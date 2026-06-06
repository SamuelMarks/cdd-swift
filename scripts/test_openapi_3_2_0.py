import os
import shutil
import subprocess
import time

def run_cmd(cmd, check=True, cwd=None):
    print(f"Running: {' '.join(cmd)}")
    return subprocess.run(cmd, check=check, capture_output=False, cwd=cwd)

def find_jar(target_dir):
    for f in os.listdir(target_dir):
        if f.endswith(".jar") and not f.endswith("-javadoc.jar") and not f.endswith("-sources.jar"):
            return os.path.join(target_dir, f)
    return None

def start_server_docker():
    try:
        subprocess.run(["docker", "rm", "-f", "petstore_server_3"], capture_output=True)
        run_cmd(["docker", "run", "-d", "-p", "8082:8080",
                 "-e", "SWAGGER_HOST=http://localhost:8082",
                 "-e", "SWAGGER_BASE_PATH=/api/v3",
                 "--name", "petstore_server_3", "swaggerapi/petstore"])
        time.sleep(3)
        return True
    except subprocess.CalledProcessError:
        return False
    except FileNotFoundError:
        return False

def stop_server_docker():
    subprocess.run(["docker", "rm", "-f", "petstore_server_3"], capture_output=True)

def main():
    docker_used = False
    server_process = None

    if start_server_docker():
        docker_used = True
    else:
        print("Docker not available or failed to start, falling back to local JVM...")
        petstore_dir = "../swagger-petstore-v2"
        target_dir = os.path.join(petstore_dir, "target")

        if not os.path.exists(target_dir):
            run_cmd(["mvn", "package", "-DskipTests"], cwd=petstore_dir)

        war_files = [f for f in os.listdir(target_dir) if f.endswith(".war")]
        if not war_files:
            run_cmd(["mvn", "package", "-DskipTests"], cwd=petstore_dir)
            war_files = [f for f in os.listdir(target_dir) if f.endswith(".war")]
            if not war_files:
                raise Exception("Could not find packaged WAR file")

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
             raise Exception("Could not find jetty-runner jar")

        env = os.environ.copy()
        env["SWAGGER_HOST"] = "http://localhost:8082"
        env["SWAGGER_BASE_PATH"] = "/api/v3"

        server_process = subprocess.Popen(["java", "-jar", jetty_runner_path, "--port", "8082", war_path], env=env)
        time.sleep(10)

    try:
        client_dir = "../cdd-swift-client-openapi"
        if os.path.exists(client_dir):
            shutil.rmtree(client_dir)

        run_cmd(["swift", "run", "cdd-swift", "from_openapi", "to_sdk",
                 "-i", "../petstore_oas3.json", "-o", client_dir, "--tests"])

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
