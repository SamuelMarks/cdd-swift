#!/usr/bin/env bash
CMD="$1"
shift

# Smart resolution for python vs python3
if [ "$CMD" = "python3" ] || [ "$CMD" = "python" ]; then
    if command -v python3 >/dev/null 2>&1; then
        CMD="python3"
    elif command -v python >/dev/null 2>&1; then
        CMD="python"
    fi
fi

if command -v "$CMD" >/dev/null 2>&1; then
    exec "$CMD" "$@"
elif command -v docker >/dev/null 2>&1; then
    echo "$CMD not found on host. Falling back to Docker..."
    if [ "$CMD" = "swiftlint" ]; then
        exec docker run --rm -v "$PWD:/app" -w /app ghcr.io/realm/swiftlint:latest "$@"
    elif [ "$CMD" = "python" ] || [ "$CMD" = "python3" ]; then
        # For python scripts, we might need network access if they spin up servers
        exec docker run --rm --network host -v "$PWD:/app" -w /app swift:latest python3 "$@"
    else
        exec docker run --rm -v "$PWD:/app" -w /app swift:latest "$CMD" "$@"
    fi
else
    echo "Neither $CMD nor Docker is available on the host."
    exit 1
fi
