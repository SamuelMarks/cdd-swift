"""Update test and documentation coverage shields.io badges in README.md."""

import glob
import os
import re
import shutil
import subprocess
import sys
from typing import List, Optional


def get_color(percentage: float) -> str:
    """Map a coverage percentage (0-100) to a shields.io badge color name.

    Args:
        percentage: The coverage percentage from 0.0 to 100.0.

    Returns:
        The shields.io badge color string.
    """
    if percentage >= 90:
        return 'brightgreen'
    elif percentage >= 80:
        return 'green'
    elif percentage >= 70:
        return 'yellowgreen'
    elif percentage >= 60:
        return 'yellow'
    elif percentage >= 50:
        return 'orange'
    else:
        return 'red'


def get_llvm_cov_cmd() -> Optional[List[str]]:
    """Locate the `llvm-cov` command or `xcrun llvm-cov` wrapper on the host.

    Returns:
        A list of command arguments to invoke `llvm-cov`, or `None` if unavailable.
    """
    if shutil.which("llvm-cov"):
        return ["llvm-cov"]
    if shutil.which("xcrun"):
        return ["xcrun", "llvm-cov"]

    # Check next to swift binary
    swift_bin = shutil.which("swift")
    if swift_bin:
        llvm_cov_path = os.path.join(os.path.dirname(swift_bin), "llvm-cov")
        if os.path.exists(llvm_cov_path):
            return [llvm_cov_path]
        if os.name == 'nt' and os.path.exists(llvm_cov_path + ".exe"):
            return [llvm_cov_path + ".exe"]
    return None


def resolve_test_binaries(bin_path: str) -> List[str]:
    """Resolve all `.xctest` bundles in `bin_path` to their executable binary paths.

    Args:
        bin_path: The Swift build products directory path.

    Returns:
        A sorted list of resolved test executable paths.
    """
    xctests = sorted(glob.glob(os.path.join(bin_path, '*.xctest')))
    test_bins: List[str] = []
    for test_bundle in xctests:
        if os.path.isdir(test_bundle):
            name = os.path.basename(test_bundle).replace('.xctest', '')
            mac_bin = os.path.join(test_bundle, 'Contents', 'MacOS', name)
            if os.path.exists(mac_bin):
                test_bins.append(mac_bin)
            else:
                test_bins.append(test_bundle)
        else:
            test_bins.append(test_bundle)
    return test_bins


def parse_llvm_cov_total(stdout: str) -> Optional[float]:
    """Parse the `TOTAL` summary row from `llvm-cov report` output.

    Returns the minimum coverage percentage across regions, functions, and lines.

    Args:
        stdout: The standard output string from `llvm-cov report`.

    Returns:
        The coverage percentage as a float, or `None` if no valid `TOTAL` line is found.
    """
    for line in stdout.splitlines():
        if line.startswith('TOTAL'):
            pcts = [float(x) for x in re.findall(r'([0-9]+\.[0-9]+)%', line)]
            if pcts:
                return min(pcts)
    return None


def run_llvm_cov_report(llvm_cov_cmd: List[str], profdata: str, test_bins: List[str]) -> Optional[float]:
    """Execute `llvm-cov report` across all test binaries and return the total coverage.

    Args:
        llvm_cov_cmd: The base command list for `llvm-cov`.
        profdata: Path to `default.profdata`.
        test_bins: List of test executable paths.

    Returns:
        The calculated coverage percentage, or `None` if execution fails.
    """
    if not test_bins or not os.path.exists(profdata):
        return None

    object_args: List[str] = [test_bins[0]]
    for extra_bin in test_bins[1:]:
        object_args.extend(['-object', extra_bin])

    cmd = (
        llvm_cov_cmd
        + ['report', '-instr-profile', profdata]
        + object_args
        + ['-ignore-filename-regex=\\.build', os.path.join('Sources', 'CDDSwift'), os.path.join('Sources', 'cdd-swift-cli')]
    )
    report = subprocess.run(cmd, capture_output=True, text=True)
    if report.returncode != 0:
        return None

    return parse_llvm_cov_total(report.stdout)


