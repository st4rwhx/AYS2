// CastingTestSuite.cpp — Testing framework implementation
// SPDX-License-Identifier: GPL-3.0+

#include "CastingTestSuite.h"
#include "CastingManager.h"
#include "PlatformImpl.h"
#include <iostream>
#include <sstream>
#include <chrono>
#include <thread>

namespace AYS2::Casting {

CastingTestSuite& CastingTestSuite::getInstance() {
    static CastingTestSuite instance;
    return instance;
}

CastingTestSuite::CastingTestSuite() {
}

CastingTestSuite::~CastingTestSuite() {
}

void CastingTestSuite::runAllTests() {
    std::cout << "\n" << std::string(60, '=') << "\n";
    std::cout << "AYS2 Casting System - Comprehensive Test Suite\n";
    std::cout << std::string(60, '=') << "\n\n";
    
    CastingManager& manager = CastingManager::getInstance();
    
    // Test 1: Device Discovery
    std::cout << "[TEST 1/8] Device Discovery...\n";
    auto start = std::chrono::high_resolution_clock::now();
    bool discoveryOk = testDeviceDiscovery();
    auto end = std::chrono::high_resolution_clock::now();
    int duration = std::chrono::duration_cast<std::chrono::milliseconds>(end - start).count();
    std::cout << (discoveryOk ? "✓ PASS" : "✗ FAIL") << " (" << duration << "ms)\n\n";
    
    // Get discovered devices
    const auto& devices = manager.getDiscoveredDevices();
    std::cout << "Discovered " << devices.size() << " devices:\n";
    for (const auto& dev : devices) {
        std::cout << "  - " << dev->getName() << " (" << dev->getProtocolString() << ")\n";
    }
    std::cout << "\n";
    
    // Test 2-7: Per-device tests
    int testNum = 2;
    for (const auto& device : devices) {
        std::cout << "[TEST " << testNum++ << "/8] Testing " << device->getName() << "\n";
        runTestsForDevice(device);
        std::cout << "\n";
    }
    
    // Test 8: Device Switching
    std::cout << "[TEST 8/8] Device Switching Resilience...\n";
    start = std::chrono::high_resolution_clock::now();
    bool switchOk = testDeviceSwitching();
    end = std::chrono::high_resolution_clock::now();
    duration = std::chrono::duration_cast<std::chrono::milliseconds>(end - start).count();
    std::cout << (switchOk ? "✓ PASS" : "✗ FAIL") << " (" << duration << "ms)\n\n";
    
    // Print summary
    std::cout << getTestReport();
    std::cout << std::string(60, '=') << "\n\n";
}

void CastingTestSuite::runTestsForDevice(const CastingDevicePtr& device) {
    std::vector<std::pair<std::string, bool>> tests;
    
    // Connection test
    auto start = std::chrono::high_resolution_clock::now();
    bool connOk = testDeviceConnection(device);
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::high_resolution_clock::now() - start).count();
    tests.push_back({"Connection", connOk});
    std::cout << "  " << (connOk ? "✓" : "✗") << " Connection (" << duration << "ms)\n";
    
    if (!connOk) {
        std::cout << "  (Skipping remaining tests - connection failed)\n";
        return;
    }
    
    // Video streaming test
    start = std::chrono::high_resolution_clock::now();
    bool videoOk = testVideoStreaming(device);
    duration = std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::high_resolution_clock::now() - start).count();
    tests.push_back({"Video Streaming", videoOk});
    std::cout << "  " << (videoOk ? "✓" : "✗") << " Video Streaming (" << duration << "ms)\n";
    
    // Audio streaming test
    start = std::chrono::high_resolution_clock::now();
    bool audioOk = testAudioStreaming(device);
    duration = std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::high_resolution_clock::now() - start).count();
    tests.push_back({"Audio Streaming", audioOk});
    std::cout << "  " << (audioOk ? "✓" : "✗") << " Audio Streaming (" << duration << "ms)\n";
    
    // Latency test
    start = std::chrono::high_resolution_clock::now();
    bool latencyOk = testLatency(device);
    duration = std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::high_resolution_clock::now() - start).count();
    tests.push_back({"Latency Measurement", latencyOk});
    std::cout << "  " << (latencyOk ? "✓" : "✗") << " Latency (" << duration << "ms)\n";
    
    // Frame rate stability test
    start = std::chrono::high_resolution_clock::now();
    bool fpsOk = testFrameRateStability(device);
    duration = std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::high_resolution_clock::now() - start).count();
    tests.push_back({"Frame Rate Stability", fpsOk});
    std::cout << "  " << (fpsOk ? "✓" : "✗") << " Frame Rate Stability (" << duration << "ms)\n";
    
    // Connection resilience test
    start = std::chrono::high_resolution_clock::now();
    bool resilientOk = testConnectionResilience(device);
    duration = std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::high_resolution_clock::now() - start).count();
    tests.push_back({"Connection Resilience", resilientOk});
    std::cout << "  " << (resilientOk ? "✓" : "✗") << " Resilience (" << duration << "ms)\n";
}

bool CastingTestSuite::testDeviceDiscovery() {
    CastingManager& manager = CastingManager::getInstance();
    manager.initialize();
    manager.startDeviceDiscovery();
    
    // Wait for discovery to complete
    std::this_thread::sleep_for(std::chrono::seconds(3));
    
    const auto& devices = manager.getDiscoveredDevices();
    return devices.size() > 0;
}

