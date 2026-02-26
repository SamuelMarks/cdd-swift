# Publishing `cdd-swift`

This guide explains how to publish the `cdd-swift` package to the broader ecosystem and how to generate and host its documentation.

## 1. Publishing the Package (Swift Package Manager)

Unlike some ecosystems (like Node.js with `npm` or Rust with `crates.io`) where code is uploaded to a centralized registry, **Swift packages are primarily distributed directly via Git repositories** (typically GitHub). 

To publish a new version of `cdd-swift`:

1. Update your `CHANGELOG.md` or release notes.
2. Commit all changes to the repository.
3. Create a Git tag using Semantic Versioning (e.g., `1.0.0`):
   ```bash
   git tag 1.0.0
   git push origin 1.0.0
   ```
4. Create a Release on GitHub pointing to this tag.

**Discoverability (The "Most Popular Location"):** 
To make the package discoverable to the wider Swift ecosystem, submit your repository URL to the **[Swift Package Index](https://swiftpackageindex.com/)**. This acts as the community registry for Swift.

## 2. Generating and Publishing Documentation (DocC)

Apple's **DocC** is the standard documentation compiler for Swift projects.

### A. Generating Docs for a Custom Server (Static Hosting)

To generate a folder of static HTML/JS/CSS files that you can serve from any standard web server (like Nginx, Apache, or AWS S3):

```bash
# Make sure the Swift DocC plugin is available, then run:
swift package --allow-writing-to-directory ./docs 
  generate-documentation --target CDDSwift 
  --output-path ./docs 
  --transform-for-static-hosting 
  --hosting-base-path cdd-swift # Replace with your subpath if not hosting at root
```

You can now zip the `./docs` directory or copy it directly to your static hosting provider.

### B. Publishing Docs to GitHub Pages (Ecosystem Standard)

The most common place to host open-source Swift documentation is GitHub Pages. You can automate this entirely with a GitHub Actions workflow.

Create `.github/workflows/docs.yml`:

```yaml
name: Deploy DocC

on:
  push:
    branches: ["main"]

permissions:
  contents: read
  pages: write
  id-token: write

jobs:
  deploy:
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build DocC
        run: |
          swift package --allow-writing-to-directory ./docs 
            generate-documentation --target CDDSwift 
            --output-path ./docs 
            --transform-for-static-hosting 
            --hosting-base-path cdd-swift # Update to match your repo name
      - name: Upload artifact
        uses: actions/upload-pages-artifact@v3
        with:
          path: './docs'
      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v4
```