# bochi v2.0 — PM Companion

アイデアの種（メモ・URL・ひらめき）を「構造化された仮説」に変換し、日々のPM活動を支えるコンパニオン Claude Code スキル。

## What's New in v2.0

- **5-Mode Router**: アイデア膨らまし + 新聞 + 雑談 + 記憶管理 + コンパニオン
- **Context Signal Triggers**: 「考えて」「まとめて」等の抽象的な思考リクエストに自然に反応
- **Persistent Data Layer**: `~/.claude/bochi-data/` に JSONL インデックス + 3層記憶管理
- **Pipeline Position**: bochi → brainstorming → requirements_designer の上流/下流を明示
- **Discord Integration**: Channels経由でスマホからアイデアメモ・新聞閲覧
- **Cross-Context Memory**: Discord→CLI間でメモを自動共有

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

## 5 Modes

| Mode | Trigger | Purpose |
|------|---------|---------|
| 1 Idea | `bochiして`, URL, 思考系動詞+コンテキスト | Deep dive + expand + research |
| 2 Newspaper | `新聞`, `朝刊`, cron 08:00 JST | Daily curated news by interest |
| 3 Casual Chat | `雑談`, `何か面白い？` | Related updates + serendipity |
| 4 Memory | `記憶整理`, `覚えてること教えて` | Search, review, archive |
| 5 Companion | `メモある？`, `前に話したやつ` | Surface relevant memos during work |

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
├── user-profile.yaml        # Interests, settings
├── topics/                  # Researched topics (1 file each)
├── memos/                   # Cross-context memos
├── newspaper/               # Newspaper archive
├── reflections/             # PDCA daily reflections
├── stats/usage.jsonl        # Skill usage stats
├── sources/verified.jsonl   # Verified source quality DB
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

## 使わない方がいいユースケース

| ユースケース | 理由 | 代替 |
|------------|------|------|
| チームブレスト | 個人PM向け設計 | Miro AI, FigJam AI |
| 大量ソースの網羅的調査 | 3-5回の検索では限界 | OpenAI Deep Research |
| 要件が明確な場合 | 膨らましフェーズ不要 | /requirements_designer |
| データ分析・定量調査 | 定性的アイデア膨らまし特化 | /pm-data-analysis |
| 既存プロダクトのバグ修正 | 新アイデアではない | /brainstorming |
| 緊急度の高い意思決定 | 全フェーズ実行は時間がかかる | 直接Claudeに質問 |

## 設計目標スコア（Design Target Scores）

> 以下はスキル設計時の自己評価による目標スコアであり、第三者評価ではありません。

| カテゴリ | スコア |
|---------|--------|
| GAFA 6軸合計 | 57/60 (95.0%) |
| アイデア発散力 | 8/10 |
| リサーチ力 | 8/10 |
| 拡張力 | 8/10 |
| ブラッシュアップ力 | 9/10 |
| **総合** | **90/100** |

## フォルダ構成

```
bochi/
├── SKILL.md                        # Main skill (372 lines, 5-mode router + context signals)
├── README.md                       # 本ファイル
├── README.en.md                    # English version
└── references/
    ├── quality-criteria.md         # E-E-A-T品質評価基準
    ├── trusted-domains.md          # 信頼ドメインリスト
    ├── research-strategy.md        # ドメイン別リサーチ戦略
    ├── socratic-levels.md          # ソクラテス式8段階質問
    ├── expansion-framework.md      # SCAMPER拡張フレームワーク
    ├── critique-checklist.md       # 検証チェックリスト
    ├── output-template.md          # 出力テンプレート (OST統合)
    ├── interview-handoff.md        # interview-prep連携仕様
    ├── feedback-log.md             # ユーザーFB履歴 (自動追記)
    ├── learned-sources.md          # 高品質ソース蓄積 (自動追記)
    ├── newspaper-spec.md           # [v2.0] 新聞モード仕様
    ├── pdca-spec.md                # [v2.0] PDCA日次振り返り仕様
    ├── casual-chat-spec.md         # [v2.0] 雑談モード仕様
    ├── memory-spec.md              # [v2.0] 記憶管理仕様
    ├── companion-spec.md           # [v2.0] コンパニオンモード仕様
    ├── discord-setup.md            # [v2.0] Discord接続ガイド
    ├── skill-tracking-spec.md      # [v2.0] スキル使用統計仕様
    └── mobile-first-spec.md        # [v2.0] モバイルファーストUX仕様
```

## ライセンス・クレジット

各フレームワークの著作権・商標は原著者に帰属します。本スキルはこれらの手法を参考に独自に設計・実装したものです。
