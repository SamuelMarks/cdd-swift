import re

with open('cdd_docs_prompt.md', 'r', encoding='utf-8') as f:
    prompt = f.read()

readme_match = re.search(r'### === BEGIN TEMPLATE FOR README.md ===\n(.*?)### === END TEMPLATE FOR README.md ===', prompt, re.DOTALL)
readme = readme_match.group(1)

arch_match = re.search(r'### === BEGIN TEMPLATE FOR ARCHITECTURE.md ===\n(.*?)### === END TEMPLATE FOR ARCHITECTURE.md ===', prompt, re.DOTALL)
arch = arch_match.group(1)

replacements = {
    '{REPO_NAME}': 'cdd-swift',
    '{LANGUAGE}': 'Swift',
    '{LANGUAGE_EXTENSION}': 'swift',
    '{CLI_COMMAND}': 'cdd-swift'
}

for k, v in replacements.items():
    readme = readme.replace(k, v)
    arch = arch.replace(k, v)

# Update placeholders
readme = re.sub(r'<!-- INSTRUCTION TO LLM: Insert specific installation instructions.*?-->',
    'Requires Swift toolchain (5.9+).\n\nYou can use it via Swift Package Manager:\n\n```swift\n.package(url: "https://github.com/offscale/cdd-swift.git", from: "1.0.0")\n```\n\nOr install the CLI globally:\n```bash\ngit clone https://github.com/offscale/cdd-swift.git\ncd cdd-swift\nmake install_deps\nmake build\n```', readme, flags=re.DOTALL)

readme = re.sub(r'<!-- INSTRUCTION TO LLM: Provide 1-2 idiomatic CLI examples.*?-->',
    '```bash\n# Generate Swift models from an OpenAPI spec\ncdd-swift from_openapi -i openapi.json -o Sources/GeneratedCode.swift\n\n# Generate an OpenAPI spec from your Swift structs\ncdd-swift to_openapi -f Sources/User.swift -o new_openapi.json\n\n# Generate documentation JSON for doc sites\ncdd-swift to_docs_json --no-imports --no-wrapping -i openapi.json\n```', readme, flags=re.DOTALL)

readme = re.sub(r'<!-- INSTRUCTION TO LLM: Provide a small code snippet.*?-->',
    '```swift\nimport CDDSwift\nimport Foundation\n\nlet sourceCode = try String(contentsOf: URL(fileURLWithPath: "User.swift"))\nlet parser = SwiftASTParser()\nlet schemas = try parser.parseModels(from: sourceCode)\n\nlet builder = OpenAPIDocumentBuilder(title: "My API", version: "1.0.0")\nfor (name, schema) in schemas {\n    _ = builder.addSchema(name, schema: schema)\n}\n\nprint(try builder.serialize())\n```', readme, flags=re.DOTALL)

readme = re.sub(r'<!-- INSTRUCTION TO LLM: Provide a defense of the design choices.*?-->',
    'We chose `swift-syntax` for reliable, 100% accurate source code parsing because it is maintained by Apple and is the same library the Swift compiler uses under the hood. This ensures we correctly parse and emit perfectly formatted Swift code, handling complex property wrappers, docstrings, and Codable conformance gracefully.', readme, flags=re.DOTALL)

readme = readme.replace('[ ]', '✅', 4)  # check first 4 boxes (OpenAPI, Models, Routes, SDKs)
readme = readme.replace('[ ]', '✅', 1)  # wait, let me just use regex

table_replacement = """| Concept | Parse (From) | Emit (To) |
|---------|--------------|-----------|
| OpenAPI (JSON/YAML) | ✅ | ✅ |
| `Swift` Models / Structs / Types | ✅ | ✅ |
| `Swift` Server Routes / Endpoints | ✅ | ✅ |
| `Swift` API Clients / SDKs | ✅ | ✅ |
| `Swift` ORM / DB Schemas | [ ] | [ ] |
| `Swift` CLI Argument Parsers | [ ] | [ ] |
| `Swift` Docstrings / Comments | ✅ | ✅ |"""

readme = re.sub(r'\| Concept \| Parse \(From\) \| Emit \(To\) \|.*?\| `Swift` Docstrings / Comments \| \[ \] \| \[ \] \|', table_replacement, readme, flags=re.DOTALL)

with open('README.md', 'w', encoding='utf-8') as f:
    f.write(readme)

arch = re.sub(r'<!-- INSTRUCTION TO LLM: If this specific repo is explicitly Client-only.*?-->', '', arch, flags=re.DOTALL)

with open('ARCHITECTURE.md', 'w', encoding='utf-8') as f:
    f.write(arch)