def get_test_coverage() -> float:
    """Calculate the combined test coverage percentage across all Swift targets.

    If coverage artifacts (`*.xctest` and `default.profdata`) are missing or stale,
    automatically invokes `swift test --enable-code-coverage` first.

    Returns:
        The test coverage percentage from 0.0 to 100.0.
    """
    swift_bin = shutil.which('swift')
    if not swift_bin:
        print("Swift not found.")
        return 0.0

    llvm_cov_cmd = get_llvm_cov_cmd()
    if not llvm_cov_cmd:
        print("llvm-cov not found.")
        return 0.0

    result = subprocess.run([swift_bin, 'build', '--show-bin-path'], capture_output=True, text=True)
    if result.returncode != 0:
        print("Error getting bin path.")
        return 0.0
    bin_path = result.stdout.strip()

    test_bins = resolve_test_binaries(bin_path)
    profdata = os.path.join(bin_path, 'codecov', 'default.profdata')

    cov = run_llvm_cov_report(llvm_cov_cmd, profdata, test_bins)
    if cov is None or cov == 0.0:
        test_run = subprocess.run([swift_bin, 'test', '--enable-code-coverage'], capture_output=True, text=True)
        if test_run.returncode != 0:
            print(f"swift test failed:\n{test_run.stderr}")
            return 0.0
        result = subprocess.run([swift_bin, 'build', '--show-bin-path'], capture_output=True, text=True)
        if result.returncode == 0:
            bin_path = result.stdout.strip()
        test_bins = resolve_test_binaries(bin_path)
        profdata = os.path.join(bin_path, 'codecov', 'default.profdata')
        cov = run_llvm_cov_report(llvm_cov_cmd, profdata, test_bins)

    return cov if cov is not None else 0.0


def get_doc_coverage() -> float:
    """Calculate the documentation coverage percentage across `Sources/`.

    Returns:
        The documentation coverage percentage from 0.0 to 100.0.
    """
    decl_pattern = re.compile(r'^\s*(?:public\s+|internal\s+|fileprivate\s+|private\s+)?(?:final\s+)?(?:class|struct|enum|protocol|func)\s+[A-Za-z0-9_]+')
    total_decls = 0
    documented_decls = 0

    for root, _, files in os.walk('Sources'):
        for file in files:
            if not file.endswith('.swift'):
                continue
            with open(os.path.join(root, file), 'r', encoding='utf-8') as f:
                lines = f.readlines()

            for i, line in enumerate(lines):
                if decl_pattern.search(line):
                    total_decls += 1
                    j = i - 1
                    is_documented = False
                    while j >= 0:
                        prev_line = lines[j].strip()
                        if not prev_line or prev_line.startswith('@'):
                            j -= 1
                            continue
                        if prev_line.startswith('///') or prev_line.endswith('*/'):
                            is_documented = True
                        break
                    if is_documented:
                        documented_decls += 1

    if total_decls == 0:
        return 100.0
    return (documented_decls / total_decls) * 100.0


def update_readme(test_cov: float, doc_cov: float) -> None:
    """Update the test and documentation coverage badges in `README.md`.

    Args:
        test_cov: The test coverage percentage.
        doc_cov: The documentation coverage percentage.
    """
    with open('README.md', 'r', encoding='utf-8') as f:
        content = f.read()

    test_color = get_color(test_cov)
    doc_color = get_color(doc_cov)

    test_badge = f'[![Test Coverage](https://img.shields.io/badge/test_coverage-{test_cov:.2f}%25-{test_color}.svg)](#)'
    doc_badge = f'[![Doc Coverage](https://img.shields.io/badge/doc_coverage-{doc_cov:.2f}%25-{doc_color}.svg)](#)'

    content = re.sub(r'\[\!\[Test Coverage\]\([^\]]+\)\]\([^\)]+\)', test_badge, content)
    content = re.sub(r'\[\!\[Doc Coverage\]\([^\]]+\)\]\([^\)]+\)', doc_badge, content)

    with open('README.md', 'w', encoding='utf-8') as f:
        f.write(content)


if __name__ == '__main__':
    test_cov = get_test_coverage()
    doc_cov = get_doc_coverage()
    print(f'Test Coverage: {test_cov:.2f}%')
    print(f'Doc Coverage: {doc_cov:.2f}%')
    update_readme(test_cov, doc_cov)
    if test_cov < 100.0 or doc_cov < 100.0:
        sys.exit(1)
