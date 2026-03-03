# Developing `cdd-swift`

Welcome to `cdd-swift`!

## Dependencies
Ensure you have Swift 5.9+ or 6.0 installed. A `Makefile` and `make.bat` are provided.

```bash
make install_deps
make build
make test
```

## Structure
- `Sources/CDDSwift/`: The compiler core (Frontend parser and Backend emitters).
  - `CDDSwift/openapi`: OpenAPI schemas, structs, generators, and AST parsing logic.
  - `CDDSwift/functions`: Webhook/callback extraction logic.
  - `CDDSwift/routes`: Operations and REST mapping emitters.
- `Sources/cdd-swift-cli/`: The CLI entrypoints and ArgumentParser commands.

## Pre-Commit Hooks
When committing, ensure that you have `.pre-commit-config.yaml` installed using `pre-commit install`. It automatically generates shields for the README and formats the Swift code.
