import os
import shutil
import subprocess
import time

def run_cmd(cmd, check=True, cwd=None, env=None):
    print(f"Running: {' '.join(cmd)}")
    return subprocess.run(cmd, check=check, capture_output=False, cwd=cwd, env=env)

def main():
    # 1. Fetch petstore.json if it doesn't exist
    if not os.path.exists("petstore.json") and not os.path.exists("../petstore.json"):
        run_cmd(["curl", "-s", "-f", "https://petstore.swagger.io/v2/swagger.json", "-o", "../petstore.json"], check=False)

    petstore_path = "../petstore.json" if os.path.exists("../petstore.json") else "petstore.json"

    server_dir = "../cdd-swift-server-swagger"
    client_dir = "../cdd-swift-client-swagger"

    # Cleanup old dirs
    for d in [server_dir, client_dir]:
        if os.path.exists(d):
            shutil.rmtree(d)

    # 2. Generate Server
    run_cmd(["swift", "run", "cdd-swift", "from_openapi", "to_server", "-i", petstore_path, "-o", server_dir])

    # 3. Generate Client
    run_cmd(["swift", "run", "cdd-swift", "from_openapi", "to_sdk", "-i", petstore_path, "-o", client_dir])

    server_process = None
    try:
        # 4. Start Server
        env = os.environ.copy()

        # Build first so it starts instantly when we Popen
        run_cmd(["swift", "build"], cwd=server_dir)

        server_process = subprocess.Popen(
            ["swift", "run", "GeneratedServer", "serve", "--port", "8085", "--ephemeral", "--seed"],
            cwd=server_dir,
            env=env
        )

        # Wait for server to start
        print("Waiting for server to boot...")
        time.sleep(15)

        # 5. Test Client
        client_env = os.environ.copy()
        client_env["API_BASE_URL"] = "http://127.0.0.1:8085/v2"
        run_cmd(["swift", "test"], cwd=client_dir, env=client_env)

    finally:
        if server_process:
            server_process.terminate()
            server_process.wait()

if __name__ == "__main__":
    main()
