// SPDX-FileCopyrightText: 2002-2026 PCSX2 Dev Team
// SPDX-License-Identifier: GPL-3.0+

// AYS2: TargetConditionals in PCH (seam) — our vendored zlib doesn't pull it.
// Ensure Apple's TARGET_OS_* macros (e.g. TARGET_OS_IPHONE) are defined for every
// translation unit that relies on them via the precompiled header. Some sources
// (Image.cpp, ...) branch on TARGET_OS_IPHONE without including TargetConditionals.h
// themselves, and would otherwise treat it as 0.
#ifdef __APPLE__
#include <TargetConditionals.h>
#endif

#include <memory>
#include <atomic>
#include <csignal>
#include <cerrno>
#include <cstdio>