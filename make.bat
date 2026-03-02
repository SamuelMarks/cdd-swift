@echo off
setlocal enabledelayedexpansion

if "%1"=="" goto help
if "%1"=="help" goto help
if "%1"=="install_base" goto install_base
if "%1"=="install_deps" goto install_deps
if "%1"=="build_docs" goto build_docs
if "%1"=="build" goto build
if "%1"=="test" goto test
if "%1"=="run" goto run
if "%1"=="build_wasm" goto build_wasm
goto help

:help
echo Available tasks:
echo   install_base : install language runtime (Swift)
echo   install_deps : install local dependencies (Swift package)
echo   build_docs   : build the API docs and put them in docs/
echo   build        : build the CLI binary
echo   test         : run tests locally
echo   run          : run the CLI (e.g., make.bat run --version)
echo   build_wasm   : build for WASM
goto :EOF

:install_base
echo Please install Swift from swift.org
goto :EOF

:install_deps
swift package resolve
goto :EOF

:build_docs
set DOCS_DIR=docs
if not "%2"=="" set DOCS_DIR=%2
if not exist "%DOCS_DIR%" mkdir "%DOCS_DIR%"
swift package generate-documentation --target cdd-swift-cli --output-path "%DOCS_DIR%"
goto :EOF

:build
set BIN_DIR=.build\release
if not "%2"=="" set BIN_DIR=%2
swift build -c release
if not "%BIN_DIR%"==".build\release" (
    if not exist "%BIN_DIR%" mkdir "%BIN_DIR%"
    copy /Y .build\release\cdd-swift.exe "%BIN_DIR%\"
)
goto :EOF

:test
swift test
goto :EOF

:run
call make.bat build
set "ARGS="
:run_args_loop
shift
if "%1"=="" goto run_execute
set "ARGS=!ARGS! %1"
goto run_args_loop
:run_execute
.build\release\cdd-swift.exe %ARGS%
goto :EOF

:build_wasm
swift build --triple wasm32-unknown-wasi -c release
goto :EOF

:build_docker
docker build -t cdd-swift:debian -f debian.Dockerfile .
docker build -t cdd-swift:alpine -f alpine.Dockerfile .
goto :EOF

:run_docker
call make.bat build_docker
docker run -d -p 8082:8082 --name cdd_swift_test cdd-swift:debian
timeout /t 2
curl -s -X POST -H "Content-Type: application/json" -d "{\"jsonrpc\": \"2.0\", \"method\": \"--version\", \"id\": 1}" http://127.0.0.1:8082/
docker stop cdd_swift_test
docker rm cdd_swift_test
docker rmi cdd-swift:debian cdd-swift:alpine
goto :EOF

