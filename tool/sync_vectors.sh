#!/usr/bin/env bash
# Copies the shared core vectors from sdk-react, so the Dart port is tested
# against exactly what @paystrater/react and @paystrater/react-native pass.
# CI fails when the copy differs.
set -euo pipefail
src="${SDK_REACT_DIR:-../sdk-react}/test/vectors/core.json"
dst="test/vectors/core.json"
if [[ "${1:-}" == "--check" ]]; then
  cmp -s "$src" "$dst" || { echo "test/vectors/core.json differs from $src: run tool/sync_vectors.sh"; exit 1; }
  echo "ok   test/vectors/core.json matches sdk-react"
else
  cp "$src" "$dst"
  echo "copied $src"
fi