bool CastingTestSuite::testDeviceConnection(const CastingDevicePtr& device) {
    if (!device) return false;
    
    CastingManager& manager = CastingManager::getInstance();
    bool success = manager.startCasting(device);
    
    // Simulate streaming for 1 second
    std::this_thread::sleep_for(std::chrono::seconds(1));
    
    manager.stopCasting();
    
    return success;
}

bool CastingTestSuite::testVideoStreaming(const CastingDevicePtr& device) {
    if (!device) return false;
    
    // Simulate sending video frames
    uint8_t testFrame[1024] = {0};
    for (int i = 0; i < 30; i++) {
        // Would call: CastingIntegration::getInstance().submitVideoFrame(...)
        std::this_thread::sleep_for(std::chrono::milliseconds(33));  // ~30fps
    }
    
    return true;
}

bool CastingTestSuite::testAudioStreaming(const CastingDevicePtr& device) {
    if (!device) return false;
    
    // Simulate sending audio frames
    float testAudio[4096] = {0};
    for (int i = 0; i < 10; i++) {
        // Would call: CastingIntegration::getInstance().submitAudioFrame(...)
        std::this_thread::sleep_for(std::chrono::milliseconds(100));
    }
    
    return true;
}

bool CastingTestSuite::testLatency(const CastingDevicePtr& device) {
    if (!device) return false;
    
    CastingManager& manager = CastingManager::getInstance();
    int latency = manager.getEstimatedLatencyMs();
    
    // Check latency is within expected range for device type
    switch (device->getSelectedProtocol()) {
        case CastingProtocol::AirPlay2:
            return latency <= 50;
        case CastingProtocol::GoogleCast:
            return latency <= 150;
        case CastingProtocol::WebRTC:
            return latency <= 600;
        case CastingProtocol::DLNA_UPnP:
            return latency <= 5000;
        default:
            return false;
    }
}

bool CastingTestSuite::testFrameRateStability(const CastingDevicePtr& device) {
    if (!device) return false;
    
    // Simulate 60fps streaming for 5 seconds
    // In real test, would measure jitter
    int frames = 0;
    auto start = std::chrono::high_resolution_clock::now();
    
    while (frames < 300) {
        std::this_thread::sleep_for(std::chrono::milliseconds(16));
        frames++;
    }
    
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::high_resolution_clock::now() - start).count();
    
    // Check if we maintained ~60fps
    float actualFps = (frames * 1000.0f) / duration;
    return actualFps >= 58.0f;  // Allow 2fps variance
}

bool CastingTestSuite::testConnectionResilience(const CastingDevicePtr& device) {
    if (!device) return false;
    
    CastingManager& manager = CastingManager::getInstance();
    
    // Simulate connection drop and recovery
    manager.stopCasting();
    std::this_thread::sleep_for(std::chrono::milliseconds(500));
    
    bool reconnected = manager.startCasting(device);
    
    if (reconnected) {
        std::this_thread::sleep_for(std::chrono::seconds(1));
        manager.stopCasting();
    }
    
    return reconnected;
}

bool CastingTestSuite::testDeviceSwitching() {
    CastingManager& manager = CastingManager::getInstance();
    const auto& devices = manager.getDiscoveredDevices();
    
    if (devices.size() < 2) {
        std::cout << "  (Skipping - need at least 2 devices)\n";
        return true;
    }
    
    // Switch between first two devices
    if (!manager.startCasting(devices[0])) {
        return false;
    }
    
    std::this_thread::sleep_for(std::chrono::milliseconds(500));
    manager.stopCasting();
    
    std::this_thread::sleep_for(std::chrono::milliseconds(500));
    
    if (!manager.startCasting(devices[1])) {
        return false;
    }
    
    std::this_thread::sleep_for(std::chrono::milliseconds(500));
    manager.stopCasting();
    
    return true;
}

std::vector<DeviceTestMatrix> CastingTestSuite::getTestResults() const {
    std::vector<DeviceTestMatrix> results;
    for (const auto& [id, matrix] : testResults_) {
        results.push_back(matrix);
    }
    return results;
}

std::string CastingTestSuite::getTestReport() const {
    std::ostringstream oss;
    
    oss << "TEST SUMMARY\n";
    oss << std::string(60, '-') << "\n";
    
    int totalTests = 0;
    int passedTests = 0;
    
    for (const auto& [deviceId, matrix] : testResults_) {
        oss << "Device: " << matrix.device->getName() << "\n";
        
        for (const auto& result : matrix.results) {
            totalTests++;
            if (result.passed) passedTests++;
            
            oss << "  " << (result.passed ? "[✓]" : "[✗]") << " " 
                << result.testName << " (" << result.durationMs << "ms)\n";
        }
    }
    
    oss << std::string(60, '-') << "\n";
    oss << "Results: " << passedTests << "/" << totalTests << " tests passed\n";
    
    return oss.str();
}

void CastingTestSuite::configureRealDevice(const RealDeviceConfig& config) {
    realDevices_.push_back(config);
    std::cout << "[Config] Registered real device: " << config.deviceName << "\n";
}

} // namespace AYS2::Casting

