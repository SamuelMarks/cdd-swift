# Publishing cdd-swift

For Swift, packages are distributed via Swift Package Manager directly from GitHub or published to the Swift Package Index.

## Swift Package Index

1. Ensure your repository has a valid `Package.swift`.
2. Tag your releases (e.g., `0.0.1`).
3. Submit your GitHub repository URL to the [Swift Package Index](https://swiftpackageindex.com/). It will automatically build and publish your package documentation.

## Manual Documentation Publishing

1. **Build Docs Locally**:
   ```bash
   make build_docs
   ```
   This will output static HTML files into the `docs/` directory.

2. **Upload to Server**:
   You can copy the contents of `docs/` to any static server or GitHub pages.
   ```bash
   scp -r docs/* user@yourserver:/var/www/docs
   ```
