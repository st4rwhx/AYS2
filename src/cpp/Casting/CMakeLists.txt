# Casting Module — Hybrid multi-device casting system
# SPDX-License-Identifier: GPL-3.0+

add_library(casting STATIC)

# Core casting system files
target_sources(casting PRIVATE
    CastingDevice.cpp
    CastingDevice.h
    CastingManager.cpp
    CastingManager.h
    CastingIntegration.cpp
    CastingIntegration.h
    CastingUIOverlay.cpp
    CastingUIOverlay.h
    VideoEncoder.h
    FramePacingController.h
    CVPixelBufferPoolManager.h
    AirPlayManager.h
    AirPlayProtocol.h
    AirPlayFrameCapture.h
    AirPlayNetworkTransport.h
    GoogleCastManager.h
    GoogleCastManager.cpp
    DLNAManager.h
    DLNAManager.cpp
    WebRTCManager.h
    WebRTCManager.cpp
    PlatformImpl.h
    PlatformImpl.cpp
    CastingTestSuite.h
    CastingTestSuite.cpp
)

# Platform-specific sources
if(APPLE)
    target_sources(casting PRIVATE
        VideoEncoder.mm
        FramePacingController.mm
        CVPixelBufferPoolManager.mm
        AirPlayFrameCapture.mm
        AirPlayNetworkTransport.mm
        AirPlayManager.mm
        AirPlayProtocol.mm
        PlatformImpl.cpp
        CastingBridge.h
        CastingBridge.mm
    )
    
    # Link Apple frameworks
    target_link_libraries(casting PRIVATE
        "-framework Foundation"
        "-framework AVFoundation"
        "-framework VideoToolbox"
        "-framework Network"
        "-framework Metal"
        "-framework UIKit"
        "-framework CoreVideo"
        "-framework CoreMedia"
        "-framework SystemConfiguration"
        "-framework CoreFoundation"
    )
endif()

# Include directories
target_include_directories(casting PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}
)

# Link against common libraries
target_link_libraries(casting PUBLIC
    common
)

# Link libupnp for DLNA/UPnP support
find_package(UPNP REQUIRED)
if(UPNP_FOUND)
    target_link_libraries(casting PRIVATE ${UPNP_LIBRARIES})
    target_include_directories(casting PRIVATE ${UPNP_INCLUDE_DIRS})
else()
    message(WARNING "libupnp not found - DLNA support may be limited")
endif()

# Platform-specific compiler flags
if(APPLE)
    target_compile_options(casting PRIVATE -fobjc-arc)
endif()

# C++ standard
set_target_properties(casting PROPERTIES
    CXX_STANDARD 17
    CXX_STANDARD_REQUIRED ON
)
