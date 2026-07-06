# bochi v2.6 — PM Companion

アイデアの種（メモ・URL・ひらめき）を「構造化された仮説」に変換し、日々のPM活動を支えるコンパニオン Claude Code スキル。
**Discord DM から、いつでもこの Mac 上の Claude 本体と会話できる。**

## Product Vision

bochiは「PMの思考をどこからでもアクセスできるハブ」。

1. **思考のハブ**: Discord DM / Mac CLI / どこからでも同じ記憶にアクセスできる
2. **Mac 常駐の脳**: Discord の応答者は Mac 常駐の Claude Code 本体。ローカルFS・全プロジェクトの記憶にアクセスできる
3. **S3データハブ**: bochi-data は S3 経由で全環境同期。データは常に最新
4. **能動的メモ保存**: 価値ある会話はbochiが保存を提案する。ユーザーの「メモして」を待たない

## Architecture at a Glance

```
Discord DM（オーナーのみ allowlist）
  │ Gateway WebSocket（同一 Bot トークン、応答者は1つだけ）
  ├─ Lightsail server.ts … dmPolicy=disabled → 全 drop（新聞係として存続）
  └─ Mac server.ts ───────→ Mac 常駐 Claude Code セッション（唯一の --channels 応答者）
                             ├ tmux -L claude-bridge / launchd 常駐 + 2分 health
                             ├ cwd ~/bochi-runtime（CLAUDE.md = deploy/mac-claude.md）
                             ├ 権限3層: allow / ask（Discord 🔐 relay）/ hard-deny
                             └ ~/.claude/projects/*/memory を横断リコール
```

- **応答者は Mac**: `--channels plugin:discord` 付きで起動したセッションだけがメッセージを受け取る。Lightsail は `access.json` の `dmPolicy:"disabled"`（メッセージ毎ホットリロード・1キーで可逆）で受信を止めている。
- **新聞は Mac で生成→配信**: launchd が毎朝 06:20 JST に生成、08:00 JST に配信（下記）。
- 詳細な構成・運用・ロールバックは **`references/mac-bridge-setup.md`**。

## What's New in v2.6 (2026-07-06) — Mac-Resident Claude Bridge

- **常駐化**: launchd（RunAtLoad + 120秒 health）+ 専用 tmux socket `claude-bridge`。mobile-dev-bridge の caffeinate 基盤の上で 24/7 稼働。CLI 更新で消える起動文言に依存せず、アイドル TUI プロンプトを健全判定してリスタートループを防ぐ。
- **認証刷新**: `--dangerously-skip-permissions` 廃止 → default-deny 権限 + **Discord permission relay（スマホの 🔐 ボタンで承認）**。秘匿ストア・自己改変・tmux 干渉は fail-close guard で hard-deny。パス正規化＋大文字小文字非依存で APFS/`../`/相対パス/インタープリタ書込のバイパスを塞ぐ。
- **記憶ハブ**: `~/.claude/projects/*/memory/` を横断リコール。PC 状態は読み取り専用ラッパー（`pc-status` / `repo-status`）経由（生の `ps|grep`・`tmux ls` は権限プロンプトで会話が止まるため必ずラッパーを使う）。
- **不干渉ガードレール**: 他プロジェクトの Claude セッションに `send-keys`/`attach` しない。重い作業は headless `claude -p`/`--bg` への委譲を提案する。
- **新聞の生成復活**: Lightsail の RemoteTrigger 生成 cron は機能停止（配信は古い同じ号を毎日再送していた）。生成・配信とも Mac の launchd に移管し、配信は「今日の号」だけを送る（古い号へのフォールバックを撤廃）。
- **データ層**: bochi-data の実体を `~/bochi-data` へ移設（`~/.claude/` 配下への Write は sensitive-file ブロックされるため。`~/.claude/bochi-data` は symlink）。`seen.jsonl` は両側 push + union-merge 同期。
- 検証: `tests/mac-bridge-e2e.sh`（40チェック）+ `.evals/`（失敗タクソノミー + eval specs）。

<details>
<summary>v2.5 の変更 — Multimedia Research Expansion</summary>

