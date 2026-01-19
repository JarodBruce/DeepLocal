# DeepLocal

DeepLocalは、LiquidAIのApolloにインスパイアされた、LLM（Large Language Model）を活用した次世代のiOS向けオープンソース翻訳アプリです。

## 概要

既存の翻訳アプリとは一線を画し、オンデバイスで動作する高精度なLLMを用いることで、文脈を汲み取った極めて自然な翻訳体験を提供することを目指しています。LiquidAIが開発した `LiquidAI/LFM2-350M-ENJP-MT` をメインモデルとして採用し、iPhone上での高速かつプライベートな翻訳を実現します。

## 特徴

- **LLMベースの高品質翻訳**: 従来の統計的・ニューラル翻訳を越える、文脈を理解した翻訳。
- **オンデバイス推論**: 翻訳データを外部サーバーに送信せず、プライバシーを保護。
- **ApolloスタイルのUX**: 使いやすさを徹底的に追求したインターフェース（予定）。
- **オープンソース**: 透明性が高く、コミュニティによるさらなる改善が可能。

## 使用モデル

初期状態では以下のモデルを推奨・使用しています：
- **[LiquidAI/LFM2-350M-ENJP-MT](https://huggingface.co/LiquidAI/LFM2-350M-ENJP-MT)**
  - 日本語と英語の翻訳に特化し、軽量（350Mパラメータ）ながら非常に高い精度を誇ります。

## セットアップ（開発者向け）

1. このリポジトリをクローンします。
2. Xcode 15.0以上で `DeepLocal.xcodeproj` を開きます。
3. **MLX Swift LM の追加**:
   - Xcode で `File` > `Add Package Dependencies...` を選択。
   - `https://github.com/ml-explore/mlx-swift-lm` を入力。
   - `Dependency Rule` を `Branch: main` に設定。
   - 以下のライブラリを `DeepLocal` ターゲットに追加：
     - `MLXLLM`
     - `MLXLMCommon`
4. ビルドして実機（Apple Silicon搭載のiPhone/iPad推奨）で実行。

## ロードマップ（概要）

1. **Phase 1: MVP** - `LFM2-350M-ENJP-MT` による基本的な翻訳機能の実装。
2. **Phase 2: UX改善** - 翻訳履歴、お気に入り、会話モードの追加。
3. **Phase 3: モデルカスタマイズ** - ユーザーが任意の（Hugging Face上の）モデルを選択・読み込める機能。
4. **Phase 4: OS統合** - iOSの共有拡張（Share Extension）やSiriとの連携。

詳細は [ROADMAP.md](ROADMAP.md) をご覧ください。

## ライセンス

MIT License

## コントリビューション

プルリクエストやIssueでの報告は大歓迎です。一緒に最高の翻訳アプリを作りましょう！
