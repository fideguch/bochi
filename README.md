# bochi v2.3 — PM Companion

アイデアの種（メモ・URL・ひらめき）を「構造化された仮説」に変換し、日々のPM活動を支えるコンパニオン Claude Code スキル。

## Product Vision

bochiは「PMの思考をどこからでもアクセスできるハブ」。

1. **思考のハブ**: Discord DM / Mac CLI / どこからでも同じ記憶にアクセスできる
2. **S3データハブ**: bochi-data → S3 → 全環境同期。データは常に最新
3. **能動的メモ保存**: 価値ある会話はbochiが保存を提案する。ユーザーの「メモして」を待たない

## What's New in v2.3

- **Thinking Hub**: Discord DMで生まれたアイデアがS3経由でMac CLIに自動伝播
- **Mode 1 Spec分離**: Phase A-G を `references/idea-expansion-spec.md` に抽出（DRY改善）
- **能動的メモ保存**: Intake Gateに4つのトリガー条件を追加
- **Edge Cases強化**: socratic-levels, expansion-framework, output-template, self-healing に追加
- **CI/CD**: markdownlint + 参照整合性チェック + テスト数検証
- **DXファイル**: CONTRIBUTING.md, CHANGELOG.md, examples/mode-1-walkthrough.md
- **47シナリオテスト**: Mode 4/5 の7件追加（全7モードカバー）

<details>
<summary>v2.0-v2.2 の変更</summary>

### v2.2 — Lightsail + Mode 6/7

- deploy/lightsail-claude.md, Mode 6 Google Brief, Mode 7 PM Tools, 40テスト

### v2.1 — Speed + Signals

- response-speed-spec (7技術), discord-ux-spec, seen-tracking cache

### v2.0 — Initial Release

- 5-Mode Router, Context Signal Triggers, Persistent Data Layer, Discord Integration
</details>

## 突出した強み

### 1. 裏付き拡張の一貫性
SCAMPER拡張 → ReActリサーチ → E-E-A-Tスコアリング → 第一原理クリティークが1スキルで完結する。
IDEO Design Thinking（拡張のみ）、OpenAI Deep Research（リサーチのみ）のどちらにもない統合フロー。

### 2. 学習蓄積設計
`learned-sources.md` + `feedback-log.md` + PDCA reflections + PostToolUse Hooks自動記録により、使い込むほどリサーチ精度が向上する。Miro AI / Juma / Perplexity には蓄積メカニズムがない。

