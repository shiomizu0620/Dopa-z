# dopaz

topaz.dev のプロジェクトを YouTube Shorts 風の縦スワイプで発見できる Flutter アプリ。
[topaz.dev の公開API](#api連携) から実データを取得します。

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

## API連携

[topaz.dev](https://topaz.dev) の公開APIからプロジェクト一覧を取得します。

```sh
curl -X GET https://topaz.dev/api/projects?page=1
```

| 項目 | 内容 |
| --- | --- |
| エンドポイント | `GET https://topaz.dev/api/projects?page=N` |
| 1ページの件数 | 12件 |
| 画像 | `thumbnail_path` は相対パス。`https://ptera-publish.topaz.dev/` を前に付けて使う |
| 文字コード | レスポンスの `Content-Type` に charset がないため、UTF-8として明示的にデコードする |
| 並び順 | APIが返す順序 (新着順) をそのまま表示する。アプリ側では並べ替えない |
| いいね数 | `like_count` を表示のみに使う |
| SNS | `user.social.github_id` / `twitter_id` からリンクを作る。空文字のことが多い (実データでは12件中GitHub 6件・X 3件) |
| コメント数 | APIが返さないため画面に出していない |

フィードの末尾に近づくと次のページを自動で読み込みます
([feed_page.dart](lib/pages/feed_page.dart) の `_loadMore`)。

### Webプレビューではサンプルデータを使う

topaz.dev のAPIは CORS ヘッダーを返さないため、**ブラウザからは直接呼べません**。
そのためWebで起動した場合は [assets/mock_projects.json](assets/mock_projects.json)
(実APIのレスポンスをそのまま保存したもの)を表示し、
ヘッダーに `SAMPLE` バッジを出します。実機・エミュレータでは実APIに接続します。

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
├── main.dart                        # アプリのエントリポイント (実行環境に応じてリポジトリを選択)
├── theme.dart                       # topaz.dev のテーマ色 (水色 + 白)
├── models/
│   └── project.dart                 # Project / ProjectPage (APIレスポンスに対応)
├── repositories/
│   ├── feed_repository.dart         # ProjectFeed と topaz.dev API 実装
│   └── mock_feed_repository.dart    # assets のサンプルJSONを返す実装 (Web用)
├── pages/
│   └── feed_page.dart               # 縦スワイプフィード + 先読み・フィルター・追加読み込み
└── widgets/
    ├── dopaz_logo.dart              # topaz.dev のロゴに合わせたロゴマーク+ロゴタイプ
    ├── feed_seek_bar.dart           # ドラッグ/タップで送れるシークバー
    ├── feed_top_bar.dart            # ヘッダーと技術タグのフィルターチップ
    └── project_card.dart            # 1ページ分のカード (サムネイル/アクションレール/作者情報)
```

## UIについて

YouTube Shorts のレイアウトに寄せつつ、配色は topaz.dev のテーマ色(水色 + 白)に合わせています。
色は [lib/theme.dart](lib/theme.dart) の `TopazColors` にまとめてあります。

- 縦スワイプでページ送り
- ヘッダーの技術タグチップでフィード内容を絞り込み(選択中は水色)
- 右下のアクションレール: いいね数・共有・topaz.dev を開く
- サムネイル下: 作者アバター・表示名・ユーザー名・GitHub / X へのリンク・タイトル・技術タグ(ハッシュタグ表示)
- GitHub / X のアイコンは `user.social` にアカウント名がある投稿者にだけ表示され、
  タップするとその人のページ (`https://github.com/<id>` / `https://x.com/<id>`) を外部ブラウザで開きます
- 最下部の水色のシークバーは「フィード内で何件目か」を示します(動画の再生位置ではありません)。
  横にドラッグ、またはタップした位置へ送れます
- 共有は未実装の表示のみです

背景が白のため、サムネイルの余白部分に文字が重なっても読めるよう、
アクションレールのアイコンと文字には白い縁取り(`topazGlowShadows`)を付けています。

### いいねの扱い

いいね数は topaz.dev から取得した値を **表示するだけ** です。
いいねのような書き込み操作は topaz.dev 側の機能なので、
このアプリからは実行しません(タップすると topaz.dev を開く案内を出します)。

## 主な依存パッケージ

- [http](https://pub.dev/packages/http) — topaz.dev APIとの通信
- [url_launcher](https://pub.dev/packages/url_launcher) — topaz.dev のプロジェクトページを外部ブラウザで開く
- [device_preview](https://pub.dev/packages/device_preview) — 各種デバイスサイズでの表示確認(デバッグビルドのみ有効)
- [font_awesome_flutter](https://pub.dev/packages/font_awesome_flutter) — GitHub / X のブランドアイコン
