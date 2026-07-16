// AYS2 WebRTC Receiver — Browser-based receiver for H.264 video streams
// SPDX-License-Identifier: GPL-3.0+

class AYS2WebRTCReceiver {
    constructor() {
        this.peerConnection = null;
        this.videoDecoder = null;
        this.frameStats = {
            count: 0,
            decodedCount: 0,
            droppedCount: 0,
            bytesReceived: 0,
            latencySamples: [],
            startTime: Date.now(),
            lastStatsUpdate: Date.now(),
            inFlightFrames: new Map()
        };
        
        this.config = {
            iceServers: [
                { urls: ['stun:stun.l.google.com:19302'] },
                { urls: ['stun:stun1.l.google.com:19302'] }
            ]
        };
        
        this.signalingServerURL = this.getSignalingServerURL();
        this.mediaSource = null;
        this.sourceBuffer = null;
    }
    
    /**
     * Get signaling server URL from current location
     */
    getSignalingServerURL() {
        // Assumes WebSocket server on same host, port 8081
        const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
        return `${protocol}//${window.location.hostname}:8081`;
    }
    
    /**
     * Initialize receiver and connect to sender
     */
    async connect() {
        try {
            console.log('[AYS2 Receiver] Initializing...');
            this.updateStatus('Initializing...', 'connecting');
            
            // Create peer connection
            this.peerConnection = new RTCPeerConnection(this.config);
            
            // Handle connection state changes
            this.peerConnection.onconnectionstatechange = () => this.handleConnectionStateChange();
            this.peerConnection.oniceconnectionstatechange = () => this.handleICEConnectionStateChange();
            
            // Handle ICE candidates
            this.peerConnection.onicecandidate = (event) => {
                if (event.candidate) {
                    this.sendSignalingMessage({
                        type: 'ice-candidate',
                        candidate: event.candidate
                    });
                }
            };
            
            // Handle incoming data channel (video stream)
            this.peerConnection.ondatachannel = (event) => {
                console.log('[AYS2 Receiver] Data channel received:', event.channel.label);
                this.handleDataChannel(event.channel);
            };
            
            // Connect to signaling server
            await this.connectToSignalingServer();
            
        } catch (error) {
            console.error('[AYS2 Receiver] Connection error:', error);
            this.updateStatus(`Error: ${error.message}`, 'disconnected');
        }
    }
    
    /**
     * Connect to WebSocket signaling server
     */
    async connectToSignalingServer() {
        return new Promise((resolve, reject) => {
            try {
                const ws = new WebSocket(this.signalingServerURL);
                
                ws.onopen = () => {
                    console.log('[AYS2 Receiver] Connected to signaling server');
                    this.updateStatus('Waiting for offer...', 'connecting');
                    resolve();
                };
                
                ws.onmessage = async (event) => {
                    const message = JSON.parse(event.data);
                    await this.handleSignalingMessage(message);
                };
                
                ws.onerror = (error) => {
                    console.error('[AYS2 Receiver] Signaling error:', error);
                    reject(error);
                };
                
                ws.onclose = () => {
                    console.log('[AYS2 Receiver] Signaling connection closed');
                };
                
                this.signalingSocket = ws;
                
            } catch (error) {
                reject(error);
            }
        });
    }
    
    /**
     * Handle signaling messages (offer, answer, ICE candidates)
     */
    async handleSignalingMessage(message) {
        try {
            switch (message.type) {
                case 'offer':
                    console.log('[AYS2 Receiver] Received SDP offer');
                    await this.handleOffer(message.sdp);
                    break;
                    
                case 'ice-candidate':
                    if (message.candidate) {
                        console.log('[AYS2 Receiver] Received ICE candidate');
                        await this.peerConnection.addIceCandidate(new RTCIceCandidate(message.candidate));
                    }
                    break;
                    
                case 'pong':
                    // Latency measurement response
                    this.recordLatencySample(message.timestamp);
                    break;
            }
        } catch (error) {
            console.error('[AYS2 Receiver] Signaling error:', error);
        }
    }
    
    /**
     * Handle WebRTC offer from sender
     */
    async handleOffer(sdp) {
        try {
            // Set remote description
            await this.peerConnection.setRemoteDescription(new RTCSessionDescription({
                type: 'offer',
                sdp: sdp
            }));
            
            // Create answer
            const answer = await this.peerConnection.createAnswer();
            await this.peerConnection.setLocalDescription(answer);
            
            // Send answer back to sender
            this.sendSignalingMessage({
                type: 'answer',
                sdp: answer.sdp
            });
            
            console.log('[AYS2 Receiver] Answer sent');
            
        } catch (error) {
            console.error('[AYS2 Receiver] Error handling offer:', error);
            throw error;
        }
    }
    
    /**
     * Handle data channel for video streaming
     */
    handleDataChannel(channel) {
        channel.binaryType = 'arraybuffer';
        
        channel.onopen = () => {
            console.log('[AYS2 Receiver] Data channel opened:', channel.label);
        };
        
        channel.onmessage = (event) => {
            this.handleVideoFrame(event.data);
        };
        
        channel.onclose = () => {
            console.log('[AYS2 Receiver] Data channel closed:', channel.label);
        };
        
        channel.onerror = (error) => {
            console.error('[AYS2 Receiver] Data channel error:', error);
        };
    }
    
