import os
import sys
import shutil
import subprocess

def run_cmd(cmd, check=True):
    print(f"Running: {' '.join(cmd)}")
    return subprocess.run(cmd, check=check, capture_output=False)

def check_output(cmd):
    return subprocess.run(cmd, capture_output=True, text=True).stdout

def main():
    if not os.path.exists("bin"):
        os.makedirs("bin")

    print("Building WASM binary for Swift...")

    swift_bin = "swift"
    if "Apple Swift" in check_output([swift_bin, "--version"]):
        if os.path.exists("/opt/homebrew/opt/swift/bin/swift"):
            print("Using Homebrew Swift for WASM support...")
            swift_bin = "/opt/homebrew/opt/swift/bin/swift"
        elif os.path.exists("/usr/local/opt/swift/bin/swift"):
            print("Using Homebrew Swift for WASM support...")
            swift_bin = "/usr/local/opt/swift/bin/swift"
        else:
            print("Error: Apple Swift does not support WASM compilation.")
            print("Please install the official open-source Swift toolchain:")
            print("  brew install swift")
            sys.exit(1)

    sdks_output = check_output([swift_bin, "sdk", "list"])
    available_sdks = [line.strip() for line in sdks_output.split("\n")
                      if ("wasm32-unknown-wasi" in line or "_wasm" in line) and "embedded" not in line]

    if not available_sdks:
        print("Error: No WebAssembly Swift SDK found.")
        print("Please install one. For example:")
        print(f"  {swift_bin} sdk install https://github.com/swiftwasm/swift/releases/download/swift-wasm-6.0.3-RELEASE/swift-wasm-6.0.3-RELEASE-wasm32-unknown-wasi.artifactbundle.zip")
        sys.exit(1)

    success = False
    for sdk in available_sdks:
        print(f"Trying Swift SDK: {sdk}")
        result = subprocess.run([swift_bin, "build", "--swift-sdk", sdk, "-c", "release"])
        if result.returncode == 0:
            success = True
            break
        else:
            print(f"Failed to build with SDK {sdk}. Trying next...")

    if not success:
        print("Error: Failed to build WASM with any available SDK. Ensure your SDK version matches your Swift compiler version.")
        sys.exit(1)

    possible_outputs = [
        ".build/wasm32-unknown-wasip1/release/cdd-swift.wasm",
        ".build/wasm32-unknown-wasip1/release/cdd-swift",
        ".build/wasm32-unknown-wasi/release/cdd-swift.wasm",
        ".build/wasm32-unknown-wasi/release/cdd-swift",
        ".build/wasm32-unknown-wasi/release/cdd-swift-cli.wasm",
        ".build/wasm32-unknown-wasi/release/cdd-swift-cli",
        ".build/release/cdd-swift.wasm",
        ".build/release/cdd-swift-cli.wasm",
        ".build\\wasm32-unknown-wasielease\\cdd-swift.wasm",
        ".build\\wasm32-unknown-wasielease\\cdd-swift"
    ]

    for p in possible_outputs:
        if os.path.exists(p):
            shutil.copy(p, "bin/cdd-swift.wasm")
            print(f"Copied {p} to bin/cdd-swift.wasm")
            sys.exit(0)

    print("Could not find the built WASM binary.")
    sys.exit(1)

if __name__ == "__main__":
    main()
