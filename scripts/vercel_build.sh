#!/usr/bin/env bash
# Vercel 上でWeb版をビルドする。
# Vercel のビルド環境には Flutter が無いので、SDKを取ってきてから使う。
set -euo pipefail

# .fvmrc と同じバージョンに揃えること
FLUTTER_VERSION=3.35.1
# .vercel/cache はビルド間で保持されるので、2回目以降はcloneを省ける
FLUTTER_DIR=.vercel/cache/flutter

clone_flutter() {
  rm -rf "$FLUTTER_DIR"
  mkdir -p "$(dirname "$FLUTTER_DIR")"
  git clone https://github.com/flutter/flutter.git \
    --depth 1 --branch "$FLUTTER_VERSION" "$FLUTTER_DIR"
}

# キャッシュから復元したSDKはgitのindexが欠けることがある。その状態だと
# Flutterがエンジンのバージョンをgitから引こうとして落ちる
# (fatal: Not a valid object name origin/master)。
# バージョンは bin/internal/engine.version に固定されているので直接渡し、
# gitに頼らせないようにする。
set_engine_version() {
  local file="$FLUTTER_DIR/bin/internal/engine.version"
  if [ -f "$file" ]; then
    export FLUTTER_PREBUILT_ENGINE_VERSION="$(cat "$file")"
  fi
}

if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  clone_flutter
fi

export PATH="$PWD/$FLUTTER_DIR/bin:$PATH"
# SDKをリポジトリ配下に置いているため所有者チェックに引っかかる
git config --global --add safe.directory "$PWD/$FLUTTER_DIR"

set_engine_version

# それでも動かないキャッシュは諦めて取り直す
if ! flutter --version; then
  echo "キャッシュされたFlutter SDKが使えないので取り直します" >&2
  clone_flutter
  set_engine_version
  flutter --version
fi

flutter pub get
# --wasm を付けると dart2wasm (Skwasm) と dart2js (CanvasKit) の両方が出力され、
# ブラウザのWasmGC対応に応じてFlutterが自動で選ぶ。
# 対応ブラウザでは配信量が約9.3MB→約5.7MBに減り、動作も速くなる。
flutter build web --release --wasm
