# Developing CDDSwift

Thank you for your interest in contributing to CDDSwift! This guide will help you set up your development environment and understand the workflow.

## Prerequisites
- Swift 5.9 or higher (Swift 6 recommended)
- A macOS or Linux environment
- (Optional) An editor with Swift support (Xcode, VSCode with Swift extension, etc.)

## Project Structure
- `Sources/CDDSwift/`: The core library. Contains the AST parser, OpenAPI models, Swift code generator, and merger.
- `Sources/cdd_swift-cli/`: The executable target containing the `ArgumentParser` CLI definitions.
- `Tests/CDDSwiftTests/`: The XCTest suite verifying model encoding/decoding, generation, parsing, and merging logic.

## Building the Project
To build the CLI executable and library:
```bash
swift build
```

## Running Tests
Ensure all tests pass before submitting a Pull Request:
```bash
swift test
```
To generate code coverage reports:
```bash
swift test --enable-code-coverage
```

## Running the CLI Locally
You can run the CLI directly from the source using `swift run`:
```bash
swift run cdd_swift --help
```
For example, to test parsing a file:
```bash
swift run cdd_swift to_openapi -f path/to/your/File.swift
```

## Making Changes
1. **Models**: If you are updating `OpenAPIModels.swift` to support a new edge case in the specification, ensure you test both `JSONEncoder` and `JSONDecoder` paths in `CDDSwiftTests`.
2. **Generators**: If you are modifying `OpenAPIToSwiftGenerator`, verify that the generated Swift code compiles correctly. You can test this by piping the output to a temporary `.swift` file and running `swiftc` on it.
3. **AST Parser**: If modifying `SwiftASTParser`, you will need to familiarize yourself with `SwiftSyntax`. The parser uses a `SyntaxVisitor` to traverse the tree.

## Code Style
- Try to keep generated code neat and properly indented.
- Stick to standard Swift conventions for the library code.
- Avoid external dependencies unless absolutely necessary. (Currently relying only on `swift-argument-parser` and `swift-syntax`).

## Pull Requests
1. Fork the repository.
2. Create a feature branch.
3. Implement your changes along with tests.
4. Open a Pull Request against the `master` branch.
