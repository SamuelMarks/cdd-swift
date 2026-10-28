"""Build and optimize the cdd-swift WebAssembly (WASI) binary."""

import os
import shutil
import subprocess
import sys
import tempfile
from typing import List


def run_cmd(
    cmd: List[str], check: bool = True
) -> subprocess.CompletedProcess[bytes]:
    """Execute a subprocess command and echo it to stdout.

    Args:
        cmd: The command and arguments list to execute.
        check: Whether to raise CalledProcessError on a non-zero exit code.

    Returns:
        The completed subprocess result.
    """
    print(f"Running: {' '.join(cmd)}")
    return subprocess.run(cmd, check=check, capture_output=False)


def check_output(cmd: List[str]) -> str:
    """Execute a command and return its captured stdout as a string.

    Args:
        cmd: The command and arguments list to execute.

    Returns:
        The captured standard output string.
    """
    return subprocess.run(cmd, capture_output=True, text=True).stdout


def main() -> None:
    """Locate an open-source Swift toolchain + WASM SDK, build cdd-swift.wasm, and optimize it."""
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
        brew_swift_path = (
            "/opt/homebrew/opt/swift/bin" + os.pathsep + "/usr/local/opt/swift/bin"
        )
        brew_swift = shutil.which("swift", path=brew_swift_path)
        if brew_swift:
            print("Using Homebrew Swift for WASM support...")
            swift_bin = brew_swift
        else:
            print("Error: Apple Swift does not support WASM compilation.")
            print("Please install the official open-source Swift toolchain:")
            print("  brew install swift")
            sys.exit(1)

    sdk_proc = subprocess.run(
        [swift_bin, "sdk", "list"], capture_output=True, text=True
    )
    if sdk_proc.returncode != 0:
        print(
            f"Error: Failed to run '{swift_bin} sdk list' (exit code {sdk_proc.returncode})."
        )
        if sdk_proc.returncode in (-9, 137):
            print(
                "The Swift binary was killed by SIGKILL (likely macOS Gatekeeper / invalidated code signatures in Homebrew Swift)."
            )
            print("Re-sign the Homebrew Swift toolchain libraries with:")
            print(
                '  find /opt/homebrew/Cellar/swift -type f | while read -r f; do if codesign -vvv "$f" 2>&1 | grep -q "invalid signature"; then codesign -f -s - "$f"; fi; done'
            )
        sys.exit(1)

    sdks_output = sdk_proc.stdout
    available_sdks: List[str] = [
        line.strip()
        for line in sdks_output.split("\n")
        if ("wasm32-unknown-wasi" in line or "_wasm" in line) and "embedded" not in line
    ]

    if not available_sdks:
        print("Error: No WebAssembly Swift SDK found.")
        print(
            "Please install one matching your Swift toolchain version. For example (Swift 6.4.0):"
        )
        print(
            f"  {swift_bin} sdk install https://download.swift.org/swift-6.4.0-release/wasm-sdk/swift-6.4.0-RELEASE/swift-6.4.0-RELEASE_wasm.artifactbundle.tar.gz --checksum f07b7be3c586d92d7a07051fc6d303b87ebea67eadc40640ba59d5a8b79aa86d"
        )
        print("Or for Swift 6.0.3 (SwiftWasm):")
        print(
            f"  {swift_bin} sdk install https://github.com/swiftwasm/swift/releases/download/swift-wasm-6.0.3-RELEASE/swift-wasm-6.0.3-RELEASE-wasm32-unknown-wasi.artifactbundle.zip --checksum 31d3585b06dd92de390bacc18527801480163188cd7473f492956b5e213a8618"
        )
        sys.exit(1)

    # Hide wasm-opt from PATH during `swift build` so the WASI clang driver / wasm-ld
    # does not implicitly run an unconfigured `wasm-opt` pass without WebAssembly
    # feature flags (such as --enable-sign-ext and --enable-bulk-memory), which fails
    # validation on Binaryen versions (e.g. Binaryen 108 on Ubuntu) that default to MVP-only.
    build_env = os.environ.copy()
    wasm_opt_bin = shutil.which("wasm-opt")
    shim_dir = ""
    if wasm_opt_bin:
        shim_dir = tempfile.mkdtemp(prefix="swift_wasm_path_")
        orig_dirs = build_env.get("PATH", "").split(os.pathsep)
        filtered_dirs: List[str] = []
        for d in orig_dirs:
            if d and os.path.exists(os.path.join(d, "wasm-opt")):
                # Populate shim_dir with symlinks to all binaries in d except wasm-opt
                try:
                    for entry in os.listdir(d):
                        if entry == "wasm-opt":
                            continue
                        src = os.path.join(d, entry)
                        dst = os.path.join(shim_dir, entry)
                        if not os.path.exists(dst) and os.access(src, os.X_OK):
                            os.symlink(src, dst)
                except OSError:
                    pass
            else:
                filtered_dirs.append(d)
        build_env["PATH"] = os.pathsep.join([shim_dir] + filtered_dirs)

    success = False
    for sdk in available_sdks:
        print(f"Trying Swift SDK: {sdk}")
        result = subprocess.run(
            [
                swift_bin,
                "build",
                "--swift-sdk",
                sdk,
                "-c",
                "release",
                "-Xswiftc",
                "-Osize",
                "-Xswiftc",
                "-gnone",
                "-Xlinker",
                "--gc-sections",
                "-Xlinker",
                "--strip-all",
            ],
            env=build_env,
        )
        if result.returncode == 0:
            success = True
            break
        else:
            print(f"Failed to build with SDK {sdk}. Trying next...")

    if shim_dir:
        shutil.rmtree(shim_dir, ignore_errors=True)

    if not success:
        print(
            "Error: Failed to build WASM with any available SDK. Ensure your SDK version matches your Swift compiler version."
        )
        sys.exit(1)

    base_build = ".build"
    possible_outputs = [
        os.path.join(
            base_build,
            "out",
            "Products",
            "Release-webassembly-wasm32",
            "cdd-swift.wasm",
        ),
        os.path.join(base_build, "wasm32-unknown-wasip1", "release", "cdd-swift.wasm"),
        os.path.join(base_build, "wasm32-unknown-wasip1", "release", "cdd-swift"),
        os.path.join(base_build, "wasm32-unknown-wasi", "release", "cdd-swift.wasm"),
        os.path.join(base_build, "wasm32-unknown-wasi", "release", "cdd-swift"),
        os.path.join(
            base_build, "wasm32-unknown-wasi", "release", "cdd-swift-cli.wasm"
        ),
        os.path.join(base_build, "wasm32-unknown-wasi", "release", "cdd-swift-cli"),
        os.path.join(base_build, "release", "cdd-swift.wasm"),
        os.path.join(base_build, "release", "cdd-swift-cli.wasm"),
    ]

    for p in possible_outputs:
        if os.path.exists(p):
            out_path = os.path.join("bin", "cdd-swift.wasm")
            shutil.copy(p, out_path)
            wasm_strip = shutil.which("wasm-strip")
            if wasm_strip:
                run_cmd([wasm_strip, out_path], check=False)
            if wasm_opt_bin:
                opt_path = out_path + ".opt"
                opt_res = subprocess.run(
                    [
                        wasm_opt_bin,
                        "-Oz",
                        "--all-features",
                        out_path,
                        "-o",
                        opt_path,
                    ]
                )
                if opt_res.returncode == 0 and os.path.exists(opt_path):
                    shutil.move(opt_path, out_path)
            size_mb = os.path.getsize(out_path) / (1024 * 1024)
            print(f"Copied and optimized {p} -> {out_path} ({size_mb:.2f} MB)")
            sys.exit(0)

    print("Could not find the built WASM binary.")
    sys.exit(1)


if __name__ == "__main__":
    main()
