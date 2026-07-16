# Contributing to AYS2

Thank you for your interest in contributing to AYS2! This document provides guidelines and instructions for contributing.

## Code of Conduct

Be respectful, constructive, and inclusive. Discrimination, harassment, or hostility will not be tolerated.

## How to Contribute

### Reporting Issues

1. Check [existing issues](https://github.com/st4rwhx/AYS2/issues) to avoid duplicates
2. Use the issue template provided
3. Include:
   - iOS version
   - Device model
   - AYS2 version
   - Steps to reproduce
   - Expected vs. actual behavior
   - Game title (if applicable)

### Suggesting Features

1. Check [discussions](https://github.com/st4rwhx/AYS2/discussions) first
2. Describe the feature and use case clearly
3. Explain why it's beneficial
4. Be open to feedback

### Code Contributions

#### Prerequisites

- macOS 12+
- Xcode 14+
- CMake 3.21+
- Ninja build system
- Git

#### Workflow

1. **Fork** the repository
2. **Clone** your fork:
   ```bash
   git clone https://github.com/YOUR-USERNAME/AYS2.git
   cd AYS2
   ```
3. **Create a branch:**
   ```bash
   git checkout -b feature/my-feature
   # or for bug fixes:
   git checkout -b fix/issue-number
   ```
4. **Make changes** following the [style guide](#style-guide)
5. **Commit** with clear messages:
   ```bash
   git commit -m "Add: feature description"
   # or
   git commit -m "Fix: bug description"
   ```
6. **Push** to your fork:
   ```bash
   git push origin feature/my-feature
   ```
7. **Open a Pull Request** with:
   - Clear title and description
   - Reference to related issues (`Fixes #123`)
   - Summary of changes
   - Testing performed

#### PR Guidelines

- PRs should target the `main` branch
- Keep PRs focused on a single feature/fix
- Update documentation if needed
- Ensure builds pass (GitHub Actions)
- Be responsive to review feedback

### Documentation Contributions

1. Fork and clone the repository
2. Edit `.md` files in `/docs` or `/source/worker`
3. Keep markdown consistent with existing style
4. Test links work correctly
5. Submit a PR with your changes

## Style Guide

### C++ (src/cpp/)

- Follow PCSX2/ARMSX2 conventions
- Use C++17 features
- Prefer standard library over custom solutions
- Add comments for complex logic
- Keep functions under 50 lines when possible

### Swift (src/swift/)

- Follow Apple Swift style guide
- Use meaningful variable names
- Mark `@State`, `@Binding` clearly
- Keep SwiftUI views under 100 lines
- Add documentation comments for public APIs

### Git Commits

Format: `<type>: <description>`

Types:
- `feat` / `Feature` — New feature
- `fix` / `Fix` — Bug fix
- `refactor` — Code refactoring
- `docs` — Documentation
- `ci` — CI/CD changes
- `chore` — Maintenance

Examples:
```
feat: Add controller profile switching
fix: Resolve memory leak in GPU renderer
docs: Update installation guide
ci: Add macOS 14 to build matrix
```

## Testing

Before submitting:

1. **Build locally:**
   ```bash
   cmake -B build -G Xcode src/cpp
   xcodebuild -project build/ARMSX2iOS.xcodeproj -scheme ARMSX2iOS
   ```

2. **Test on device or simulator** (iOS 17+)

3. **Test with multiple games** if applicable

4. **Verify no regressions** in existing functionality

## License

By contributing, you agree that your contributions will be licensed under the GPL-3.0 License (same as AYS2).

## Getting Help

- **Questions:** [GitHub Discussions](https://github.com/st4rwhx/AYS2/discussions)
- **Chat:** [Discord Community](https://discord.gg/AXAzExECSv)
- **Issues:** [GitHub Issues](https://github.com/st4rwhx/AYS2/issues)

## Recognition

Contributors are recognized in:
- [CONTRIBUTORS.md](CONTRIBUTORS.md)
- GitHub Contributors page
- Release notes (for major contributions)

Thank you for contributing to AYS2! 🎮
