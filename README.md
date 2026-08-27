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
├── theme.dart                       # topaz.dev のテーマ色 (水色 + 白)
├── models/
│   └── project.dart                 # Projectモデル (id, title, thumbnail, author, techs, topazUrl, likes, comments)
├── repositories/
│   └── feed_repository.dart         # フィード取得 (現状はモックJSON、将来API差し替え)
├── pages/
│   └── feed_page.dart               # 縦スワイプフィード (PageView.vertical) + 先読み・フィルター
└── widgets/
    ├── dopaz_logo.dart              # topaz.dev のロゴに合わせたロゴマーク+ロゴタイプ
    ├── feed_top_bar.dart            # ヘッダーと技術タグのフィルターチップ
    └── project_card.dart            # 1ページ分のカード (サムネイル/アクションレール/作者情報)
```

## UIについて

YouTube Shorts のレイアウトに寄せつつ、配色は topaz.dev のテーマ色(水色 + 白)に合わせています。
色は [lib/theme.dart](lib/theme.dart) の `TopazColors` にまとめてあります。

- 縦スワイプでページ送り
- ヘッダーの技術タグチップでフィード内容を絞り込み(選択中は水色)
- 右下のアクションレール: いいね数・コメント数・共有・topaz.dev を開く
- サムネイル下: 作者アバター・フォローボタン・タイトル・技術タグ(ハッシュタグ表示)
- 最下部の水色のシークバーは「フィード内で何件目か」を示します(動画の再生位置ではありません)
- 検索・メニュー・共有は未実装の表示のみです

背景が白のため、サムネイルの余白部分に文字が重なっても読めるよう、
アクションレールのアイコンと文字には白い縁取り(`topazGlowShadows`)を付けています。

### いいね・フォローの扱い

いいね数・コメント数は topaz.dev から取得した値を **表示するだけ** です。
いいね・フォロー・コメントといった書き込み操作は topaz.dev 側の機能なので、
このアプリからは実行しません(タップすると topaz.dev を開く案内を出します)。

## 主な依存パッケージ

- [http](https://pub.dev/packages/http) — 将来のAPI通信用
- [url_launcher](https://pub.dev/packages/url_launcher) — topaz.dev のプロジェクトページを外部ブラウザで開く
- [device_preview](https://pub.dev/packages/device_preview) — 各種デバイスサイズでの表示確認(デバッグビルドのみ有効)
