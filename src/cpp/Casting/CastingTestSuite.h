// CastingTestSuite.h — Device testing framework
// SPDX-License-Identifier: GPL-3.0+

#pragma once

#include "CastingDevice.h"
#include <string>
#include <vector>
#include <map>
#include <memory>

namespace AYS2::Casting {

struct TestResult {
    std::string testName;
    bool passed;
    std::string errorMessage;
    int durationMs;
    std::map<std::string, std::string> metrics;
};

struct DeviceTestMatrix {
    CastingDevicePtr device;
    std::vector<TestResult> results;
    bool allTestsPassed;
    int totalDurationMs;
};

class CastingTestSuite {
public:
    static CastingTestSuite& getInstance();
    
    // Start comprehensive device testing
    void runAllTests();
    void runTestsForDevice(const CastingDevicePtr& device);
    
    // Individual test methods
    bool testDeviceDiscovery();
    bool testDeviceConnection(const CastingDevicePtr& device);
    bool testVideoStreaming(const CastingDevicePtr& device);
    bool testAudioStreaming(const CastingDevicePtr& device);
    bool testLatency(const CastingDevicePtr& device);
    bool testFrameRateStability(const CastingDevicePtr& device);
    bool testConnectionResilience(const CastingDevicePtr& device);
    bool testDeviceSwitching();
    
    // Get test results
    std::vector<DeviceTestMatrix> getTestResults() const;
    std::string getTestReport() const;
    
    // Real device targets
    struct RealDeviceConfig {
        std::string deviceName;
        CastingDeviceType deviceType;
        CastingProtocol protocol;
        std::string ipAddress;
    };
    
    void configureRealDevice(const RealDeviceConfig& config);
    
private:
    CastingTestSuite();
    ~CastingTestSuite();
    
    CastingTestSuite(const CastingTestSuite&) = delete;
    CastingTestSuite& operator=(const CastingTestSuite&) = delete;
    
    void recordTestResult(const std::string& deviceId, const TestResult& result);
    std::string formatReport() const;
    
    std::map<std::string, DeviceTestMatrix> testResults_;
    std::vector<RealDeviceConfig> realDevices_;
};

} // namespace AYS2::Casting