> PostToolUse Hook (`bochi-feedback-capture.sh`) は [my_dotfiles](https://github.com/fideguch/my_dotfiles) の `claude/scripts/hooks/` に含まれ、`set_up.sh` で `~/.claude/scripts/hooks/` にシンボリックリンクされます。

### 3. PMパイプラインネイティブ統合
bochi（思考拡張）→ `/brainstorming`（設計探索）→ `/requirements_designer` → `/speckit-bridge` の上流として完全に整合。
`/pm-discovery-interview-prep` への自動ハンドオフでユーザー検証にも直結する。

### 4. Mobile-First PM Journey
Morning newspaper → commute memos → meeting-gap casual chat → evening memory review.

## 7 Modes

| Mode | Trigger | Purpose |
|------|---------|---------|
| 1 Idea | `bochiして`, URL, 思考系動詞+コンテキスト | Deep dive + expand + research |
| 2 Newspaper | `新聞`, `朝刊`, cron 08:00 JST | Daily curated news by interest |
| 3 Casual Chat | `雑談`, `何か面白い？` | Related updates + serendipity |
| 4 Memory | `記憶整理`, `覚えてること教えて` | Search, review, archive |
| 5 Companion | `メモある？`, `前に話したやつ` | Surface relevant memos during work |
| 6 Google Brief | `今日の予定`, `メール確認` | Calendar + Gmail from cache |
| 7 PM Tools | `イシュー一覧`, `チケット作って` | Linear/GitHub Issue delegation |

## Quick Start

```bash
# Install
cd ~/.claude/skills && git clone <repo-url> bochi

# Data directory is created on first use at ~/.claude/bochi-data/

# Basic usage — say: "bochiして" or "新聞" or "雑談"

# Discord setup (optional) — see references/discord-setup.md
```

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

## Data Layer

```
~/.claude/bochi-data/
├── index.jsonl              # Master search index (JSONL append)
├── user-profile.yaml        # Interests, category weights, settings
├── seen.jsonl               # Seen article URL tracking (dedup)
├── topics/                  # Researched topics (1 file each)
├── memos/                   # Cross-context memos (Discord/CLI)
├── newspaper/               # Newspaper archive
├── reflections/             # PDCA daily reflections
├── stats/usage.jsonl        # Skill usage stats
├── sources/verified.jsonl   # Verified source quality DB
├── cache/                   # Performance cache layer
│   ├── newspaper-draft.md   # Pre-generated newspaper (06:00 JST cron)
│   ├── trending/*.jsonl     # Category-specific trending article pool
│   ├── meta.json            # Cache TTL management
│   ├── calendar.md          # Google Calendar cache (S3 sync)
│   └── gmail.md             # Gmail top 10 cache (S3 sync)
├── errors/                  # Error logs + diagnosis reports
│   └── known-patterns.jsonl # Known error pattern DB (auto-accumulate)
└── archive/                 # Archived old data (never deleted)
```

### 3-Layer Freshness

| Layer | Condition | Access |
|-------|-----------|--------|
| Active | <90 days or recently referenced | Auto-surface |
| Warm | 90-180 days, no references | Explicit search only |
| Archive | >180 days or user-approved | Archive search only |

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

## アーキテクチャ

### Owner-Only Learning Protocol

```
Message received → Owner (paired user)? → full interaction + learn + memorize
                → Other user?           → respond with read-only knowledge
```

CLI: 全セッションがOwner。Discord: access.jsonのpaired user_idで判定。

### Discord UX

- **React即時応答** (HARD-GATE): メッセージ受信→他の処理の前にリアクション
- **セクション分割**: 各メッセージ300文字以内。DMにスレッドがないため引用返信チェーン
- **Progressive Disclosure**: react → "考えてるゆ" → edit_message → 新reply（push通知）
- **リアクションステータス**: received → searching → found → processing → done（カテゴリ別ランダム選択）
- 詳細: `references/discord-ux-spec.md`, `references/response-speed-spec.md`

### Self-Healing & Error Reporting

- セッション開始時にerrors/*.jsonlを調査、既知パターンは自動修復
- Discord応答失敗時は必ずユーザーにエラー報告（沈黙禁止）
- JSONL破損時の自動回復スクリプト（最大5行ロールバック）
- 詳細: `references/self-healing-spec.md`, `references/error-reporting-spec.md`

### RemoteTrigger Cron

| Trigger | Schedule | Purpose |
|---------|----------|---------|
| `bochi-prefetch` | 06:00 JST | Newspaper cache pre-generation |
| `bochi-daily` | 08:00 JST | Morning newspaper delivery + PDCA |

### 外部依存

| 依存 | 必須/任意 | 用途 |
|------|----------|------|
| Discord MCP Plugin | 任意 | Discord DM連携 |
| Context7 MCP | 任意 | 技術系リサーチでライブラリドキュメント参照 |
| gog CLI | 任意 | Google Calendar/Gmail同期（Mac側のみ） |
| github_project_manager skill | 任意 | Mode 7 PM Tools のGitHub操作委譲先 |
| Figma MCP | 任意 | FigJam図生成（Mode 1 Phase E） |

## 使わない方がいいユースケース

| ユースケース | 理由 | 代替 |
|------------|------|------|
| チームブレスト | 個人PM向け設計 | Miro AI, FigJam AI |
| 大量ソースの網羅的調査 | 3-5回の検索では限界 | OpenAI Deep Research |
| 要件が明確な場合 | 膨らましフェーズ不要 | /requirements_designer |
| データ分析・定量調査 | 定性的アイデア膨らまし特化 | /pm-data-analysis |
| 既存プロダクトのバグ修正 | 新アイデアではない | /brainstorming |
| 緊急度の高い意思決定 | 全フェーズ実行は時間がかかる | 直接Claudeに質問 |

## 品質スコア（Rubric Self-Assessment）

> 以下はGAFA Rubric v2（5次元×20点=100点満点）に基づく自己評価。

| 次元 | v2.2 | v2.3 | 判定根拠 |
|------|------|------|---------|
| Maintainability | 15 | 16 | Mode 1分離+DRY改善。References表重複が残存 |
| Reliability | 15 | 15 | 主要モードEdge Cases追加。全specカバーは未達 |
| Testing & CI | 10 | 14 | CI追加+47テスト。Mode 4/5テスト薄い |
| DX | 16 | 17 | CONTRIBUTING+CHANGELOG+examples全追加 |
| Product | 16 | 16 | Vision追加。S3スクリプト未実装で相殺 |
| **Total** | **72** | **78** | **Grade C+ → 目標B+(87)に向けて継続改善** |

## フォルダ構成

```
bochi/
├── SKILL.md                        # Main skill (329 lines, 7-mode router)
├── README.md                       # 本ファイル
├── README.en.md                    # English version
├── CONTRIBUTING.md                 # [v2.3] 貢献ガイド
├── CHANGELOG.md                    # [v2.3] 変更履歴
├── .markdownlint.json              # [v2.3] Lint設定
├── .github/workflows/quality.yml   # [v2.3] CI/CD
├── deploy/
│   └── lightsail-claude.md         # [v2.2] Lightsail CLAUDE.md
├── examples/
│   └── mode-1-walkthrough.md       # [v2.3] Mode 1 E2Eウォークスルー
└── references/                     # 26 files (specs + data, on-demand load)
    ├── idea-expansion-spec.md      # [v2.3] Mode 1 Phases A-G
    ├── newspaper-spec.md           # Mode 2
    ├── casual-chat-spec.md         # Mode 3
    ├── memory-spec.md              # Mode 4
    ├── companion-spec.md           # Mode 5 + S3 sync loop
    ├── google-brief-spec.md        # [v2.2] Mode 6
    ├── pm-tools-bridge-spec.md     # [v2.2] Mode 7
    ├── discord-ux-spec.md          # [v2.1] Discord UX
    ├── response-speed-spec.md      # [v2.1] 速度改善7技術
    ├── self-healing-spec.md        # 自己修復 + JSONL回復
    ├── scenario-tests.md           # [v2.3] 47シナリオテスト
    └── ...                         # 17 more spec/data files
```

## ライセンス・クレジット

各フレームワークの著作権・商標は原著者に帰属します。本スキルはこれらの手法を参考に独自に設計・実装したものです。
