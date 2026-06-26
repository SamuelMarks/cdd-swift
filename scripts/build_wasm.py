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

    swift_bin = shutil.which("swift")
    if not swift_bin:
        print("Error: swift not found in PATH.")
        sys.exit(1)

    try:
        swift_ver = check_output([swift_bin, "--version"])
    except Exception as e:
        print(f"Failed to check swift version: {e}")
        sys.exit(1)

    if "Apple Swift" in swift_ver:
        # Check brew paths for open source swift on macOS
        brew_swift_path = "/opt/homebrew/opt/swift/bin" + os.pathsep + "/usr/local/opt/swift/bin"
        brew_swift = shutil.which("swift", path=brew_swift_path)
        if brew_swift:
            print("Using Homebrew Swift for WASM support...")
            swift_bin = brew_swift
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
        print(f"Please install one. For example: {swift_bin} sdk install https://github.com/swiftwasm/swift/releases/download/swift-wasm-6.0.3-RELEASE/swift-wasm-6.0.3-RELEASE-wasm32-unknown-wasi.artifactbundle.zip")
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

    base_build = ".build"
    possible_outputs = [
        os.path.join(base_build, "wasm32-unknown-wasip1", "release", "cdd-swift.wasm"),
        os.path.join(base_build, "wasm32-unknown-wasip1", "release", "cdd-swift"),
        os.path.join(base_build, "wasm32-unknown-wasi", "release", "cdd-swift.wasm"),
        os.path.join(base_build, "wasm32-unknown-wasi", "release", "cdd-swift"),
        os.path.join(base_build, "wasm32-unknown-wasi", "release", "cdd-swift-cli.wasm"),
        os.path.join(base_build, "wasm32-unknown-wasi", "release", "cdd-swift-cli"),
        os.path.join(base_build, "release", "cdd-swift.wasm"),
        os.path.join(base_build, "release", "cdd-swift-cli.wasm")
    ]

    for p in possible_outputs:
        if os.path.exists(p):
            out_path = os.path.join("bin", "cdd-swift.wasm")
            shutil.copy(p, out_path)
            print(f"Copied {p} to {out_path}")
            sys.exit(0)

    print("Could not find the built WASM binary.")
    sys.exit(1)

if __name__ == "__main__":
    main()
