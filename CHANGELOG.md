# Changelog

All notable changes to AYS2 are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- SideStore integration for one-tap installation
- Community Discord links
- GPL-3.0 compliance documentation
- Comprehensive README with SEO optimization
- Issue and PR templates for professional contribution workflow

### Changed
- Migrated release publishing from external repo to main repository
- Updated Worker UI for better user experience

### Fixed
- PhotosPI → PhotosUI import error in Swift

## [0.1.0] - 2026-07-15

### Initial Release

**AYS2** — PlayStation 2 Emulator for iOS based on ARMSX2

#### Features
- Full PS2 emulation on iOS 17.0+
- JIT compilation for high-speed performance
- Universal iPhone and iPad support
- High PS2 game compatibility
- Open source (GPL-3.0 license)
- Easy installation via SideStore/AltStore

#### Architecture
- Built on ARMSX2 (PS2 emulator for ARM)
- Based on PCSX2 core
- Metal graphics rendering
- arm64 architecture support

#### Technical Details
- Bundle ID: `com.ayano.aysx2`
- Minimum iOS: 17.0
- Supported devices: iPhone 11+, all modern iPads
- Internal version: 2.2.2

#### Known Limitations
- JIT support requires compatible device
- Some PS2 titles have limited compatibility
- Performance varies by device capability
- Requires user-provided BIOS and ROM files

---

## Version History

### Format
- **Added** — New features
- **Changed** — Changes to existing functionality
- **Deprecated** — Soon-to-be removed features
- **Removed** — Removed features
- **Fixed** — Bug fixes
- **Security** — Security fixes

### How to Report Bugs
- Create an issue with template: [🐛 Bug Report](.github/ISSUE_TEMPLATE/bug_report.md)
- Provide device info, iOS version, and reproduction steps
- See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines

### How to Request Features
- Create an issue with template: [✨ Feature Request](.github/ISSUE_TEMPLATE/feature_request.md)
- Describe the use case and expected behavior
- Community feedback welcome

---

**Last Updated:** July 2026  
**Current Version:** 0.1.{BUILD_NUMBER}  
**Repository:** https://github.com/st4rwhx/AYS2
