# Contributing to SA-MP macOS Runner

Thank you for your interest in contributing! This document provides guidelines for contributing to the project.

## Ways to Contribute

### 1. Bug Reports

If you find a bug:

1. Check if it's already reported in [Issues](https://github.com/yourusername/SAmacOS/issues)
2. If not, create a new issue with:
   - Clear title
   - Steps to reproduce
   - Expected vs actual behavior
   - Your system info (Mac model, macOS version, etc.)
   - Relevant logs from `~/Library/Application Support/SA-MP Runner/logs/`

### 2. Feature Requests

Have an idea?

1. Check existing feature requests
2. Create new issue with `enhancement` label
3. Describe:
   - What problem it solves
   - How it should work
   - Why it's useful

### 3. Code Contributions

#### Getting Started

```bash
# Fork the repository
# Clone your fork
git clone https://github.com/yourusername/SAmacOS.git
cd SAmacOS

# Create a branch
git checkout -b feature/your-feature-name

# Install dependencies
./scripts/install-wine.sh
./scripts/setup-dxvk.sh
```

#### Development Setup

**Requirements:**
- macOS 11.0+
- Xcode 14.0+
- Homebrew
- Wine (via Homebrew)

**Build:**
```bash
./scripts/build.sh
```

**Run:**
```bash
./scripts/run-dev.sh
```

#### Code Style

**Swift:**
- Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use 4 spaces for indentation
- Maximum line length: 120 characters
- Use meaningful variable names

**Shell Scripts:**
- Follow [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- Use `#!/bin/bash` shebang
- Add comments for complex logic

**Example Swift:**
```swift
// Good
func installGame(from sourceURL: URL, completion: @escaping (Bool) -> Void) {
    DispatchQueue.global(qos: .userInitiated).async {
        let success = self.performInstallation(from: sourceURL)
        DispatchQueue.main.async {
            completion(success)
        }
    }
}

// Bad
func install(url: URL, cb: @escaping (Bool)->Void){
    DispatchQueue.global().async{
        let s = self.doInstall(url)
        DispatchQueue.main.async{cb(s)}
    }
}
```

#### Testing

Before submitting:

1. **Build succeeds:**
   ```bash
   ./scripts/build.sh
   ```

2. **Manual testing:**
   - Fresh installation works
   - Game launches successfully
   - Settings apply correctly
   - No crashes during normal use

3. **Check logs for errors:**
   ```bash
   tail -f ~/Library/Application\ Support/SA-MP\ Runner/logs/launcher.log
   ```

#### Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
type(scope): subject

body (optional)

footer (optional)
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `style`: Formatting
- `refactor`: Code restructuring
- `perf`: Performance improvement
- `test`: Adding tests
- `chore`: Maintenance

**Examples:**
```
feat(launcher): add server browser integration

- Added server list fetching
- Implemented server search
- Added favorite servers
```

```
fix(wine): resolve shader cache corruption issue

Fixes #123
```

#### Pull Request Process

1. **Update your branch:**
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

2. **Push to your fork:**
   ```bash
   git push origin feature/your-feature-name
   ```

3. **Create Pull Request:**
   - Clear title describing the change
   - Reference related issues
   - Describe what changed and why
   - Include screenshots for UI changes
   - List testing performed

4. **Review process:**
   - Maintainers will review
   - Address feedback
   - Once approved, it will be merged

### 4. Documentation

Help improve docs:

- Fix typos
- Clarify confusing sections
- Add missing information
- Translate to other languages

### 5. Testing

Help test on different Macs:

- Different Mac models (Intel/Apple Silicon)
- Different macOS versions
- Different GTA SA versions
- Various mods

Report your findings in issues or discussions.

## Development Areas

### High Priority

- [ ] Performance optimizations for Intel Macs
- [ ] Better mod compatibility
- [ ] Server browser implementation
- [ ] Auto-update system
- [ ] Improved error handling

### Medium Priority

- [ ] Cloud save synchronization
- [ ] Graphics preset system
- [ ] Skin preview
- [ ] Achievement system
- [ ] In-app mod manager

### Low Priority

- [ ] Themes/customization
- [ ] Statistics tracking
- [ ] Social features
- [ ] Streaming integration

## Project Structure

```
SAmacOS/
├── MacLauncher/          # Native macOS app (Swift)
│   ├── Sources/
│   │   ├── App/          # Main app logic
│   │   ├── UI/           # User interface
│   │   ├── Installer/    # Game installation
│   │   ├── WineManager/  # Wine process management
│   │   └── Performance/  # Optimizations
│   └── Resources/        # Assets
│
├── WineEngine/           # Wine configuration
│   ├── configs/          # Environment configs
│   └── dlls/             # DXVK DLLs
│
├── GameOptimizations/    # Performance configs
│   ├── dxvk/             # DXVK settings
│   └── patches/          # Game patches
│
├── scripts/              # Build scripts
└── docs/                 # Documentation
```

## Community Guidelines

### Code of Conduct

- Be respectful and inclusive
- No harassment or discrimination
- Constructive criticism only
- Help others learn

### Communication

- **Issues:** Bug reports, feature requests
- **Discussions:** Questions, ideas, general chat
- **Pull Requests:** Code contributions

## Recognition

Contributors will be:
- Listed in README
- Credited in release notes
- Appreciated forever! 🙏

## Questions?

- Create a [Discussion](https://github.com/yourusername/SAmacOS/discussions)
- Tag maintainers in issues
- Check existing documentation

---

Thank you for contributing to SA-MP macOS Runner! 🎮