    /**
     * Handle incoming H.264 video frame
     */
    async handleVideoFrame(frameBuffer) {
        try {
            this.frameStats.count++;
            this.frameStats.bytesReceived += frameBuffer.byteLength;
            
            // Create video decoder chunk
            const chunk = new EncodedVideoChunk({
                type: 'delta',  // Assume frames are delta frames by default
                timestamp: performance.now() * 1000,
                data: frameBuffer
            });
            
            // Decode and render
            if (this.videoDecoder) {
                try {
                    await this.videoDecoder.decode(chunk);
                    this.frameStats.decodedCount++;
                } catch (error) {
                    console.error('[AYS2 Receiver] Decode error:', error);
                    this.frameStats.droppedCount++;
                }
            }
            
            // Update stats periodically
            if (this.frameStats.count % 60 === 0) {
                this.updateStatsDisplay();
            }
            
        } catch (error) {
            console.error('[AYS2 Receiver] Frame handling error:', error);
            this.frameStats.droppedCount++;
        }
    }
    
    /**
     * Record latency sample (for jitter analysis)
     */
    recordLatencySample(senderTimestamp) {
        const receiverTimestamp = performance.now();
        const latency = receiverTimestamp - senderTimestamp;
        
        this.frameStats.latencySamples.push(latency);
        
        // Keep only recent samples (100 frames)
        if (this.frameStats.latencySamples.length > 100) {
            this.frameStats.latencySamples.shift();
        }
    }
    
    /**
     * Calculate average latency
     */
    getAverageLatency() {
        if (this.frameStats.latencySamples.length === 0) return 0;
        
        const sum = this.frameStats.latencySamples.reduce((a, b) => a + b, 0);
        return (sum / this.frameStats.latencySamples.length).toFixed(1);
    }
    
    /**
     * Handle connection state change
     */
    handleConnectionStateChange() {
        const state = this.peerConnection.connectionState;
        console.log('[AYS2 Receiver] Connection state:', state);
        
        switch (state) {
            case 'connected':
                this.updateStatus('Connected', 'connected');
                break;
            case 'disconnected':
            case 'failed':
            case 'closed':
                this.updateStatus('Disconnected', 'disconnected');
                break;
        }
    }
    
    /**
     * Handle ICE connection state change
     */
    handleICEConnectionStateChange() {
        const state = this.peerConnection.iceConnectionState;
        console.log('[AYS2 Receiver] ICE connection state:', state);
        
        const connectionStateSpan = document.getElementById('connection-state');
        if (connectionStateSpan) {
            connectionStateSpan.textContent = state;
        }
    }
    
    /**
     * Update status display
     */
    updateStatus(message, state) {
        const statusSpan = document.getElementById('status');
        if (statusSpan) {
            statusSpan.textContent = message;
            statusSpan.className = `stat-value status-${state}`;
        }
        console.log(`[AYS2 Receiver] Status: ${message} (${state})`);
    }
    
    /**
     * Update statistics display
     */
    updateStatsDisplay() {
        const now = Date.now();
        const elapsed = (now - this.frameStats.startTime) / 1000;
        const fps = (this.frameStats.decodedCount / elapsed).toFixed(1);
        const bitrate = ((this.frameStats.bytesReceived * 8) / (elapsed * 1_000_000)).toFixed(1);
        const latency = this.getAverageLatency();
        
        // Update UI
        const framesSpan = document.getElementById('frames');
        const latencySpan = document.getElementById('latency');
        const bitrateSpan = document.getElementById('bitrate');
        const packetsLostSpan = document.getElementById('packets-lost');
        
        if (framesSpan) framesSpan.textContent = `${this.frameStats.decodedCount} (${fps} fps)`;
        if (latencySpan) latencySpan.textContent = `${latency} ms`;
        if (bitrateSpan) bitrateSpan.textContent = `${bitrate} Mbps`;
        if (packetsLostSpan) packetsLostSpan.textContent = this.frameStats.droppedCount;
        
        console.log(`[AYS2 Receiver] Stats: ${this.frameStats.decodedCount} frames, ` +
                    `${fps} fps, ${bitrate} Mbps, ${latency}ms latency`);
    }
    
    /**
     * Send signaling message back to sender
     */
    sendSignalingMessage(message) {
        if (this.signalingSocket && this.signalingSocket.readyState === WebSocket.OPEN) {
            this.signalingSocket.send(JSON.stringify(message));
        }
    }
}

// Initialize receiver when page loads
window.addEventListener('DOMContentLoaded', async () => {
    console.log('[AYS2 Receiver] Page loaded');
    
    const receiver = new AYS2WebRTCReceiver();
    
    // Setup fullscreen button
    const fullscreenBtn = document.getElementById('fullscreen-btn');
    if (fullscreenBtn) {
        fullscreenBtn.addEventListener('click', () => {
            const videoContainer = document.getElementById('video-container');
            if (videoContainer.requestFullscreen) {
                videoContainer.requestFullscreen();
            }
        });
    }
    
    // Setup stats toggle
    const statsToggle = document.getElementById('stats-toggle');
    if (statsToggle) {
        let statsVisible = true;
        statsToggle.addEventListener('click', () => {
            const statsPanel = document.getElementById('stats-panel');
            statsVisible = !statsVisible;
            statsPanel.style.display = statsVisible ? 'grid' : 'none';
            statsToggle.textContent = statsVisible ? 'Hide Stats' : 'Show Stats';
        });
    }
    
    // Connect to sender
    await receiver.connect();
});
