# Publishing

## Releasing `cdd-swift` Package & CLI

Swift packages and CLI binaries are distributed via Git tags and GitHub Releases (`https://github.com/SamuelMarks/cdd-swift`). To publish a new release:

```bash
git tag v0.0.4
git push origin v0.0.4
```

Consumers can then depend on the tagged version in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/SamuelMarks/cdd-swift.git", from: "0.0.4")
]
```

## Generating & Publishing DocC API Documentation

Build the `CDDSwift` DocC documentation bundle locally using:

```bash
make docs
```

This generates the static documentation bundle in `.build/docs` and links `docs/html` for local previewing or deployment to GitHub Pages.
