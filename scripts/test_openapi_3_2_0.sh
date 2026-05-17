#!/usr/bin/env bash
set -e

# start server
docker rm -f petstore_server || true
docker run -d -p 8080:8080 -e SWAGGER_HOST="http://localhost:8080" -e SWAGGER_BASE_PATH="/api/v3" --name petstore_server swaggerapi/petstore >/dev/null
sleep 3

# test
rm -rf ../cdd-swift-client-openapi
swift run cdd-swift from_openapi to_sdk -i ../petstore_oas3.json -o ../cdd-swift-client-openapi --tests
cd ../cdd-swift-client-openapi
swift test

# cleanup
docker rm -f petstore_server
