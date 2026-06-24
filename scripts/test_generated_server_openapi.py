import os
import shutil
import subprocess
import time

def run_cmd(cmd, check=True, cwd=None, env=None):
    print(f"Running: {' '.join(cmd)}")
    return subprocess.run(cmd, check=check, capture_output=False, cwd=cwd, env=env)

def main():
    # 1. Fetch petstore_oas3.json if it doesn't exist
    if not os.path.exists("petstore_oas3.json") and not os.path.exists("../petstore_oas3.json"):
        # We assume it exists from the main test script or we generate it from yaml
        # Fallback fetch
        run_cmd(["curl", "-s", "-f", "https://raw.githubusercontent.com/swagger-api/swagger-petstore/master/src/main/resources/openapi.yaml", "-o", "../petstore_oas3.yaml"], check=False)
        # Assuming python3 and yaml are available
        try:
            import yaml, json
            with open("../petstore_oas3.yaml", "r") as f:
                data = yaml.safe_load(f)
            with open("../petstore_oas3.json", "w") as f:
                json.dump(data, f)
        except Exception:
            pass

    petstore_path = "../petstore_oas3.json" if os.path.exists("../petstore_oas3.json") else "petstore_oas3.json"

    server_dir = "../cdd-swift-server-openapi"
    client_dir = "../cdd-swift-client-openapi"

    # Cleanup old dirs
    for d in [server_dir, client_dir]:
        if os.path.exists(d):
            shutil.rmtree(d)

    # 2. Generate Server
    run_cmd(["swift", "run", "cdd-swift", "from_openapi", "to_server", "-i", petstore_path, "-o", server_dir, "--tests"])

    # 3. Generate Client
    run_cmd(["swift", "run", "cdd-swift", "from_openapi", "to_sdk", "-i", petstore_path, "-o", client_dir, "--tests"])

    server_process = None
    try:
        # 4. Start Server
        env = os.environ.copy()

        # Build first
        run_cmd(["swift", "build"], cwd=server_dir)

        server_process = subprocess.Popen(
            ["swift", "run", "GeneratedServer", "serve", "--port", "8086", "--ephemeral", "--seed"],
            cwd=server_dir,
            env=env
        )

        # Wait for server to start
        print("Waiting for server to boot...")
        time.sleep(15)

        # 5. Test Client
        client_env = os.environ.copy()
        client_env["API_BASE_URL"] = "http://127.0.0.1:8086/api/v3"
        run_cmd(["swift", "test"], cwd=client_dir, env=client_env)

    finally:
        if server_process:
            server_process.terminate()
            server_process.wait()

if __name__ == "__main__":
    main()