- **YouTube/X リアルタイム連携**: Mode 1 Phase C の ReAct ループが YouTube RSS と X (Nitter RSS) を扱えるように。動画字幕は `scripts/fetch_yt_transcript.py` で取得し、`~/bochi-data/transcripts/` にキャッシュして全環境で共有。
- **動画/SNS 専用 E-E-A-T format cap**: 単独ツイート 24/40, スレッド 32/40, 動画+字幕 36/40, 記事 cap なし。鮮度ボーナス (+2/0/−2)。SNS-only 結論は "preliminary" タグ必須。
- **サブエージェント要約パターン**: 3分超の動画は `general-purpose` サブエージェントに要約依頼してから利用。
- **Phase D Check #6**: Video/SNS hygiene (記事ペア必須、ISO 鮮度、transcript 引用箇所明示)。
- **毎朝 Discord 新聞配信**: 記事カード形式、URL embed 抑制でモバイル読みやすさ最適化。

</details>

<details>
<summary>v2.0-v2.4 の変更</summary>

- **v2.4** — 全14 specのEdge Cases完備, SKILL.md DRY, Session Continuity Protocol, 49シナリオテスト
- **v2.3** — Mode 1 Spec分離, 能動的メモ保存, CI/CD, DXファイル, 47テスト
- **v2.2** — deploy/lightsail-claude.md, Mode 6 Google Brief, Mode 7 PM Tools, 40テスト
- **v2.1** — response-speed-spec (7技術), discord-ux-spec, seen-tracking cache
- **v2.0** — 5-Mode Router, Context Signal Triggers, Persistent Data Layer, Discord Integration
</details>

## 8 Modes

| Mode | Trigger | Purpose |
|------|---------|---------|
| 1 Idea | `bochiして`, URL, 思考系動詞+コンテキスト | Deep dive + expand + research |
| 2 Newspaper | `新聞`, `朝刊`, 毎朝 launchd | Daily curated news by interest |
| 3 Casual Chat | `おすすめ`, `何か面白い？` | Related updates + serendipity |
| 4 Memory | `記憶整理`, `覚えてること教えて` | Search, review, archive |
| 5 Companion | `メモある？`, `前に話したやつ` | Surface relevant memos during work |
| 6 Google Brief | `今日の予定`, `メール確認` | Calendar + Gmail from cache |
| 7 PM Tools | `イシュー一覧`, `チケット作って` | Linear/GitHub Issue delegation |
| 8 Vocab | `単語帳`, `クイズ`, 裸の英単語/フレーズ | 英単語帳 + SM-2クイズ + 一括追加 |

会話のデフォルト人格は Claude 本体（日本語・自然な口調）。上記トリガー時に `~/.claude/skills/bochi/SKILL.md` のモードルーターへ入る。

## Quick Start

### 会話（インストール済みなら不要）

Discord で bot に DM するだけ。応答者は Mac 常駐の Claude 本体。

### Mac ブリッジのセットアップ / 更新

```bash
cd ~/bochi
bash deploy/mac/setup-bridge.sh              # dry-run で内容確認
bash deploy/mac/setup-bridge.sh --apply      # ランタイム構築 + launchd 4本を登録
bash ~/bochi-runtime/bin/bridge-start.sh start
bash tests/mac-bridge-e2e.sh --with-lightsail
```

登録される launchd:

| Label | スケジュール | 役割 |
|-------|------------|------|
| `com.fideguch.claude-bridge` | RunAtLoad | ブリッジ本体起動 |
| `com.fideguch.claude-bridge-health` | 120秒 | 死活監視・上限モーダル自動処理 |
| `com.fideguch.bochi-newspaper-gen` | 06:20 JST | 今日の朝刊を生成 |
| `com.fideguch.bochi-newspaper-deliver` | 08:00 JST | 今日の朝刊だけ配信 |

運用コマンド・ロールバック手順は `references/mac-bridge-setup.md`。

## Mode 1: アイデア膨らまし (7-Phase Flow)

```
入力（メモ or URL）
  → Phase A: 深掘り — ソクラテス式8段階質問（最大5問）
  → Phase B: 拡張 — SCAMPER 7視点から2-3案を提示
  → Phase C: リサーチ — ReActループ + E-E-A-T品質評価
  → Phase D: 検証 — 第一原理チェック + バイアス検証（HARD-GATE）
  → Phase E: 出力 — Teresa Torres OST構造 + ユーザー仮説
  → Phase F: 次のステップ — brainstorming / interview-prep / 深掘り継続
  → Phase G: 学習 — フィードバック → プロフィール更新
```

