# AYS2 — PlayStation 2 Emulator for iOS

[![License: GPL-3.0](https://img.shields.io/badge/License-GPL%203.0-blue.svg)](LICENSE)
[![GitHub release](https://img.shields.io/github/v/release/st4rwhx/AYS2?include_prereleases)](https://github.com/st4rwhx/AYS2/releases)
[![iOS 17.0+](https://img.shields.io/badge/iOS-17.0+-blue.svg)](#requirements)
[![Build Status](https://github.com/st4rwhx/AYS2/actions/workflows/build-ios.yml/badge.svg)](https://github.com/st4rwhx/AYS2/actions)

**AYS2** is a free and open-source PlayStation 2 emulator for iOS, based on [ARMSX2](https://github.com/ARMSX2/ARMSX2). It brings PS2 gaming to iPhone and iPad with high compatibility and performance.

## Features

- 🎮 **Full PS2 Emulation** — Play your favorite PlayStation 2 games on iOS
- ⚡ **JIT Compilation** — High-speed emulation with x86 → ARM64 recompilation
- 📱 **Universal iOS Support** — iPhone and iPad with iOS 17.0 or later
- 🎯 **High Compatibility** — Supports a wide range of PS2 titles
- 🔓 **Open Source** — Licensed under GPL-3.0, source code available
- 📦 **One-Tap Install** — Easy installation via SideStore/AltStore
- 🎮 **Controller Support** — Full gamepad mapping and virtual controller

## Quick Start

### Installation

1. **Get SideStore/AltStore** on your iOS device
2. **Add the Source:**
   ```
   https://aysx2.ayanokiyotakaxpsycoworld.workers.dev
   ```
3. **One-tap Install:**
   ```
   https://aysx2.ayanokiyotakaxpsycoworld.workers.dev/install
   ```

Or manually add from Releases:
- Download the latest `.ipa` from [Releases](https://github.com/st4rwhx/AYS2/releases)
- Sideload using Sideloadly or Xcode

### Requirements

- iOS 17.0 or later
- iPhone 11 or newer (arm64 device)
- 2+ GB available storage
- PS2 BIOS file (dump your own legally)
- PS2 game images (.iso or .chd format)

### First Launch

1. Open AYS2
2. Go to **Storage** → **Import**
3. Import your PS2 BIOS file
4. Import your PS2 game images
5. Select a game and start playing!

## Building from Source

### Prerequisites

- macOS 12+
- Xcode 14+
- CMake 3.21+
- Ninja build system

### Build

```bash
git clone https://github.com/st4rwhx/AYS2.git
cd AYS2

# Configure
cmake -B build -G Xcode \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DARMSX2_REAL_DEVICE=ON \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  src/cpp

# Build
xcodebuild -project build/ARMSX2iOS.xcodeproj \
  -scheme ARMSX2iOS -configuration Release
```

## Documentation

- [Migration Guide](docs/ARMSX2_MIGRATION.md) — ARMSX2 iOS v2.3.0 integration
- [Overlay Pattern](docs/ELORIS_OVERLAY.md) — Customization seams
- [Workers Documentation](source/worker/README.md) — SideStore feed setup

## Community

- **Discord:** [Join us](https://discord.gg/AXAzExECSv)
- **GitHub Issues:** [Report bugs](https://github.com/st4rwhx/AYS2/issues)
- **GitHub Discussions:** [Share ideas](https://github.com/st4rwhx/AYS2/discussions)

## Legal & Compliance

### GPL-3.0 License

AYS2 is licensed under the **GNU General Public License v3.0**. See [LICENSE](LICENSE) for details.

**Important:** This emulator is provided "as-is" for educational and personal use only. Users are responsible for:
- Owning legitimate PS2 BIOS dumps (via homebrew/modchip or official backup)
- Owning or having permission to use PS2 game ROMs
- Compliance with local copyright laws

### Source Code Compliance

As required by GPL-3.0 Section 6, the complete corresponding source code is available:
- In this repository
- In all releases (see `SOURCE-OFFER.txt`)
- Contact: ayanoxkiyotakaxpsycoworld@gmail.com

## Technical Details

### Architecture

- **Emulator Core:** ARMSX2 (PCSX2 fork for ARM)
- **Language:** C++17, Swift (UI)
- **Rendering:** Metal (iOS native graphics)
- **Target:** arm64 (Apple Silicon / iPhone 11+)

### Bundle Identifier

```
com.ayano.aysx2
```

This is a hard constraint to preserve install data and settings across updates.

### Version Scheme

- **Internal:** 2.2.2 (ARMSX2 core version)
- **SideStore Feed:** 0.1.{BUILD_NUMBER} (automated via CI)

### Build System

- **Build Tool:** CMake + Xcode
- **CI/CD:** GitHub Actions
- **Releases:** Automated via GitHub Actions
- **Feed:** Cloudflare Worker proxy

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes (`git commit -m 'Add: my feature'`)
4. Push to the branch (`git push origin feature/my-feature`)
5. Open a Pull Request

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Credits

- **ARMSX2 Project:** [github.com/ARMSX2/ARMSX2](https://github.com/ARMSX2/ARMSX2)
- **PCSX2 Project:** [github.com/PCSX2/pcsx2](https://github.com/PCSX2/pcsx2)
- **AYS2 Contributors:** See [Contributors](https://github.com/st4rwhx/AYS2/graphs/contributors)

## Troubleshooting

### App won't install
- Ensure SideStore/AltStore is installed
- Check that the source URL is correct
- Try removing and re-adding the source

### Games crash or don't boot
- Update to the latest build
- Verify your BIOS dump is correct
- Check game compatibility (not all titles are supported)
- Report the issue on GitHub

### Performance issues
- Close background apps
- Reduce screen resolution settings
- Ensure JIT mode is enabled (if your device supports it)

## Resources

- 📖 **ARMSX2 Docs:** https://armsx2.net
- 🎮 **Compatibility List:** Check [ARMSX2 compatibility](https://github.com/ARMSX2/ARMSX2/discussions)
- 💬 **Discord Community:** https://discord.gg/AXAzExECSv
- 📝 **Issues & Feedback:** https://github.com/st4rwhx/AYS2/issues

## License

```
AYS2 — PlayStation 2 Emulator for iOS
Copyright (C) 2024-2026 AYS2 Contributors

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see <https://www.gnu.org/licenses/>.
```

Based on [ARMSX2](https://github.com/ARMSX2/ARMSX2), which is based on [PCSX2](https://github.com/PCSX2/pcsx2).

---

**Last Updated:** July 2026  
**Repository:** https://github.com/st4rwhx/AYS2  
**Issues:** https://github.com/st4rwhx/AYS2/issues  
**Discord:** https://discord.gg/AXAzExECSv
