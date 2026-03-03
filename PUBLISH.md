# Publishing

### Releasing `cdd-swift` CLI
Since Swift tooling is distributed via GitHub Releases, to publish `cdd-swift` to the most popular location, simply create a new tag and push it:

```bash
git tag v0.0.1
git push origin v0.0.1
```

The GitHub Actions CI pipeline will automatically compile for Ubuntu, macOS, and WebAssembly, and upload the binaries to a new GitHub Release.

### Publishing Docs
To build the API documentation for the CLI locally into a `docs/` folder:

```bash
make build_docs
```

Or deploy to GitHub Pages. `swift-docc-plugin` enables seamless publishing to GitHub pages.

1. Ensure GitHub Actions has write access.
2. The generated documentation can be uploaded as an artifact and deployed to GitHub pages via the `peaceiris/actions-gh-pages` action.
