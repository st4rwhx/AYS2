# Security Policy

## Reporting Vulnerabilities

If you discover a security vulnerability, **do NOT open a public GitHub issue**. Instead:

1. **Email:** security@ayanoxkiyotakaxpsycoworld.com (or contact via Discord DM)
2. **Include:**
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if available)

3. **Timeline:**
   - We'll acknowledge within 48 hours
   - Work toward a fix within 7 days
   - Coordinated public disclosure after patch release

## Supported Versions

| Version | Support |
|---------|---------|
| 0.1.x   | Current |

Security updates will be released as needed. Always keep AYS2 updated.

## Known Limitations

- AYS2 requires iOS 17.0+ for JIT support
- Some PS2 titles may have compatibility issues
- Performance varies by device
- BIOS dumping is user's responsibility

## Best Practices

### For Users

- Keep iOS updated
- Only download AYS2 from official sources (GitHub, SideStore)
- Verify checksums in releases
- Don't install from untrusted sources
- Report suspicious behavior

### For Developers

- Don't commit secrets or credentials
- Use `@Sensitive` for password fields
- Sanitize user input
- Follow Apple security guidelines
- Report security issues responsibly

## Dependencies

AYS2 relies on:
- **ARMSX2** — Core emulation
- **PCSX2** — Base emulator
- **SDL3** — Input handling
- **Metal** — Graphics API

We monitor these projects for security updates and patch as needed.

## Compliance

- **License:** GPL-3.0 (open source, auditable)
- **BIOS:** Users must provide their own (legal responsibility)
- **ROMs:** Users must own copies (legal responsibility)
- **Copyright:** Respects copyright holders

## Contact

- **Security:** security@ayanoxkiyotakaxpsycoworld.com
- **Discord:** https://discord.gg/AXAzExECSv
- **GitHub Issues:** https://github.com/st4rwhx/AYS2/issues
