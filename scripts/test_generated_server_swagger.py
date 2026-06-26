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
    # 1. Fetch petstore.json if it doesn't exist
    fallback_petstore_path = os.path.join("..", "petstore.json")
    if not os.path.exists("petstore.json") and not os.path.exists(fallback_petstore_path):
        download_file("https://petstore.swagger.io/v2/swagger.json", fallback_petstore_path)

    petstore_path = fallback_petstore_path if os.path.exists(fallback_petstore_path) else "petstore.json"

    server_dir = os.path.join("..", "cdd-swift-server-swagger")
    client_dir = os.path.join("..", "cdd-swift-client-swagger")

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

        # Build first so it starts instantly when we Popen
        try:
            run_cmd(["swift", "build"], cwd=server_dir)
        except subprocess.CalledProcessError:
            print("swift build failed, trying to update packages and retrying...")
            run_cmd(["swift", "package", "update"], cwd=server_dir)
            run_cmd(["swift", "build"], cwd=server_dir)

        swift_run_cmd = resolve_cmd(["swift", "run", "GeneratedServer", "serve", "--port", "8085"])
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
        client_env["API_BASE_URL"] = "http://127.0.0.1:8085/v2"
        run_cmd(["swift", "test"], cwd=client_dir, env=client_env)

    finally:
        if server_process:
            server_process.terminate()
            server_process.wait()

if __name__ == "__main__":
    main()