## Mode 2: 新聞（生成→配信）

```
[生成] com.fideguch.bochi-newspaper-gen (06:20 JST)
  → deploy/mac/generate-newspaper.sh が claude -p を起動
  → user-profile.yaml の興味カテゴリ × WebSearch × E-E-A-T フィルタ
  → ~/bochi-data/newspaper/YYYY-MM-DD.md を表形式で出力（seen.jsonl 追記）
  → 生成失敗時は部分ファイルを残さない（配信は自動スキップ）

[配信] com.fideguch.bochi-newspaper-deliver (08:00 JST)
  → deploy/send-newspaper-to-discord.py が「今日の号」だけを配信
  → 今日の号が無ければ古い号を送らずスキップ（毎日同じ号の再送を防止）
  → 記事カード形式・URL embed 抑制でモバイル最適化
```

## Data Layer

実体は `~/bochi-data/`（`~/.claude/bochi-data` はそこへの symlink）。

```
~/bochi-data/
├── index.jsonl              # Master search index (JSONL append)
├── user-profile.yaml        # Interests, category weights, settings
├── seen.jsonl               # Seen article URL tracking（両側 union-merge 同期）
├── topics/                  # Researched topics (1 file each)
├── memos/                   # Cross-context memos (Discord/CLI)
├── newspaper/               # Daily brief archive (YYYY-MM-DD.md)
├── conversations/           # Bridge conversation logs
├── context-seeds/           # CLI→bridge handoff seeds
├── vocab/                   # Vocabulary notebook (Mode 8)
├── reflections/             # PDCA daily reflections
├── stats/usage.jsonl        # Skill usage stats
├── sources/verified.jsonl   # Verified source quality DB
├── cache/                   # Performance cache (calendar.md, gmail.md, trending/)
├── errors/                  # Error logs + watchdog + newspaper-gen/deliver logs
│   ├── known-patterns.jsonl # Known error pattern DB
│   └── bridge-watchdog.jsonl# Mac bridge restart/health events
└── archive/                 # Archived old data (never deleted)
```

### Write Ownership（応答者交代後）

| データ | 所有 | ブリッジの扱い |
|--------|------|--------------|
| memos/ index.jsonl context-seeds/ vocab/ errors/ topics/ conversations/ newspaper/ | Mac | 読み書き |
| seen.jsonl | 両側（union-merge） | 読み書き |
| user-profile.yaml reflections/ sources/ stats/ cache/ | Lightsail | 読み取り中心 |

## 統合フレームワーク

| フレームワーク | フェーズ | 出典 |
|-------------|---------|------|
| Socratic Method 8 Levels | Phase A | ソクラテス / 教育学 |
| SCAMPER | Phase B | Bob Eberle (1971) |
| ReAct Pattern | Phase C | Yao et al. (2022) |
| E-E-A-T | Phase C/D | Google Search Quality Guidelines |
| First-Principles Thinking | Phase D | Jensen Huang / NVIDIA |
| Opportunity Solution Tree | Phase E | Teresa Torres |
| Mom Test / JTBD | Phase F (handoff) | Rob Fitzpatrick / Clayton Christensen |

## アーキテクチャ詳細

### Owner-Only Learning Protocol

```
Message received → Owner (paired user)? → full interaction + learn + memorize
                → Other user?           → respond with read-only knowledge
```

Discord: `access.json` の paired user_id で判定（allowlist、オーナー1名）。

### Permission Model（3層）

| 層 | 対象 | 挙動 |
|----|------|------|
| allow | ホーム読取（deny 優先）/ bochi-data・workspace への書込 / WebSearch / trusted ドメイン WebFetch / Discord ツール / 状態ラッパー | 無プロンプト |
| ask | それ以外（他所への Write、任意 Bash、未知ドメイン WebFetch） | Discord 🔐 ボタンでスマホ承認 |
| hard-deny | 秘匿ストア（.ssh/.aws/gh/gcloud/token類）/ enforcement 自己改変 / tmux 干渉 | 承認でも不可（fail-close guard） |

### Self-Healing & Error Reporting

