// CastingDevice.cpp — Universal casting device implementation
// SPDX-License-Identifier: GPL-3.0+

#include "CastingDevice.h"

namespace AYS2::Casting {

CastingDevice::CastingDevice(const CastingDeviceInfo& info)
    : info_(info), state_(CastingState::Discovered), selectedProtocol_(info.preferredProtocol)
{
}

bool CastingDevice::supports(CastingProtocol protocol) const
{
    for (const auto& p : info_.supportedProtocols) {
        if (p == protocol)
            return true;
    }
    return false;
}

bool CastingDevice::isGameStreamingSuitable() const
{
    if (!info_.supportsGameStreaming || !info_.isAvailable)
        return false;
    
    // Only fast protocols suitable for gaming
    return selectedProtocol_ == CastingProtocol::AirPlay2 ||
           selectedProtocol_ == CastingProtocol::NetworkFramework ||
           selectedProtocol_ == CastingProtocol::GoogleCast ||
           selectedProtocol_ == CastingProtocol::WebRTC;
}

bool CastingDevice::isVideoPlaybackSuitable() const
{
    return info_.supportsVideo && info_.isAvailable;
}

std::string CastingDevice::getStateString() const
{
    switch (state_) {
        case CastingState::Discovered:
            return "Discovered";
        case CastingState::Connecting:
            return "Connecting";
        case CastingState::Connected:
            return "Connected";
        case CastingState::Disconnecting:
            return "Disconnecting";
        case CastingState::Error:
            return "Error";
        case CastingState::Unavailable:
            return "Unavailable";
        default:
            return "Unknown";
    }
}

std::string CastingDevice::getProtocolString() const
{
    switch (selectedProtocol_) {
        case CastingProtocol::AirPlay2:
            return "AirPlay 2";
        case CastingProtocol::NetworkFramework:
            return "Network Framework";
        case CastingProtocol::GoogleCast:
            return "Google Cast";
        case CastingProtocol::DLNA_UPnP:
            return "DLNA/UPnP";
        case CastingProtocol::WebRTC:
            return "WebRTC";
        default:
            return "Unknown";
    }
}

} // namespace AYS2::Casting
