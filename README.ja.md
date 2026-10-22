# pumi

[opencode](https://opencode.ai) サーバ上のエージェントを、Tailscale 越しに iPhone から
操作するための iOS アプリとブリッジ。名前はハンガリーの牧羊犬から（羊を「集める」より
「追い立てる」犬）。

## 構成

```
crates/pumi/        Rust ブリッジ: opencode API の中継、イベントリレー、Web Push
crates/pumi/web/    PWA: Web Push の購読と通知からのディープリンク
ios/                SwiftUI アプリ（XcodeGen。Xcode の UI は開かない）
```

opencode と話すのはブリッジだけ。iOS アプリも PWA もブリッジに話す。

## ブリッジ

```bash
cargo run -p pumi -- serve --port 7180
```

- `GET /api/sessions` — 全プロジェクトの一覧（`active` / `pending` を合成）
- `GET /api/sessions/{id}/messages` — 新しいページから。`cursor` で遡る
- `POST /api/sessions/{id}/prompt` — `delivery: queue` で実行中のターンの後ろに積む
- `GET /api/sessions/{id}/inbox` — 実行待ちのプロンプト
- `GET /api/events?session={id}` — opencode から中継する SSE

`tailscale serve` で loopback のポートを tailnet に公開する（pumi は `127.0.0.1`
にしか bind しない）。

## iOS

詳細は [ios/README.md](ios/README.md)。

```bash
cd ios
xcodegen generate
./deploy.sh          # ビルドして実機に入れて起動
```
