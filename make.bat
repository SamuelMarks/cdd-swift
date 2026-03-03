@echo off
setlocal enabledelayedexpansion

if "%1"=="" goto help
if "%1"=="install_base" goto install_base
if "%1"=="install_deps" goto install_deps
if "%1"=="build_docs" goto build_docs
if "%1"=="build" goto build
if "%1"=="build_wasm" goto build_wasm
if "%1"=="build_docker" goto build_docker
if "%1"=="run_docker" goto run_docker
if "%1"=="test" goto test
if "%1"=="run" goto run
if "%1"=="help" goto help
if "%1"=="all" goto help

echo Unknown target: %1
goto :eof

:install_base
echo Installing base dependencies...
echo Install Swift from swift.org
goto :eof

:install_deps
swift package resolve
goto :eof

:build_docs
set DOCS_DIR=docs
if not "%2"=="" set DOCS_DIR=%2
echo Building docs to %DOCS_DIR%...
swift package --allow-writing-to-directory %DOCS_DIR% generate-documentation --target CDDSwift --output-path %DOCS_DIR%
goto :eof

:build
echo Building CLI binary...
swift build -c release
goto :eof

:build_wasm
echo Building WASM binary...
swift build --triple wasm32-unknown-wasi -c release
goto :eof

:build_docker
docker build -t cdd-swift -f alpine.Dockerfile .
docker build -t cdd-swift-debian -f debian.Dockerfile .
goto :eof

:run_docker
call make.bat build_docker
docker run --rm -p 8082:8082 cdd-swift
goto :eof

:test
echo Running tests...
swift test
goto :eof

:run
call make.bat build
echo Running CLI...
.build\release\cdd-swift %*
goto :eof

:help
echo Available tasks:
echo   install_base  : install language runtime
echo   install_deps  : install dependencies
echo   build_docs    : build the API docs
echo   build         : build the CLI binary
echo   build_wasm    : build the WASM binary
echo   build_docker  : build docker images
echo   run_docker    : run docker image
echo   test          : run tests locally
echo   run           : build and run the CLI (e.g., make.bat run --version)
echo   help / all    : show this help text
goto :eof