- health（120秒）が tmux/claude/gateway を監視。落ちれば再起動（5回/時 backoff）。
- **利用上限モーダル**を検知したら「待機」を自動選択し、オーナーに1回通知（リセット後に自動再開）。
- 権限プロンプトは自動承認しない（健全な待機扱い、10分超で通知）。
- Discord応答失敗時は必ずユーザーにエラー報告（沈黙禁止）。
- 詳細: `references/self-healing-spec.md`, `references/error-reporting-spec.md`

### 外部依存

| 依存 | 必須/任意 | 用途 |
|------|----------|------|
| Discord MCP Plugin | 必須（Discord 連携） | Discord DM 応答 |
| Context7 MCP | 任意 | 技術系リサーチでライブラリドキュメント参照 |
| gog CLI | 任意 | Google Calendar/Gmail同期（Mac側のみ） |
| Figma MCP | 任意 | FigJam図生成（Mode 1 Phase E） |

## 使わない方がいいユースケース

| ユースケース | 理由 | 代替 |
|------------|------|------|
| チームブレスト | 個人PM向け設計 | Miro AI, FigJam AI |
| 大量ソースの網羅的調査 | 3-5回の検索では限界 | OpenAI Deep Research |
| 要件が明確な場合 | 膨らましフェーズ不要 | /requirements_designer |
| データ分析・定量調査 | 定性的アイデア膨らまし特化 | /pm-data-analysis |
| 他ディレクトリの本格的な実装 | ブリッジは不干渉・委譲方針 | 対象ディレクトリの Claude / `claude -p` |

## フォルダ構成

```
bochi/
├── SKILL.md                        # Main skill (mode router)
├── SKILL-cli.md                    # Mac CLI companion 版
├── SKILL-server.md                 # [legacy] Lightsail server 版
├── README.md / README.en.md        # 本ファイル / 英語版
├── CONTRIBUTING.md / CHANGELOG.md
├── .github/workflows/quality.yml   # CI/CD（static + Lightsail infra E2E + Discord verify）
├── deploy/
│   ├── mac-claude.md               # [v2.6] Mac ブリッジ runtime CLAUDE.md
│   ├── mac/                        # [v2.6] Mac 常駐一式
│   │   ├── setup-bridge.sh         # 冪等インストーラ（dry-run 既定）
│   │   ├── bridge-start.sh         # start/restart/stop/status
│   │   ├── bridge-health.sh        # 死活監視 + 上限モーダル処理
│   │   ├── bridge-guard.sh/.py     # PreToolUse hard-deny（fail-close）
│   │   ├── notify-owner.sh         # REST 直叩き DM 通知
│   │   ├── generate-newspaper.sh   # 毎朝の朝刊生成（claude -p）
│   │   ├── deliver-newspaper.sh    # 今日の号だけ配信
│   │   ├── bin/{pc-status,repo-status}  # 読み取り専用ラッパー
│   │   └── templates/              # settings.json + launchd plist 4本
│   ├── lightsail-claude.md         # Lightsail CLAUDE.md（新聞係として存続）
│   ├── send-newspaper-to-discord.py# 配信本体（今日の号のみ・stale 再送しない）
│   ├── bochi-tmux-start.sh / bochi-health-check.sh  # Lightsail 常駐
│   └── protect-readonly.sh / restart-bot.sh / setup-cron.sh
├── tests/
│   ├── mac-bridge-e2e.sh           # [v2.6] Mac ブリッジ 40チェック
│   ├── discord-e2e.sh              # Discord 応答品質検証
│   └── infra-check.sh / data-integrity.sh / s3-sync-test.sh / run-all.sh
├── .evals/                         # [v2.6] specs-evals（失敗タクソノミー + eval specs）
├── examples/mode-1-walkthrough.md
├── scripts/fetch_yt_transcript.py
└── references/                     # 31 files (specs + data, on-demand load)
    ├── mac-bridge-setup.md         # [v2.6] セットアップ/運用/ロールバック runbook
    ├── idea-expansion-spec.md      # Mode 1
    ├── newspaper-spec.md           # Mode 2
    └── ...                         # casual-chat / memory / companion / discord-ux 等
```

## ライセンス・クレジット

各フレームワークの著作権・商標は原著者に帰属します。本スキルはこれらの手法を参考に独自に設計・実装したものです。
