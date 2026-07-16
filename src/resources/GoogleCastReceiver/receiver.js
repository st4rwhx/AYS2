/**
 * AYS2 Custom Google Cast Receiver
 * Receives H.264 video + AAC audio stream from iOS app
 * SPDX-License-Identifier: GPL-3.0+
 */

class AYS2CastReceiver {
    constructor() {
        this.videoPlayer = document.getElementById('video-player');
        this.statusText = document.getElementById('status-text');
        this.statsText = document.getElementById('stats-text');
        
        this.mediaSource = null;
        this.sourceBuffer = null;
        this.framesReceived = 0;
        this.audioFramesReceived = 0;
        this.lastTimestamp = 0;
        
        this.initialize();
    }
    
    initialize() {
        console.log('[AYS2 Receiver] Initializing...');
        
        // Get custom message channel namespace
        const context = cast.framework.CastReceiverContext.getInstance();
        
        // Create custom message bus for raw streaming
        this.messageBus = context.getCustomMessageBus('urn:x-cast:ays2.media');
        
        // Listen for messages from sender
        this.messageBus.onMessage = (event) => {
            this.onMessage(event);
        };
        
        // Setup MediaSource for H.264 streaming
        this.setupMediaSource();
        
        // Request standalone receiver
        context.setLoggerLevel(cast.framework.LoggerLevel.DEBUG);
        context.start();
        
        this.updateStatus('Ready for streaming...');
        console.log('[AYS2 Receiver] Initialized');
    }
    
    setupMediaSource() {
        if (!window.MediaSource) {
            console.error('[AYS2 Receiver] MediaSource API not supported');
            this.updateStatus('ERROR: MediaSource not supported');
            return;
        }
        
        this.mediaSource = new MediaSource();
        this.mediaSource.addEventListener('sourceopen', () => this.onSourceOpen());
        this.mediaSource.addEventListener('sourceended', () => this.onSourceEnded());
        
        // Create blob URL for video element
        const url = URL.createObjectURL(this.mediaSource);
        this.videoPlayer.src = url;
    }
    
    onSourceOpen() {
        console.log('[AYS2 Receiver] MediaSource opened');
        
        try {
            // Create source buffer for H.264 video
            // Codec string: video/mp4; codecs="avc1.42E01E" (H.264 baseline)
            const videoCodec = 'video/mp4; codecs="avc1.42E01E"';
            
            if (MediaSource.isTypeSupported(videoCodec)) {
                this.sourceBuffer = this.mediaSource.addSourceBuffer(videoCodec);
                console.log('[AYS2 Receiver] Added H.264 source buffer');
            } else {
                console.error('[AYS2 Receiver] H.264 codec not supported');
                this.updateStatus('ERROR: H.264 not supported');
            }
        } catch (error) {
            console.error('[AYS2 Receiver] Failed to create source buffer:', error);
            this.updateStatus('ERROR: ' + error.message);
        }
    }
    
    onSourceEnded() {
        console.log('[AYS2 Receiver] MediaSource ended');
    }
    
    onMessage(event) {
        try {
            const message = JSON.parse(event.data);
            
            switch (message.type) {
                case 'INIT':
                    this.onInit(message);
                    break;
                case 'VIDEO_FRAME':
                    this.onVideoFrame(message);
                    break;
                case 'AUDIO_FRAME':
                    this.onAudioFrame(message);
                    break;
                default:
                    console.warn('[AYS2 Receiver] Unknown message type:', message.type);
            }
        } catch (error) {
            console.error('[AYS2 Receiver] Failed to process message:', error);
        }
    }
    
    onInit(message) {
        console.log('[AYS2 Receiver] Stream init:', {
            encoding: message.encoding,
            audio: message.audio,
            fps: message.fps,
            resolution: message.width + 'x' + message.height
        });
        
        this.updateStatus('Stream initialized: ' + message.width + 'x' + message.height + ' @ ' + message.fps + 'fps');
    }
    
    onVideoFrame(message) {
        if (!this.sourceBuffer || this.mediaSource.readyState !== 'open') {
            return;
        }
        
        try {
            // Decode base64 H.264 data
            const binaryString = atob(message.data);
            const bytes = new Uint8Array(binaryString.length);
            for (let i = 0; i < binaryString.length; i++) {
                bytes[i] = binaryString.charCodeAt(i);
            }
            
            // Append to source buffer
            if (!this.sourceBuffer.updating) {
                this.sourceBuffer.appendBuffer(bytes);
            }
            
            this.framesReceived++;
            this.lastTimestamp = message.timestamp;
            
            // Update stats every 30 frames
            if (this.framesReceived % 30 === 0) {
                this.updateStats();
            }
        } catch (error) {
            console.error('[AYS2 Receiver] Failed to process video frame:', error);
        }
    }
    
    onAudioFrame(message) {
        // Audio handling would go here
        // For now, audio is handled separately through system audio
        this.audioFramesReceived++;
    }
    
    updateStatus(text) {
        this.statusText.textContent = text;
        console.log('[AYS2 Receiver]', text);
    }
    
    updateStats() {
        const stats = `Frames: ${this.framesReceived} | Audio: ${this.audioFramesReceived} | Latency: ?ms`;
        this.statsText.textContent = stats;
    }
}

// Initialize receiver when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
    new AYS2CastReceiver();
});
