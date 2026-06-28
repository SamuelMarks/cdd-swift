import os
import shutil
import subprocess
import time

def resolve_cmd(cmd):
    """Resolves the command executable to its full path to ensure cross-platform compatibility (e.g. .cmd, .exe)."""
    if not cmd:
        return cmd
    executable = shutil.which(cmd[0])
    if executable:
        return [executable] + cmd[1:]
    return cmd

def run_cmd(cmd, check=True, cwd=None):
    cmd = resolve_cmd(cmd)
    print(f"Running: {' '.join(cmd)}")
    return subprocess.run(cmd, check=check, capture_output=False, cwd=cwd)

def find_jar(target_dir):
    for f in os.listdir(target_dir):
        if f.endswith(".jar") and not f.endswith("-javadoc.jar") and not f.endswith("-sources.jar"):
            return os.path.join(target_dir, f)
    return None

def start_server_docker():
    try:
        run_cmd(["docker", "rm", "-f", "petstore_server_3"], check=False)
        run_cmd(["docker", "run", "-d", "-p", "8082:8080",
                 "-e", "SWAGGER_HOST=http://localhost:8082",
                 "-e", "SWAGGER_BASE_PATH=/api/v3",
                 "--name", "petstore_server_3", "swaggerapi/petstore"])
        time.sleep(3)
        return True
    except Exception:
        return False

def stop_server_docker():
    run_cmd(["docker", "rm", "-f", "petstore_server_3"], check=False)

def start_server_jvm(port, host, base_path):
    print("Attempting to start local JVM server...")
    petstore_dir = os.path.join("..", "swagger-petstore-v2")
    target_dir = os.path.join(petstore_dir, "target")

    try:
        if not os.path.exists(target_dir):
            run_cmd(["mvn", "package", "-DskipTests"], cwd=petstore_dir)

        war_files = [f for f in os.listdir(target_dir) if f.endswith(".war")]
        if not war_files:
            run_cmd(["mvn", "package", "-DskipTests"], cwd=petstore_dir)
            war_files = [f for f in os.listdir(target_dir) if f.endswith(".war")]
            if not war_files:
                return None

        war_path = os.path.join(target_dir, war_files[0])
        jetty_runner_path = None
        for root, _, files in os.walk(target_dir):
            for f in files:
                if "jetty-runner" in f and f.endswith(".jar"):
                    jetty_runner_path = os.path.join(root, f)
                    break
            if jetty_runner_path:
                break

        if not jetty_runner_path:
             return None

        env = os.environ.copy()
        env["SWAGGER_HOST"] = host
        env["SWAGGER_BASE_PATH"] = base_path

        java_cmd = resolve_cmd(["java", "-jar", jetty_runner_path, "--port", str(port), war_path])
        server_process = subprocess.Popen(java_cmd, env=env)
        time.sleep(10)
        return server_process
    except Exception as e:
        print(f"JVM start failed: {e}")
        return None

import urllib.request
import urllib.error

def is_server_pingable(url):
    try:
        req = urllib.request.Request(url)
        with urllib.request.urlopen(req, timeout=2) as response:
            return response.status == 200
    except Exception:
        return False

def main():
    docker_used = False
    server_process = None

    if is_server_pingable("http://localhost:8082/api/v3/openapi.json"):
        print("Server is already running and pingable.")
    else:
        print("Attempting to start Docker server...")
        if start_server_docker():
            docker_used = True
        else:
            if os.environ.get("RUN_SLOW_TESTS"):
                server_process = start_server_jvm(8082, "http://localhost:8082", "/api/v3")
                if server_process is None:
                    raise Exception("JVM failed to start.")
            else:
                print("Docker failed to start and RUN_SLOW_TESTS is not set. Skipping tests.")
                return


    try:
        client_dir = os.path.join("..", "cdd-swift-client-openapi")
        if os.path.exists(client_dir):
            shutil.rmtree(client_dir)

        run_cmd(["swift", "run", "cdd-swift", "from_openapi", "to_sdk",
                 "-i", os.path.join("..", "petstore_oas3.json"), "-o", client_dir, "--tests"])

        os.chdir(client_dir)
        run_cmd(["swift", "test"])
    finally:
        if docker_used:
            stop_server_docker()
        elif server_process:
            server_process.terminate()
            server_process.wait()

if __name__ == "__main__":
    main()
