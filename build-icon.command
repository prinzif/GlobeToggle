#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
ICONSET="$PWD/build/AppIcon.iconset"
mkdir -p "$ICONSET"
xcrun swiftc -module-cache-path "$PWD/build/ModuleCache" scripts/RenderIcon.swift -o build/render-icon
build/render-icon "$PWD/build/icons"
for SIZE in 16 32 128 256 512; do
    sips -z "$SIZE" "$SIZE" build/icons/AppIcon-light.png --out "$ICONSET/icon_${SIZE}x${SIZE}.png" >/dev/null
    DOUBLE=$((SIZE * 2))
    sips -z "$DOUBLE" "$DOUBLE" build/icons/AppIcon-light.png --out "$ICONSET/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
done
python3 - <<'PY'
from pathlib import Path
import struct

iconset = Path('build/AppIcon.iconset')
representations = [
    ('icp4', 'icon_16x16.png'),
    ('icp5', 'icon_32x32.png'),
    ('icp6', 'icon_32x32@2x.png'),
    ('ic07', 'icon_128x128.png'),
    ('ic08', 'icon_256x256.png'),
    ('ic09', 'icon_512x512.png'),
    ('ic10', 'icon_512x512@2x.png'),
    ('ic11', 'icon_16x16@2x.png'),
    ('ic12', 'icon_32x32@2x.png'),
    ('ic13', 'icon_128x128@2x.png'),
    ('ic14', 'icon_256x256@2x.png'),
]
chunks = []
for kind, name in representations:
    data = (iconset / name).read_bytes()
    chunks.append(kind.encode('ascii') + struct.pack('>I', len(data) + 8) + data)
body = b''.join(chunks)
Path('build/icons/AppIcon.icns').write_bytes(b'icns' + struct.pack('>I', len(body) + 8) + body)
PY
