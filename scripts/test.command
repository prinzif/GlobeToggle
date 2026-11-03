#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
xcrun swiftc -module-cache-path "$PWD/build/ModuleCache" TapGesture.swift Tests/TapGestureTests.swift -o build/gesture-tests
build/gesture-tests
plutil -lint Info.plist
bash -n build-dmg.command build-icon.command scripts/test.command
