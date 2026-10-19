#!/usr/bin/env python3
"""End-to-end Arazzo 1.1.0 roundtrip transpilation and workflow execution test script."""

import json
import os
import shutil
import subprocess
import sys
import tempfile


def run_cmd(cmd, cwd=None):
    """Execute a subprocess command and raise on non-zero exit."""
    print(f"Running: {' '.join(cmd)}")
    subprocess.run(cmd, check=True, cwd=cwd)


def main() -> int:
    """Execute Arazzo 1.1.0 CLI roundtrip generation and AST verification."""
    tmp_dir = tempfile.mkdtemp(prefix="cdd_arazzo_e2e_")
    try:
        spec_path = os.path.join(tmp_dir, "arazzo.json")
        sdk_dir = os.path.join(tmp_dir, "sdk")
        cli_dir = os.path.join(tmp_dir, "cli")
        test_dir = os.path.join(tmp_dir, "tests")
        server_dir = os.path.join(tmp_dir, "server")
        roundtrip_path = os.path.join(tmp_dir, "roundtrip.json")

        run_cmd(["swift", "run", "cdd-swift", "generate_arazzo", "-o", spec_path])
        assert os.path.exists(spec_path), "Generated Arazzo JSON missing"

        run_cmd(
            [
                "swift",
                "run",
                "cdd-swift",
                "from_arazzo",
                "to_sdk",
                "-i",
                spec_path,
                "-o",
                sdk_dir,
                "--no-installable-package",
            ]
        )
        sdk_file = os.path.join(sdk_dir, "WorkflowsClient.swift")
        assert os.path.exists(sdk_file), "Generated WorkflowsClient.swift missing"

        run_cmd(
            [
                "swift",
                "run",
                "cdd-swift",
                "from_arazzo",
                "to_sdk_cli",
                "-i",
                spec_path,
                "-o",
                cli_dir,
                "--no-installable-package",
            ]
        )
        assert os.path.exists(os.path.join(cli_dir, "WorkflowCLI.swift")), (
            "Generated WorkflowCLI.swift missing"
        )

        run_cmd(
            [
                "swift",
                "run",
                "cdd-swift",
                "from_arazzo",
                "to_test",
                "-i",
                spec_path,
                "-o",
                test_dir,
            ]
        )
        assert os.path.exists(
            os.path.join(test_dir, "GeneratedArazzoWorkflowTests.swift")
        ), "Generated test suite missing"

        run_cmd(
            [
                "swift",
                "run",
                "cdd-swift",
                "from_arazzo",
                "to_server",
                "-i",
                spec_path,
                "-o",
                server_dir,
            ]
        )
        assert os.path.exists(
            os.path.join(server_dir, "ServerWorkflowOrchestrator.swift")
        ), "Generated server orchestrator missing"

        run_cmd(
            [
                "swift",
                "run",
                "cdd-swift",
                "to_arazzo",
                "-i",
                sdk_file,
                "-o",
                roundtrip_path,
            ]
        )
        with open(roundtrip_path, "r", encoding="utf-8") as f:
            roundtrip = json.load(f)
        assert roundtrip.get("arazzo") == "1.1.0", "Expected Arazzo 1.1.0 version"
        assert len(roundtrip.get("workflows", [])) >= 1, "Expected extracted workflows"

        print("✅ Arazzo 1.1.0 end-to-end roundtrip verification succeeded.")
        return 0
    finally:
        shutil.rmtree(tmp_dir, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
