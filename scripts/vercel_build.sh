#!/usr/bin/env bash
# Vercel 上でWeb版をビルドする。
# Vercel のビルド環境には Flutter が無いので、SDKを取ってきてから使う。
set -euo pipefail

# .fvmrc と同じバージョンに揃えること
FLUTTER_VERSION=3.35.1
# .vercel/cache はビルド間で保持されるので、2回目以降はcloneを省ける
FLUTTER_DIR=.vercel/cache/flutter

if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  rm -rf "$FLUTTER_DIR"
  mkdir -p "$(dirname "$FLUTTER_DIR")"
  git clone https://github.com/flutter/flutter.git     --depth 1 --branch "$FLUTTER_VERSION" "$FLUTTER_DIR"
fi

export PATH="$PWD/$FLUTTER_DIR/bin:$PATH"
# SDKをリポジトリ配下に置いているため所有者チェックに引っかかる
git config --global --add safe.directory "$PWD/$FLUTTER_DIR"

flutter --version
flutter pub get
flutter build web --release
