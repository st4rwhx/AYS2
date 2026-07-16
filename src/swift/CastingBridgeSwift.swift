// CastingBridgeSwift.swift — Swift bindings for C++ casting system
// SPDX-License-Identifier: GPL-3.0+

import Foundation

// MARK: - Device Model

public enum CastingProtocol: String {
    case unknown = "Unknown"
    case airplay2 = "AirPlay 2"
    case networkFramework = "Network.framework"
    case googleCast = "Google Cast"
    case dlna = "DLNA/UPnP"
    case webrtc = "WebRTC"
}

public enum CastingDeviceType: String {
    case unknown = "Unknown"
    case appleTV = "Apple TV"
    case iPad = "iPad"
    case iPhone = "iPhone"
    case mac = "Mac"
    case chromecast = "Chromecast"
    case androidTV = "Android TV"
    case smartTV = "Smart TV"
    case computer = "Computer"
    case phone = "Phone"
}

public enum CastingState: String {
    case discovered = "Discovered"
    case connecting = "Connecting"
    case connected = "Connected"
    case disconnecting = "Disconnecting"
    case error = "Error"
    case unavailable = "Unavailable"
}

public struct CastingDeviceSwift: Identifiable {
    public let id: String
    public let name: String
    public let model: String
    public let deviceType: CastingDeviceType
    public let protocol: CastingProtocol
    public let ipAddress: String
    public let estimatedLatencyMs: Int
    public let isAvailable: Bool
    public let supportsGameStreaming: Bool
    public let receiverURL: String?
    
    public init(
        id: String,
        name: String,
        model: String,
        deviceType: CastingDeviceType = .unknown,
        protocol: CastingProtocol = .unknown,
        ipAddress: String = "",
        estimatedLatencyMs: Int = 0,
        isAvailable: Bool = true,
        supportsGameStreaming: Bool = false,
        receiverURL: String? = nil
    ) {
        self.id = id
        self.name = name
        self.model = model
        self.deviceType = deviceType
        self.protocol = `protocol`
        self.ipAddress = ipAddress
        self.estimatedLatencyMs = estimatedLatencyMs
        self.isAvailable = isAvailable
        self.supportsGameStreaming = supportsGameStreaming
        self.receiverURL = receiverURL
    }
}

// MARK: - Casting Manager Wrapper

public class CastingManagerSwift: ObservableObject {
    @Published public var discoveredDevices: [CastingDeviceSwift] = []
    @Published public var activeDevice: CastingDeviceSwift?
    @Published public var isConnected: Bool = false
    @Published public var latencyMs: Int = 0
    
    private var discoveryTimer: Timer?
    
    public static let shared = CastingManagerSwift()
    
    private init() {
        setupObservers()
    }
    
    private func setupObservers() {
        // Would connect to C++ event callbacks here
    }
    
    public func initialize() {
        print("[CastingManagerSwift] Initializing")
        // Call C++ CastingManager::initialize()
    }
    
    public func startDeviceDiscovery() {
        print("[CastingManagerSwift] Starting device discovery")
        // Call C++ CastingManager::startDeviceDiscovery()
        
        // Simulate discovery for UI
        discoveryTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateDiscoveredDevices()
        }
    }
    
    public func stopDeviceDiscovery() {
        discoveryTimer?.invalidate()
        // Call C++ CastingManager::stopDeviceDiscovery()
    }
    
    public func startCasting(device: CastingDeviceSwift) {
        print("[CastingManagerSwift] Starting cast to: \(device.name)")
        // Call C++ CastingManager::startCasting(device)
        DispatchQueue.main.async {
            self.activeDevice = device
            self.isConnected = true
        }
    }
    
    public func stopCasting() {
        print("[CastingManagerSwift] Stopping cast")
        // Call C++ CastingManager::stopCasting()
        DispatchQueue.main.async {
            self.activeDevice = nil
            self.isConnected = false
        }
    }
    
    private func updateDiscoveredDevices() {
        // In production, would fetch from C++ CastingManager::getDiscoveredDevices()
        // For now, simulate some devices
        
        DispatchQueue.main.async {
            // Simulate device discovery
            if self.discoveredDevices.isEmpty {
                self.discoveredDevices = [
                    CastingDeviceSwift(
                        id: "airplay-appletv",
                        name: "Living Room Apple TV",
                        model: "Apple TV 4K",
                        deviceType: .appleTV,
                        protocol: .airplay2,
                        estimatedLatencyMs: 35,
                        supportsGameStreaming: true
                    ),
                    CastingDeviceSwift(
                        id: "cast-chromecast",
                        name: "Bedroom Chromecast",
                        model: "Chromecast 3",
                        deviceType: .chromecast,
                        protocol: .googleCast,
                        estimatedLatencyMs: 100,
                        supportsGameStreaming: false
                    )
                ]
            }
        }
    }
}

// MARK: - UI Overlay View

public struct CastingStatusBarView: View {
    @ObservedObject var castingManager = CastingManagerSwift.shared
    
    public init() {}
    
    public var body: some View {
        if let device = castingManager.activeDevice, castingManager.isConnected {
            HStack(spacing: 12) {
                Image(systemName: "airplayaudio.circle.fill")
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Casting to \(device.name)")
                        .font(.caption)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 8) {
                        Image(systemName: "network")
                            .font(.caption2)
                        Text("\(device.estimatedLatencyMs)ms")
                            .font(.caption2)
                        
                        Image(systemName: "speedometer")
                            .font(.caption2)
                        Text(device.protocol.rawValue)
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    castingManager.stopCasting()
                }) {
                    Image(systemName: "stop.circle.fill")
                        .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.7))
            .cornerRadius(8)
        }
    }
}

// MARK: - Device Picker View

public struct CastingDevicePickerView: View {
    @ObservedObject var castingManager = CastingManagerSwift.shared
    @Environment(\.dismiss) var dismiss
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            List {
                if castingManager.discoveredDevices.isEmpty {
                    Text("No devices found")
                        .foregroundColor(.secondary)
                } else {
                    // Group by device type
                    let groupedByType = Dictionary(grouping: castingManager.discoveredDevices) { $0.deviceType }
                    
                    ForEach(groupedByType.keys.sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { type in
                        Section(header: Text(type.rawValue)) {
                            ForEach(groupedByType[type] ?? []) { device in
                                CastingDeviceRow(device: device) {
                                    castingManager.startCasting(device: device)
                                    dismiss()
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Device")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                castingManager.startDeviceDiscovery()
            }
            .onDisappear {
                castingManager.stopDeviceDiscovery()
            }
        }
    }
}

private struct CastingDeviceRow: View {
    let device: CastingDeviceSwift
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(device.name)
                        .font(.headline)
                    
                    HStack(spacing: 12) {
                        Label(device.model, systemImage: "tv")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Label("\(device.estimatedLatencyMs)ms", systemImage: "network")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    if device.supportsGameStreaming {
                        Label("Gaming", systemImage: "gamecontroller.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    
                    if !device.isAvailable {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.yellow)
                    }
                }
            }
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    CastingStatusBarView()
}
