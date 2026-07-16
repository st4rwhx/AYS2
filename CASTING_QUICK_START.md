# AYS2 Casting System - Quick Start Guide

## Initialize Casting System

```cpp
#include "Casting/CastingIntegration.h"

void AppDidLaunch() {
    // Initialize all protocol managers
    AYS2::Casting::CastingIntegration::getInstance().initialize();
    
    // Start device discovery
    AYS2::Casting::CastingManager::getInstance().initialize();
    AYS2::Casting::CastingManager::getInstance().startDeviceDiscovery();
}
```

## Submit Video Frame (from Game Loop)

```cpp
// In GSDeviceMTL::EndPresent() or equivalent
#include "Casting/CastingIntegration.h"

void SubmitFrame(const uint8_t* h264Data, size_t size, int64_t timestampUs, bool isKeyframe) {
    AYS2::Casting::CastingIntegration::getInstance().submitVideoFrame(
        h264Data, size, timestampUs, isKeyframe
    );
}
```

## Submit Audio Frame (from Audio Output)

```cpp
// In audio callback
void SubmitAudio(const float* audioData, int sampleCount, int sampleRate) {
    AYS2::Casting::CastingIntegration::getInstance().submitAudioFrame(
        audioData, sampleCount, sampleRate
    );
}
```

## Access Discovered Devices (Swift)

```swift
import SwiftUI

struct GameView: View {
    @ObservedObject var castingManager = CastingManagerSwift.shared
    
    var body: some View {
        VStack {
            // Show status bar if casting
            if castingManager.isConnected {
                CastingStatusBarView()
            }
            
            // Show device picker button
            Button("Select Device") {
                showDevicePicker = true
            }
            .sheet(isPresented: $showDevicePicker) {
                CastingDevicePickerView()
            }
        }
    }
}
```

## Start Casting to Device

```cpp
#include "Casting/CastingManager.h"

void StartCastingToDevice(const std::string& deviceId) {
    auto device = AYS2::Casting::CastingManager::getInstance().getDeviceById(deviceId);
    if (device) {
        bool success = AYS2::Casting::CastingManager::getInstance().startCasting(device);
        if (success) {
            // Casting started, frames will be sent to this device
            int latency = AYS2::Casting::CastingManager::getInstance().getEstimatedLatencyMs();
            std::cout << "Casting started, latency: " << latency << "ms\n";
        }
    }
}
```

## Stop Casting

```cpp
#include "Casting/CastingManager.h"

void StopCasting() {
    AYS2::Casting::CastingManager::getInstance().stopCasting();
}
```

## Get Statistics

```cpp
#include "Casting/CastingIntegration.h"

void PrintStatistics() {
    std::string stats;
    AYS2::Casting::CastingIntegration::getInstance().getStatistics(stats);
    std::cout << stats;
}
```

## Run Tests

```cpp
#include "Casting/CastingTestSuite.h"

void RunTests() {
    AYS2::Casting::CastingTestSuite::getInstance().runAllTests();
    
    std::string report = AYS2::Casting::CastingTestSuite::getInstance().getTestReport();
    std::cout << report;
}
```

## Device Discovery with Callbacks

```cpp
#include "Casting/CastingManager.h"

void SetupDiscovery() {
    auto& manager = AYS2::Casting::CastingManager::getInstance();
    
    // Set callback for when devices are discovered
    manager.setOnDeviceDiscovery([](const AYS2::Casting::CastingDeviceList& devices) {
        for (const auto& device : devices) {
            std::cout << "Found: " << device->getName() << "\n";
        }
    });
    
    // Set callback for connection status changes
    manager.setOnConnectionStatus(
        [](const AYS2::Casting::CastingDevicePtr& device, 
           AYS2::Casting::CastingState state, 
           const std::string& message) {
            std::cout << "Device: " << device->getName() 
                      << " State: " << device->getStateString() << "\n";
        }
    );
}
```

## Supported Protocols

| Protocol | Latency | Devices | Game Suitable |
|----------|---------|---------|---------------|
| AirPlay 2 | <40ms | Apple TV, iPad, iPhone | ✓ Yes |
| Google Cast | 80-120ms | Chromecast, Android TV | ◐ Okay |
| WebRTC | <500ms | Browsers | ✗ No |
| DLNA | 1-3s | Samsung/LG/Sony TV | ✗ No |
| Network.framework | <40ms | iOS 16+ devices | ✓ Yes |

## Protocol Auto-Selection

The system automatically selects the best protocol based on device type:

1. **Apple TV/iPad/iPhone** → AirPlay 2 (<40ms)
2. **Chromecast/Android TV** → Google Cast (80-120ms)
3. **Browser** → WebRTC (<500ms)
4. **Samsung/LG/Sony TV** → DLNA (1-3s)

## Performance Tips

1. **Minimize Latency**: Use AirPlay 2 for gaming (Apple devices)
2. **Frame Pacing**: System automatically paces frames via CMClock
3. **Zero-Copy**: IOSurface GPU memory sharing is automatic
4. **CPU Usage**: Approximately 8% additional CPU for casting

## Troubleshooting

### No Devices Found
- Ensure all devices are on same WiFi network
- Wait 3-5 seconds for discovery to complete
- Check device is compatible with AYS2 (iOS 14.0+)

### High Latency
- Verify WiFi signal strength
- Check for network congestion
- Try moving closer to router
- Use AirPlay 2 for gaming (lowest latency)

### Audio Sync Issues
- System uses CMClock for synchronization
- Should automatically sync audio/video
- Check audio sample rate (48kHz recommended)

### Connection Drops
- Connection resilience test can verify recovery
- System automatically reconnects
- Check WiFi stability

## Integration Checklist

- [ ] Include `CastingIntegration.h`
- [ ] Call `initialize()` on app launch
- [ ] Call `startDeviceDiscovery()` to find devices
- [ ] Call `submitVideoFrame()` in game render loop
- [ ] Call `submitAudioFrame()` in audio output
- [ ] Add UI views for device picker and status
- [ ] Handle connection status callbacks
- [ ] Call `shutdown()` on app exit
- [ ] Run tests to verify all devices work
- [ ] Monitor performance metrics

## Example: Minimal Integration

```cpp
// Minimal example: Start casting to first discovered device

#include "Casting/CastingIntegration.h"

void MinimalExample() {
    auto& manager = AYS2::Casting::CastingManager::getInstance();
    manager.initialize();
    manager.startDeviceDiscovery();
    
    std::this_thread::sleep_for(std::chrono::seconds(3));  // Wait for discovery
    
    const auto& devices = manager.getDiscoveredDevices();
    if (!devices.empty()) {
        manager.startCasting(devices[0]);
        
        // Now submit frames to active device
        // Each frame will automatically route to correct protocol
    }
}
```

## Documentation Files

- `CASTING_SYSTEM_COMPLETE.md` - Full technical documentation
- `PHASE_6_COMPLETE.md` - Phase 6 completion details
- `CASTING_IMPLEMENTATION_GUIDE.md` - Original implementation roadmap

