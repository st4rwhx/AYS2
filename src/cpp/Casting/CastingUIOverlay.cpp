// CastingUIOverlay.cpp — In-game overlay implementation
// SPDX-License-Identifier: GPL-3.0+

#include "CastingUIOverlay.h"
#include <iostream>
#include <sstream>
#include <iomanip>

namespace AYS2::Casting {

CastingUIOverlay& CastingUIOverlay::getInstance() {
    static CastingUIOverlay instance;
    return instance;
}

CastingUIOverlay::CastingUIOverlay() {
}

CastingUIOverlay::~CastingUIOverlay() {
    shutdown();
}

void CastingUIOverlay::initialize() {
    std::cout << "[CastingUIOverlay] Initialized at (" << posX_ << ", " << posY_ 
              << ") size: " << width_ << "x" << height_ << "\n";
}

void CastingUIOverlay::shutdown() {
    std::cout << "[CastingUIOverlay] Shutdown\n";
}

void CastingUIOverlay::setVisible(bool visible) {
    isVisible_ = visible;
    std::cout << "[CastingUIOverlay] " << (visible ? "Visible" : "Hidden") << "\n";
}

void CastingUIOverlay::setPosition(int x, int y) {
    posX_ = x;
    posY_ = y;
}

void CastingUIOverlay::setSize(int width, int height) {
    width_ = width;
    height_ = height;
}

void CastingUIOverlay::updateCastingState(const CastingDevicePtr& activeDevice) {
    if (!activeDevice) {
        deviceName_ = "Not casting";
        protocolName_ = "";
        return;
    }
    
    deviceName_ = activeDevice->getName();
    protocolName_ = activeDevice->getProtocolString();
}

void CastingUIOverlay::updateMetrics(const OverlayMetrics& metrics) {
    metrics_ = metrics;
}

std::string CastingUIOverlay::getOverlayJSON() const {
    std::ostringstream oss;
    
    oss << "{\n";
    oss << "  \"visible\": " << (isVisible_.load() ? "true" : "false") << ",\n";
    oss << "  \"position\": {\"x\": " << posX_ << ", \"y\": " << posY_ << "},\n";
    oss << "  \"size\": {\"width\": " << width_ << ", \"height\": " << height_ << "},\n";
    oss << "  \"device\": \"" << deviceName_ << "\",\n";
    oss << "  \"protocol\": \"" << protocolName_ << "\",\n";
    oss << "  \"metrics\": {\n";
    oss << "    \"fps\": " << metrics_.frameRate << ",\n";
    oss << "    \"latency_ms\": " << metrics_.latencyMs << ",\n";
    oss << "    \"bytes_sent\": " << metrics_.bytesSent << ",\n";
    oss << "    \"cpu_usage\": " << std::fixed << std::setprecision(1) << metrics_.cpuUsage << ",\n";
    oss << "    \"gpu_usage\": " << std::fixed << std::setprecision(1) << metrics_.gpuUsage << ",\n";
    oss << "    \"memory_usage\": " << std::fixed << std::setprecision(1) << metrics_.memoryUsage << "\n";
    oss << "  }\n";
    oss << "}\n";
    
    return oss.str();
}

} // namespace AYS2::Casting

