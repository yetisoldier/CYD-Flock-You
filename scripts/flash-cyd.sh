#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

env_name="${1:-cyd}"

echo "Building ${env_name} firmware..."
pio run -e "${env_name}"

echo "Flashing ${env_name} firmware..."
pio run -e "${env_name}" -t upload

echo "Opening serial monitor. Press Ctrl+C to exit."
pio device monitor -b 115200
