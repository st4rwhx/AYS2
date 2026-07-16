// CastingDevicePickerView.swift — Device picker for multi-device casting
// SPDX-License-Identifier: GPL-3.0+

import SwiftUI

struct CastingDevicePickerView: View {
    @State private var discoveredDevices: [AYS2CastingDeviceInfo] = []
    @State private var isDiscovering = false
    @State private var selectedDevice: AYS2CastingDeviceInfo?
    @State private var isCasting = false
    @State private var castingStatus = "Ready to cast"
    
    var onDismiss: () -> Void
    var onDeviceSelected: (AYS2CastingDeviceInfo) -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Cast to Device")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Select a device to start casting gameplay")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                // Discovering indicator
                if isDiscovering {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Discovering devices...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                }
                
                // Device list
                if discoveredDevices.isEmpty && !isDiscovering {
                    VStack(spacing: 12) {
                        Image(systemName: "tv.inset.filled")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        
                        Text("No devices found")
                            .font(.headline)
                        
                        Text("Make sure your TV or casting device is connected to the same WiFi network")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(discoveredDevices, id: \.deviceId) { device in
                                CastingDeviceRow(
                                    device: device,
                                    isSelected: selectedDevice?.deviceId == device.deviceId,
                                    onSelect: {
                                        selectedDevice = device
                                        startCasting(to: device)
                                    }
                                )
                            }
                        }
                        .padding()
                    }
                }
                
                // Casting status
                if isCasting, let device = selectedDevice {
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Casting to \(device.deviceName)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                Text("Latency: \(device.estimatedLatencyMs)ms • \(device.modelName)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Button(action: { stopCasting() }) {
                                Text("Stop")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.red)
                            }
                        }
                        .padding()
                        .background(Color(.systemGreen).opacity(0.1))
                        .cornerRadius(8)
                    }
                    .padding()
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 12) {
                    Button(action: onDismiss) {
                        Text("Close")
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(Color(.systemGray5))
                            .cornerRadius(8)
                    }
                    .foregroundStyle(.primary)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                startDiscovery()
            }
            .onDisappear {
                AYS2Casting.stopDeviceDiscovery()
            }
        }
    }
    
    private func startDiscovery() {
        isDiscovering = true
        AYS2Casting.startDeviceDiscovery()
        
        // Poll for discovered devices
        let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            let devices = AYS2Casting.discoveredDevices()
            discoveredDevices = devices
            
            if !devices.isEmpty {
                isDiscovering = false
            }
        }
        
        // Stop polling after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            timer.invalidate()
            if discoveredDevices.isEmpty {
                isDiscovering = false
            }
        }
    }
    
    private func startCasting(to device: AYS2CastingDeviceInfo) {
        if AYS2Casting.startCastingToDevice(device) {
            isCasting = true
            castingStatus = "Casting to \(device.deviceName)"
            onDeviceSelected(device)
        } else {
            castingStatus = "Failed to start casting"
        }
    }
    
    private func stopCasting() {
        AYS2Casting.stopCasting()
        isCasting = false
        selectedDevice = nil
        castingStatus = "Stopped casting"
    }
}

struct CastingDeviceRow: View {
    let device: AYS2CastingDeviceInfo
    let isSelected: Bool
    let onSelect: () -> Void
    
    var protocolIcon: String {
        switch device.protocol {
        case .airPlay2:
            return "apple.tv"
        case .googleCast:
            return "play.tv"
        case .networkFramework:
            return "network"
        case .webRTC:
            return "globe"
        case .dLNA:
            return "tv"
        default:
            return "questionmark.circle"
        }
    }
    
    var protocolName: String {
        switch device.protocol {
        case .airPlay2:
            return "AirPlay 2"
        case .googleCast:
            return "Google Cast"
        case .networkFramework:
            return "Network"
        case .webRTC:
            return "WebRTC"
        case .dLNA:
            return "DLNA"
        default:
            return "Unknown"
        }
    }
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: protocolIcon)
                        .font(.system(size: 28))
                        .foregroundStyle(.blue)
                        .frame(width: 44, alignment: .center)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(device.deviceName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        
                        HStack(spacing: 8) {
                            Text(device.modelName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Divider()
                                .frame(height: 12)
                            
                            Text(protocolName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Divider()
                                .frame(height: 12)
                            
                            Text("\(device.estimatedLatencyMs)ms")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.green)
                    } else {
                        Image(systemName: "circle")
                            .font(.system(size: 24))
                            .foregroundStyle(.secondary)
                    }
                }
                
                if device.supportsGameStreaming {
                    HStack(spacing: 4) {
                        Image(systemName: "gamecontroller.fill")
                            .font(.caption2)
                        Text("Optimized for gaming")
                            .font(.caption2)
                            .fontWeight(.semibold)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(Color.blue.opacity(0.15))
                    .cornerRadius(4)
                    .foregroundStyle(.blue)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.green : Color(.systemGray4), lineWidth: isSelected ? 2 : 1)
            )
        }
    }
}

#Preview {
    CastingDevicePickerView(
        onDismiss: { },
        onDeviceSelected: { _ in }
    )
}
