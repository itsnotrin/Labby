# Contributing to Labby

Thank you for considering contributing to Labby! We welcome contributions in code, documentation, testing, and service integrations. This guide will help you get started and ensure your contributions align with the project's goals.

## Ways to Contribute

### 🐛 Bug Reports
- Use the [GitHub Issues](../../issues) tracker
- Include detailed reproduction steps
- Provide iOS version, device model, and Labby version
- Add screenshots or recordings when helpful

### 💡 Feature Requests
- Check existing issues first to avoid duplicates
- Clearly describe the problem you're solving
- Provide context about your use case
- Consider implementation complexity

### 📝 Documentation
- Fix typos and improve clarity
- Add missing setup guides for services
- Update outdated information
- Translate documentation (future consideration)

### 🔧 Code Contributions
- Bug fixes and performance improvements
- New service integrations
- UI/UX enhancements
- Test coverage improvements

## Development Setup

### Prerequisites
- **macOS** with Xcode 14.0 or later
- **iOS 15.0+ device or simulator** for testing
- **Git** for version control
- Access to **self-hosted services** for testing integrations

### Getting Started
1. **Fork and Clone**
   ```bash
   git clone https://github.com/your-username/Labby.git
   cd Labby
   ```

2. **Open in Xcode**
   ```bash
   open Labby.xcodeproj
   ```

3. **Build and Run**
   - Select your target device/simulator
   - Press Cmd+R to build and run
   - Verify the app launches successfully

4. **Create a Branch**
   ```bash
   git checkout -b feature/your-feature-name
   # or
   git checkout -b fix/issue-description
   ```

## Code Standards

### Swift Style Guide
- **Naming**: Use descriptive names for variables, functions, and types
- **Formatting**: Follow Xcode's default formatting (Ctrl+I)
- **Comments**: Keep inline comments minimal; prefer self-documenting code
- **Documentation**: Use Swift documentation comments for public APIs

### Project Structure
```
Labby/
├── LabbyApp.swift              # App entry point
├── ContentView.swift           # Main tab interface
├── Managers/                   # Core system managers
├── Models/                     # Data models and enums
├── Services/                   # Service integrations
│   ├── ServiceClient.swift    # Protocol definition
│   ├── ServiceManager.swift   # Client factory
│   └── [ServiceName]/         # Individual service implementations
└── Views/                      # SwiftUI views
    └── Core/                   # Main app views
```

### Architecture Principles
- **Protocol-Oriented**: Use protocols for service clients and common interfaces
- **SwiftUI + Combine**: Reactive UI with ObservableObject pattern
- **Async/Await**: Modern concurrency for network operations
- **Local-First**: No cloud dependencies, secure local storage

## Contributing Process

### 1. Planning
- **Check existing issues** to avoid duplicate work
- **Open a discussion** for major features or architectural changes
- **Start small** with bug fixes or documentation improvements

### 2. Implementation
- **Write clean code** following project conventions
- **Add appropriate error handling** for network operations
- **Include unit tests** for new functionality when possible
- **Update documentation** for user-facing changes

### 3. Testing Requirements
- **Manual testing** on iOS device or simulator
- **Test all supported service types** if making core changes
- **Verify edge cases** like network failures and invalid credentials
- **Check both light and dark mode** appearances

### 4. Pull Request Guidelines
- **Clear title and description** explaining the change
- **Reference related issues** using "Fixes #123" syntax
- **Include screenshots** for UI changes
- **List breaking changes** if any
- **Small, focused PRs** are preferred over large ones

## Service Integration Guidelines

### Adding New Services
1. **Research the API** - Documentation, authentication methods, endpoints
2. **Follow the guide** in [Adding New Services](adding-new-services.md)
3. **Implement incrementally** - Start with basic connectivity, add features gradually
4. **Create setup documentation** following existing service guide formats

### Service Client Requirements
- Implement `ServiceClient` protocol
- Support connection testing
- Handle authentication securely via Keychain
- Provide meaningful error messages
- Use async/await for network operations
- Support SSL certificate bypass option

### Widget Integration
- Define service-specific metrics enum
- Add to `WidgetMetricsSelection` and `ServiceStatsPayload`
- Implement stat formatting for different widget sizes
- Choose appropriate default widget sizes and metrics

## Code Review Process

### What We Look For
- **Functionality**: Does it work as intended?
- **Code Quality**: Is it readable, maintainable, and well-structured?
- **Performance**: Are there any efficiency concerns?
- **Security**: Proper handling of credentials and user data?
- **User Experience**: Intuitive and consistent with app patterns?

### Review Timeline
- Initial review within **1-2 weeks** for active contributions
- Feedback provided through GitHub's review system
- Multiple review rounds may be needed for complex changes
- Maintainers may request changes or provide suggestions

## Coding Best Practices

### Error Handling
```swift
// Good: Specific error types
throw ServiceError.httpStatus(response.statusCode)

// Bad: Generic errors
throw ServiceError.unknown
```

### Async Operations
```swift
// Good: Proper async/await usage
func fetchData() async throws -> Data {
    let (data, _) = try await session.data(for: request)
    return data
}
```

### SwiftUI Patterns
```swift
// Good: Extract complex views
struct ServiceCard: View {
    let service: ServiceConfig
    var body: some View { /* ... */ }
}

// Good: Use @StateObject for data that survives view updates
@StateObject private var serviceManager = ServiceManager.shared
```

## Security Guidelines

### Credential Handling
- **Never commit** credentials or API keys
- **Always use KeychainStorage** for sensitive data
- **Validate input** from external APIs
- **Use HTTPS** when possible

### Network Security
- Support SSL certificate bypass for self-signed certificates
- Implement proper timeout values
- Handle network errors gracefully
- Don't log sensitive information

## Release Process

### Version Numbering
- Follow semantic versioning (MAJOR.MINOR.PATCH)
- Major: Breaking changes or significant new features
- Minor: New features, service additions
- Patch: Bug fixes, documentation updates

### Release Checklist
- All tests pass
- Documentation updated
- Version numbers incremented
- Release notes prepared
- IPA built and tested

## Community Guidelines

### Communication
- **Be respectful** and constructive in all interactions
- **Help newcomers** get started with the project
- **Share knowledge** through documentation and examples
- **Ask questions** when unsure about implementation details

### Recognition
- Contributors are recognized in release notes
- Significant contributions may be highlighted in the README
- All contributors are valued regardless of contribution size

## Getting Help

### Resources
- **Documentation**: Start with the [docs/](.) directory
- **Code Examples**: Look at existing service implementations
- **GitHub Discussions**: For questions and community help
- **Issues**: For bug reports and feature requests

### Mentorship
- New contributors are welcome to ask for guidance
- Maintainers can provide code review and suggestions
- Consider starting with "good first issue" labeled items

---

**Questions?** Don't hesitate to ask! Open a discussion or create an issue. We're here to help make your contribution successful.

**Thank you** for helping make Labby better for the entire self-hosting community! 🚀
