# Usage

`cdd-swift` provides a CLI to convert between OpenAPI JSON/YAML and Swift.

## CLI Options

- `cdd-swift --help`
- `cdd-swift --version`
- `cdd-swift to_openapi -f <file.swift> -o <openapi.json>`
- `cdd-swift to_docs_json --no-imports --no-wrapping -i <openapi.json>`
- `cdd-swift from_openapi to_sdk -i <openapi.json> -o <target_directory>`
- `cdd-swift from_openapi to_sdk_cli -i <openapi.json> -o <target_directory>`
- `cdd-swift from_openapi to_server -i <openapi.json> -o <target_directory>`

## SDK

You can use `CDDSwift` directly within your project. Ensure you add `.package(url: "https://github.com/offscale/cdd-swift.git", from: "0.0.1")` to your `Package.swift`.
