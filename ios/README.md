# pumi/ios

opencode のセッションを iPhone から操作する SwiftUI アプリ。**Xcode を開かず CLI だけで**
開発・実行する（`study` / `pita` と同じ形）。

- UI: SwiftUI（iOS 17+）
- Markdown: MarkdownUI（SPM）
- プロジェクト定義: XcodeGen（`project.yml`）。`.xcodeproj` は生成物なので追跡しない
- 通信: `crates/pumi` のブリッジ（`/api/*`）。SSE は `URLSession.bytes` で読む

## 開発ループ（Xcode 不要）

```bash
# 0) 前提: brew install xcodegen

# 1) プロジェクト生成（project.yml を変えたときだけ）
xcodegen generate

# 2) ビルド
xcodebuild -project Pumi.xcodeproj -scheme Pumi \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath build build

# 3) シミュレータで実行
xcrun simctl boot "iPhone 17" || true
xcrun simctl install "iPhone 17" build/Build/Products/Debug-iphonesimulator/Pumi.app
xcrun simctl launch "iPhone 17" app.pumi.Pumi
```

シミュレータからは `http://127.0.0.1:7180`（ブリッジ）に繋がる。アプリの設定画面で
URL を変えられる。

## 実機に入れる（Xcode 不要）

```bash
# iPhone を USB で繋ぎ、ロックを外して「信頼」。
# iOS 16 以降は 設定 > プライバシーとセキュリティ > デベロッパモード を ON。
./deploy.sh              # 繋がっている端末を自動で選ぶ
./deploy.sh <UDID>       # 端末を指定（xcrun devicectl list devices で調べる）
```

実機では設定に Tailscale の HTTPS URL（例: `https://<machine>.<tailnet>.ts.net:8443`）を入れる。
無料の Personal Team なので、プロファイルが切れたら `./deploy.sh` を流し直す。

## 構成

```
Sources/
  PumiApp.swift               # @main
  App/Settings.swift          # ブリッジの URL（UserDefaults）
  API/
    Models.swift              # opencode のワイヤ型（描画する分だけ）
    PumiClient.swift          # JSON API + SSE
  Features/
    Sessions/                 # 一覧（リポジトリでグルーピング、状態ドット）
    Chat/                     # スレッド、SSE、送信、送信待ち、権限、フォーム
    Settings/                 # サーバ URL
  Support/Format.swift        # 相対時刻・未読判定
```

## 通知

Web Push は iOS アプリでは受け取れないので、ホーム画面に入れた PWA
（`crates/pumi/web`）が購読する。通知をタップすると `pumi://sessions/<id>` で
このアプリが開く。
