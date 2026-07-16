// CastingStatusBar.swift — In-game casting status indicator
// SPDX-License-Identifier: GPL-3.0+

import SwiftUI

struct CastingStatusBar: View {
    @State private var activeCastingDevice: AYS2CastingDeviceInfo?
    @State private var isCasting = false
    @State private var latencyMs = 0
    @State private var isShowingPicker = false
    
    var onShowDevicePicker: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            if isCasting, let device = activeCastingDevice {
                // Casting active - show status bar
                HStack(spacing: 12) {
                    // Casting indicator
                    HStack(spacing: 6) {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.caption2)
                            .foregroundStyle(.green)
                            .symbolEffect(.pulse)
                        
                        Text("Casting")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.green)
                    }
                    
                    Divider()
                        .frame(height: 14)
                    
                    // Device name
                    VStack(alignment: .leading, spacing: 2) {
                        Text(device.deviceName)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        
                        Text("\(latencyMs)ms latency")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    // Change device button
                    Button(action: { isShowingPicker = true }) {
                        Image(systemName: "arrow.up.right.square.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                    
                    // Stop casting button
                    Button(action: stopCasting) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.green.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
            } else {
                // Not casting - show cast button
                Button(action: { isShowingPicker = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "tv.and.hifispeaker.fill")
                            .font(.caption)
                        Text("Cast")
                            .font(.caption2)
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.15))
                    .foregroundStyle(.blue)
                    .cornerRadius(6)
                }
            }
        }
        .sheet(isPresented: $isShowingPicker) {
            CastingDevicePickerView(
                onDismiss: { isShowingPicker = false },
                onDeviceSelected: { device in
                    activeCastingDevice = device
                    isCasting = true
                    latencyMs = Int(device.estimatedLatencyMs)
                    onShowDevicePicker()
                }
            )
        }
        .onAppear {
            updateStatus()
            
            // Update status every second
            let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                updateStatus()
            }
            
            // Keep reference to timer
            DispatchQueue.main.async {
                // Store timer reference somewhere to prevent deallocation
            }
        }
    }
    
    private func updateStatus() {
        isCasting = AYS2Casting.isCasting()
        activeCastingDevice = AYS2Casting.activeCastingDevice()
        latencyMs = Int(AYS2Casting.estimatedLatencyMs())
    }
    
    private func stopCasting() {
        AYS2Casting.stopCasting()
        isCasting = false
        activeCastingDevice = nil
    }
}

#Preview {
    CastingStatusBar(onShowDevicePicker: {})
        .padding()
}
