# CDDSwift CLI Usage Guide

The `cdd_swift` CLI provides several subcommands to facilitate Contract-Driven Development.

## Commands

### `from_openapi`
Generates Swift code from an OpenAPI document. This includes `Codable` data models, an async/await `URLSession` API Client, and Delegate protocols for Webhooks and Callbacks.

**Usage:**
```bash
cdd_swift from_openapi -i <input_openapi.json> [--output-path <output.swift>]
```
- `-i, --input`: Path to the OpenAPI 3.2.0 JSON file.
- `-o, --output-path`: (Optional) Where to write the generated Swift code. If omitted, prints to standard output.

---

### `to_openapi`
Parses a Swift source file, extracts `Codable`, `Encodable`, and `Decodable` structs, and converts them into OpenAPI JSON Schema definitions wrapped in a valid OpenAPI Document.

**Usage:**
```bash
cdd_swift to_openapi -f <input.swift> [--output-path <output_openapi.json>]
```
- `-f, --file`: Path to the Swift file containing your models.
- `-o, --output-path`: (Optional) Where to write the generated JSON. If omitted, prints to standard output.

**Supported Swift Types:**
- Primitives: `String`, `Int`, `Int64`, `Double`, `Float`, `Bool`
- Complex: `Date` (mapped to `date-time`), `UUID` (mapped to `uuid`)
- Collections: `Array`, `Dictionary`, Optionals, and Tuples (mapped to `prefixItems`)

---

### `merge-swift`
Safely injects generated Swift code into an existing Swift file without destroying your custom hand-written code.

**Usage:**
```bash
cdd_swift merge-swift <input_openapi.json> <destination.swift>
```
- `<input_openapi.json>`: Path to the OpenAPI JSON file.
- `<destination.swift>`: Path to the existing Swift file.

**How it works:**
In your `destination.swift` file, you must add the following marker comments:
```swift
import Foundation

// MARK: - CDDSwift Auto-Generated Start
// Everything in this block will be overwritten by the generator.
// MARK: - CDDSwift Auto-Generated End

// Your custom code here will be preserved!
extension Customer {
    func getFullName() -> String { return name }
}
```
When you run the command, `cdd_swift` replaces only the text between the markers. If the markers do not exist, it will append the generated code to the end of the file wrapped in the markers.

---

### `generate-open-api`
Generates an example OpenAPI 3.2.0 JSON document using the internal `OpenAPIDocumentBuilder`. This is primarily used for testing and scaffolding out a new API quickly.

**Usage:**
```bash
cdd_swift generate-open-api [--output-path <output.json>]
```
