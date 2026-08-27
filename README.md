# dopaz

topaz.dev のプロジェクトを YouTube Shorts 風の縦スワイプで発見できる Flutter アプリ。
現在はモックデータ(5件)で動作します。

## 対象プラットフォーム

- iOS
- Android

## 必要環境

- [fvm](https://fvm.app/) (Flutter Version Management) — Flutterのバージョンは `.fvmrc` で **3.35.1** に固定
- iOS: macOS + Xcode
- Android: Android Studio / Android SDK

## セットアップ (fvm)

```sh
# fvm未導入の場合
dart pub global activate fvm

# .fvmrc に記載のFlutter SDKを取得してプロジェクトに紐付け
fvm install
fvm use
```

VS Codeを使う場合は [.vscode/settings.json](.vscode/settings.json) で
`dart.flutterSdkPath` が `.fvm/flutter_sdk` に設定済みです。

## 起動手順

```sh
# 依存パッケージの取得
fvm flutter pub get

# 接続中のデバイス確認
fvm flutter devices

# 起動(デバイス/エミュレータを選択して実行)
fvm flutter run

# デバイスを指定する場合
fvm flutter run -d <device-id>
```

## デバイスプレビュー (実機なしでの表示確認)

モバイル実機・エミュレータがない環境では、Chromeで起動して
[device_preview](https://pub.dev/packages/device_preview) の画面上で
各種デバイスサイズの表示を確認できます。

```sh
fvm flutter run -d chrome
```

※ 配布対象はiOS / Androidのみで、webは開発時のプレビュー用です。

## プロジェクト構成

```text
lib/
├── main.dart                        # アプリのエントリポイント
├── models/
│   └── project.dart                 # Projectモデル (id, title, thumbnail, author, techs, topazUrl)
├── repositories/
│   └── feed_repository.dart         # フィード取得 (現状はモックJSON、将来API差し替え)
└── pages/
    └── feed_page.dart               # 縦スワイプフィード (PageView.vertical)
```

## 主な依存パッケージ

- [http](https://pub.dev/packages/http) — 将来のAPI通信用
- [url_launcher](https://pub.dev/packages/url_launcher) — topaz.dev のプロジェクトページを外部ブラウザで開く
- [device_preview](https://pub.dev/packages/device_preview) — 各種デバイスサイズでの表示確認(デバッグビルドのみ有効)
