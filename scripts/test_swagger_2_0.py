import os
import shutil
import subprocess
import time

def run_cmd(cmd, check=True):
    print(f"Running: {' '.join(cmd)}")
    return subprocess.run(cmd, check=check, capture_output=False)

def main():
    subprocess.run(["docker", "rm", "-f", "petstore_server_2"], capture_output=True)

    run_cmd(["docker", "run", "-d", "-p", "8081:8080",
             "-e", "SWAGGER_HOST=http://localhost:8081",
             "-e", "SWAGGER_BASE_PATH=/v2",
             "--name", "petstore_server_2", "swaggerapi/petstore"])
    time.sleep(3)

    client_dir = "../cdd-swift-client-swagger"
    if os.path.exists(client_dir):
        shutil.rmtree(client_dir)

    run_cmd(["swift", "run", "cdd-swift", "from_openapi", "to_sdk",
             "-i", "../petstore.json", "-o", client_dir, "--tests"])

    os.chdir(client_dir)
    run_cmd(["swift", "test"])

    subprocess.run(["docker", "rm", "-f", "petstore_server_2"], capture_output=True)

if __name__ == "__main__":
    main()
