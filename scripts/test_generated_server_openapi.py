import os
import shutil
import subprocess
import time
import urllib.request

def resolve_cmd(cmd):
    """Resolves the command executable to its full path to ensure cross-platform compatibility (e.g. .cmd, .exe)."""
    if not cmd:
        return cmd
    executable = shutil.which(cmd[0])
    if executable:
        return [executable] + cmd[1:]
    return cmd

def get_clean_env():
    env = os.environ.copy()
    for k in list(env.keys()):
        if k.startswith("GIT_") and k != "GIT_SSH_COMMAND":
            del env[k]
    return env

def run_cmd(cmd, check=True, cwd=None, env=None):
    if env is None:
        env = get_clean_env()
    cmd = resolve_cmd(cmd)
    print(f"Running: {' '.join(cmd)}")
    return subprocess.run(cmd, check=check, capture_output=False, cwd=cwd, env=env)

def download_file(url, path):
    print(f"Downloading {url} to {path}")
    try:
        urllib.request.urlretrieve(url, path)
    except Exception as e:
        print(f"Failed to download {url}: {e}")

def main():
    # 1. Fetch petstore_oas3.json if it doesn't exist
    fallback_petstore_json = os.path.join("..", "petstore_oas3.json")
    if not os.path.exists("petstore_oas3.json") and not os.path.exists(fallback_petstore_json):
        # We assume it exists from the main test script or we generate it from yaml
        # Fallback fetch
        fallback_petstore_yaml = os.path.join("..", "petstore_oas3.yaml")
        download_file("https://raw.githubusercontent.com/swagger-api/swagger-petstore/master/src/main/resources/openapi.yaml", fallback_petstore_yaml)
        # Assuming python3 and yaml are available
        try:
            import yaml, json
            with open(fallback_petstore_yaml, "r") as f:
                data = yaml.safe_load(f)
            with open(fallback_petstore_json, "w") as f:
                json.dump(data, f)
        except Exception:
            pass

    petstore_path = fallback_petstore_json if os.path.exists(fallback_petstore_json) else "petstore_oas3.json"

    server_dir = os.path.join("..", "cdd-swift-server-openapi")
    client_dir = os.path.join("..", "cdd-swift-client-openapi")

    # Cleanup old dirs
    for d in [server_dir, client_dir]:
        if os.path.exists(d):
            shutil.rmtree(d)

    # 2. Generate Server
    run_cmd(["swift", "run", "cdd-swift", "from_openapi", "to_server", "-i", petstore_path, "-o", server_dir])

    # 3. Generate Client
    run_cmd(["swift", "run", "cdd-swift", "from_openapi", "to_sdk", "-i", petstore_path, "-o", client_dir, "--tests"])

    server_process = None
    try:
        # 4. Start Server
        env = get_clean_env()

        # Build first
        try:
            run_cmd(["swift", "build"], cwd=server_dir)
        except subprocess.CalledProcessError:
            print("swift build failed, trying to update packages and retrying...")
            run_cmd(["swift", "package", "update"], cwd=server_dir)
            run_cmd(["swift", "build"], cwd=server_dir)

        swift_run_cmd = resolve_cmd(["swift", "run", "GeneratedServer", "serve", "--port", "8086"])
        server_process = subprocess.Popen(
            swift_run_cmd,
            cwd=server_dir,
            env=env
        )

        # Wait for server to start
        print("Waiting for server to boot...")
        time.sleep(15)

        # 5. Test Client
        client_env = get_clean_env()
        client_env["API_BASE_URL"] = "http://127.0.0.1:8086/api/v3"
        run_cmd(["swift", "test"], cwd=client_dir, env=client_env)

    finally:
        if server_process:
            server_process.terminate()
            server_process.wait()

if __name__ == "__main__":
    main()
