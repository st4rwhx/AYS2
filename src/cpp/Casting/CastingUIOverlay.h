// CastingUIOverlay.h — In-game casting status overlay
// SPDX-License-Identifier: GPL-3.0+

#pragma once

#include "CastingDevice.h"
#include <string>
#include <memory>
#include <atomic>

namespace AYS2::Casting {

struct OverlayMetrics {
    int frameRate;
    int latencyMs;
    uint64_t bytesSent;
    float cpuUsage;
    float gpuUsage;
    float memoryUsage;
};

class CastingUIOverlay {
public:
    static CastingUIOverlay& getInstance();
    
    void initialize();
    void shutdown();
    
    // Control overlay visibility
    void setVisible(bool visible);
    bool isVisible() const { return isVisible_.load(); }
    
    // Position and size
    void setPosition(int x, int y);
    void setSize(int width, int height);
    
    // Update overlay with current casting state
    void updateCastingState(const CastingDevicePtr& activeDevice);
    void updateMetrics(const OverlayMetrics& metrics);
    
    // Get overlay render data for UI system
    std::string getOverlayJSON() const;
    
    // Quick toggle (can be triggered by user hotkey)
    void toggleVisibility() { setVisible(!isVisible_.load()); }
    
private:
    CastingUIOverlay();
    ~CastingUIOverlay();
    
    CastingUIOverlay(const CastingUIOverlay&) = delete;
    CastingUIOverlay& operator=(const CastingUIOverlay&) = delete;
    
    std::atomic<bool> isVisible_{true};
    int posX_ = 16;
    int posY_ = 16;
    int width_ = 300;
    int height_ = 120;
    
    std::string deviceName_;
    std::string protocolName_;
    OverlayMetrics metrics_;
};

} // namespace AYS2::Casting

