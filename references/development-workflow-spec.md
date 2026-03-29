# bochi Development Workflow Spec

## 原則: クラウドがメインプロダクト

bochiのメインプロダクトは **Lightsail上で稼働するDiscord bot**（SKILL-server.md）。
Mac CLI版（SKILL-cli.md）はコンパニオンモード（Mode 5-6のみ）。

すべての開発判断は「クラウドのユーザー体験にどう影響するか」を基準にする。

## 開発前チェック（HARD-GATE）

<HARD-GATE>
bochi の仕様変更・バグ修正を開始する前に、以下を必ず実行する:

1. **環境判定**: この変更はローカル(Mac CLI)かクラウド(Lightsail)か、両方か？
   - Mode 1-4, 7 → クラウド（SKILL-server.md + references/）
   - Mode 5-6 → ローカル（SKILL-cli.md）
   - データ構造・共通ルール → 両方
   - 判定結果を計画に明記すること

2. **デプロイ計画**: クラウド対象の変更には以下を計画に含めること:
   - git push origin main
   - SSH → restart-bot.sh（手動SSHコマンド禁止）
   - Discord DM E2Eテスト（R1: spec完了→同セッションE2E）

3. **spec矛盾チェック**: reference specの指示がSKILL-server.mdや
   lightsail-claude.mdと矛盾していないか確認
   例: lightsail-claude.mdがWrite tool指定なのにreference specがBash echo指定 → 矛盾
</HARD-GATE>

## ローカル→クラウド反映保証

ローカルでspec/コードを修正した場合、以下の**全ステップ完了まで「完了」と言わない**:

1. git commit + push（mainブランチ）
2. Lightsailでgit pull + restart-bot.sh実行
3. Discord DMで対象機能のE2Eテスト
4. テスト結果をハンドオフメモに記録

「ローカルで修正した」は完了ではない。「クラウドで動作確認した」が完了。

## 逆方向: クラウド→ローカル反映

Lightsailで直接修正した場合（緊急hotfix等）:
1. 修正内容をMac側のリポジトリにも反映
2. git push（Mac → GitHub → 次回Lightsail pullで同期）

## v2.4 postmortem 適用ルール

このspecは以下のpostmortemルールを制度化したもの:

- **R1**: Spec完了→同セッションE2Eテスト
- **R2**: モード間依存は依存元から検証
- **R5**: 存在チェック≠機能チェック
- **feedback_spec_vs_infra_gap**: specが完璧でもランタイム未構築なら機能しない

## spec矛盾の教訓（v2.6）

v2.5→v2.6で発覚した事例:
- `lightsail-claude.md` (L100): 「Write/Editツールを使用。Bash echo不可」
- `casual-chat-spec.md` HARD-GATE: Write tool (read-append) に修正済み
- 結果: Permission制御でブロック → seen.jsonl空 → 既読管理全壊 → 記事が毎回同じ

**教訓**: reference specはon-demandロードされるため、ランタイム仕様（lightsail-claude.md）
との整合性が見落とされやすい。新規・変更時に必ずクロスチェックすること。
