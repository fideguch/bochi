# bochi — アイデア膨らましスキル

アイデアの種（メモ・URL・ひらめき）を「構造化された仮説」に変換する Claude Code スキル。

## 突出した強み

### 1. 裏付き拡張の一貫性
SCAMPER拡張 → ReActリサーチ → E-E-A-Tスコアリング → 第一原理クリティークが1スキルで完結する。
IDEO Design Thinking（拡張のみ）、OpenAI Deep Research（リサーチのみ）のどちらにもない統合フロー。

### 2. 学習蓄積設計
`learned-sources.md` + `feedback-log.md` + PostToolUse Hooks自動記録により、使い込むほどリサーチ精度が向上する。Miro AI / Juma / Perplexity には蓄積メカニズムがない。

### 3. PMパイプラインネイティブ統合
`/brainstorming` → `/requirements_designer` → `/speckit-bridge` の前段階として完全に整合。
`/pm-discovery-interview-prep` への自動ハンドオフでユーザー検証にも直結する。

## 使い方

### 起動方法
- `bochiして` / `アイデアを膨らませたい` / `このURL深掘りして`（即起動）
- `調べて欲しい` / `どうやるの` + アイデア文脈（コンテキスト判定で起動）

### 入力フォーマット
- テキストのアイデアメモ
- URL（記事・動画リンク）

### 出力先
- コンソール（語尾「ゆ」キャラ付き概要）
- `docs/bochi/YYYY-MM-DD-{要約}.md`（プロフェッショナルモードで自動保存）
- ユーザー指定の場所（Notion等）

## 6フェーズフロー

```
入力（メモ or URL）
  ↓
Phase A: 深掘り — ソクラテス式8段階質問（最大5問）
  ↓
Phase B: 拡張 — SCAMPER 7視点から2-3案を提示
  ↓
Phase C: リサーチ — ReActループ + E-E-A-T品質評価
  ↓
Phase D: 検証 — 第一原理チェック + バイアス検証（HARD-GATE）
  ↓
Phase E: 出力 — Teresa Torres OST構造 + ユーザー仮説
  ↓
Phase F: 次のステップ — brainstorming / interview-prep / 深掘り継続
```

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

## 評価スコア

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
bochi-skill/
├── SKILL.md              # メインスキル (226行)
├── README.md             # 本ファイル
├── README.en.md          # English version
└── references/
    ├── quality-criteria.md     # E-E-A-T品質評価基準
    ├── trusted-domains.md      # 信頼ドメインリスト
    ├── research-strategy.md    # ドメイン別リサーチ戦略
    ├── socratic-levels.md      # ソクラテス式8段階質問
    ├── expansion-framework.md  # SCAMPER拡張フレームワーク
    ├── critique-checklist.md   # 検証チェックリスト
    ├── output-template.md      # 出力テンプレート (OST統合)
    ├── interview-handoff.md    # interview-prep連携仕様
    ├── feedback-log.md         # ユーザーFB履歴 (自動追記)
    └── learned-sources.md      # 高品質ソース蓄積 (自動追記)
```

## ライセンス・クレジット

各フレームワークの著作権・商標は原著者に帰属します。本スキルはこれらの手法を参考に独自に設計・実装したものです。
