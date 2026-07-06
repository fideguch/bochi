# Error Analysis: 2026-07-06 (Mac 常駐ブリッジ導入前調査)

> Phase 1 必須ゲート。メトリクスより先に実トレースを読む。
> 対象 SUT: Discord → Mac 常駐 Claude Code ブリッジ（bochi v2.6 で導入）

## 入力 (Inputs)

- trace source:
  - Lightsail `/home/ubuntu/bochi-data/errors/watchdog.jsonl`（2026-03-28〜、実運用の全再起動イベント）
  - Lightsail `errors/known-patterns.jsonl`（既知エラー DB）
  - リポジトリの修正履歴（d498afa: health-check 誤検知修正、CHANGELOG v2.5〜v2.6 の seen.jsonl 全壊事故、server.ts recipientId パッチ）
  - 2026-07-06 設計レビュー（4 レンズ敵対レビュー）での実機検証済み欠陥
- 件数: watchdog イベント 18 件 + 文書化済みインシデント 4 件 + レビュー実証欠陥 6 件（bootstrap モード相当、15 件以上）

## Step 1: Open Coding（観察した失敗・自由記述）

| # | trace ref | 観察した失敗 |
|---|-----------|--------------|
| 1 | watchdog.jsonl 2026-03-30T07:10 | pane 応答性プローブが unresponsive を誤検知 → recovery_failed 連発（idle 状態を「無応答」判定） |
| 2 | watchdog.jsonl 2026-05-02, 06-06 | stale flock inode により restart がブロック → forced_inode_reset で復旧 |
| 3 | known-patterns.jsonl | bun が非ログインシェルの PATH に無く MCP subprocess 起動失敗 |
| 4 | CHANGELOG v2.5→v2.6 | Bash `echo >>` による ~/.claude/ 書込がブロックされ seen.jsonl が空に（既読管理全壊） |
| 5 | lightsail-claude.md | プラグイン更新で server.ts の recipientId パッチが消え DM 解決不能 |
| 6 | レビュー実証 2026-07-06 | claude 2.1.195+ で起動文言が変更（`Listening for channel messages` → `Listening for messages from ${channel}`）。旧文字列依存の health は再起動ループを起こす |
| 7 | レビュー実証 | macOS に flock(1) が存在せず Linux 版起動スクリプトは移植不能 |
| 8 | レビュー実証 | 同一トークン複数 gateway 接続 + `--channels` セッション複数化で二重応答の構造リスク |
| 9 | レビュー実証 | S3 push の Darwin 除外リスト（seen.jsonl 等）により、応答者交代後は書込が同期されず pull で巻き戻る |
| 10 | レビュー実証 | permission プロンプト放置で後続メッセージも injection されず bot 全体が沈黙 |
| 11 | レビュー実証 | additionalDirectories は write も付与 / Bash 経由の読取は Read deny を迂回（秘匿 exfil 経路） |
| 12 | レビュー実証 | グローバル hooks（Stop 通知音・pm-pipeline-guard 等）が常駐セッションに全発火 |

## Step 2: Axial Coding（具体的カテゴリ）

| taxonomy-id | カテゴリ名（具体的） | 説明 |
|-------------|---------------------|------|
| T1 | 監視誤検知・自己修復の暴走 | pane 文字列/ハッシュ依存の health が CLI 更新や idle 状態で誤判定し、不要再起動・再起動ループを起こす（#1, #6） |
| T2 | 実行環境ドリフト（PATH/OS 差分/CLI 更新） | launchd/非ログインシェルの PATH 欠落、macOS に無いコマンド（flock）、日次 CLI 自動更新による挙動変化（#3, #7, #6） |
| T3 | 応答者の一意性崩壊（二重応答/無応答） | 複数 --channels セッション、カットオーバー手順ミス、permission スタックによる全体沈黙（#8, #10） |
| T4 | データ層の書込経路事故 | ~/.claude/ 書込ブロック、S3 所有権と push/pull 除外の不整合による巻き戻り・消失（#4, #9） |
| T5 | 権限境界の迂回・過剰権限 | add-dir の write 付与、Bash による Read deny 迂回、自己改変（#11） |
| T6 | 外部コンポーネント更新による破壊 | プラグイン更新でのパッチ消失、グローバル hooks との干渉（#5, #12） |

## Step 3: 頻度・優先度

| taxonomy-id | 件数 | 優先度 | eval 化 |
|-------------|------|--------|---------|
| T1 | 5 | 高（実運用で recovery_failed 連発の実績） | mac-bridge-runtime |
| T3 | 4 | 最高（ユーザー体験の直撃 = 沈黙/二重応答） | mac-bridge-runtime |
| T4 | 3 | 高（データ全壊の前科） | mac-bridge-runtime |
| T5 | 3 | 高（24/7 で injection 面が常時開く） | mac-bridge-security |
| T2 | 3 | 中（起動不能として顕在化） | mac-bridge-runtime |
| T6 | 2 | 中 | runbook + 手動チェック |

## Step 4: saturation 判定

- [x] レビュー 4 レンズ + 実トレースで新カテゴリの増加が止まった（T1-T6 で飽和）

## 出力

- eval spec 化: `specs/mac-bridge-runtime.eval.md`（T1/T2/T3/T4）、`specs/mac-bridge-security.eval.md`（T5）
- deterministic grader の実体は `tests/mac-bridge-e2e.sh`（exit code 契約）
