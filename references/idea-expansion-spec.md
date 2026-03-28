# Mode 1: アイデア膨らまし — Phases A-G Spec

## Overview

Mode 1はユーザーの曖昧なアイデアを構造化仮説に変換するフローゆ。
Phase A-Gを順に実行し、各Phaseは専用referenceをロードする。

---

## Phase A: Deep Dive — Socratic Questioning

Load: `references/socratic-levels.md`

ユーザーの入力レベルに応じて8段階から適切なレベルを選択するゆ。

- 曖昧な入力 → Level 1-2（明確化・仮定検証）から
- 明確な構想 → Level 4-5（視点転換・含意探索）から
- **1問ずつ、最大5問。** ユーザーが「十分」と言えば即終了

## Phase B: Expand — SCAMPER Framework

Load: `references/expansion-framework.md`

ユーザーのアイデアに対してSCAMPER 7視点から**最も効果的な2-3視点を選択**し、
各視点から具体的な拡張案を1つずつ提示するゆ。

1. ユーザーのアイデアを1文で要約
2. 2-3の拡張案を提示（各視点+具体例）
3. ユーザーが方向性を選択 → Phase Cのリサーチに反映

## Phase C: Research — ReAct Loop

Load: `references/research-strategy.md`, `references/quality-criteria.md`,
      `references/trusted-domains.md`, `references/learned-sources.md`

ReAct（Thought → Action → Observation）パターンでリサーチするゆ。

**Loop (max 5 iterations):**
1. **Thought**: 「このアイデアの検証には〇〇の情報が必要ゆ」
2. **Action**: WebSearch（ドメイン別戦略に従いクエリ生成）
3. **Observation**: 結果をE-E-A-T 4軸で評価
4. **Next Thought**: 足りない角度があれば追加検索

**Research Rules:**
- 最初の3検索クエリは**並列実行**する（response-speed-spec.md参照）
- 結果依存の追加クエリのみ直列（最大2回）
- trusted-domains.md のドメインを優先するが排他的ではない
- learned-sources.md の既知高品質ソースも参照
- 技術系アイデア → Context7 MCP（mcp__context7__query-docs）を併用。MCPが利用不可の場合はWebSearchで代替。Context7の有無で品質は変わるが動作は保証
- WebFetch で上位候補の本文を取得し深く分析
- 各ループのThought/Observationをユーザーに簡潔に提示

## Phase D: Critique — Self-Verification

Load: `references/critique-checklist.md`

<HARD-GATE>
リサーチ結果を出力する前に `references/critique-checklist.md` の全チェックを実行する。
全チェックを通過しないと Phase E に進めない。
不合格 → Phase Cに戻り追加検索（最大2回リトライ）。
2回リトライ後も不合格 → ユーザーに正直に報告し手動判断を仰ぐ。
</HARD-GATE>

## Phase E: Output — Structured Summary

Load: `references/output-template.md`

**Console Output** (語尾「ゆ」あり):
- アイデア概要（何を/なぜ/誰に）
- SCAMPER拡張で選択した方向性
- 高品質ソース3件（タイトル+E-E-A-Tスコア+要約）
- 関連記事3件
- 検証結果サマリー
- 機会→解決策→実験（Teresa Torres OST風）
- ユーザー仮説

**File Output** (プロフェッショナルモード):
`~/.claude/bochi-data/topics/YYYY-MM-DD-{slug}.md` に自動保存。
テンプレートは `references/output-template.md` に従う。語尾「ゆ」なし。

### Source Citation Format

アウトプットのソース表示は以下のルールに従う:

1. **ハイパーリンク形式**: `[タイトル要約 — ドメイン名](URL)`
2. **タイトル要約**: 記事の内容を1語〜短いフレーズで要約（原題そのままではない）
3. **ドメイン名**: URLからドメインだけ抽出して含める（example.com形式）
4. **件数**: 各情報ブロックに対し1-2件。過剰に貼らない
5. **配置**: 情報の直後にインラインで。テーブル内ではSource列にドメインリンク

**コンソール例（Discord/CLI）:**
```
SaaSのチャーン対策としてオンボーディング自動化が注目されているゆ ✨
📎 [SaaS解約防止の最新手法 — note.com](https://note.com/xxx)
```

**テーブル例（ファイル出力）:**
```
| 1 | SaaS解約防止手法 | [note.com](URL) | 32/40 | オンボーディング自動化で30%改善 |
```

**Index Update** (CRITICAL):
After writing the topic file, append to index.jsonl via Bash:
```bash
echo '{"id":"topic-YYYYMMDD-NNN","type":"topic","title":"...","date":"...","category":"...","tags":[...],"freshness":"active","channel":"cli","path":"topics/YYYY-MM-DD-slug.md"}' >> ~/.claude/bochi-data/index.jsonl
```

Verified sources → append to `sources/verified.jsonl`:
```bash
echo '{"url":"...","domain":"...","eeat_score":32,"date":"...","topic_id":"..."}' >> ~/.claude/bochi-data/sources/verified.jsonl
```

## Phase F: Next Steps

ユーザーに以下の選択肢を提案するゆ:

1. **「/brainstorming で設計に落とすゆ？」** — 設計フェーズへ
2. **「/pm-discovery-interview-prep でユーザーに聞いてみるゆ？」** — ユーザー検証へ
3. **「/requirements_designer で要件定義に進むゆ？」** — 本格要件定義へ
4. **「もっと深掘りするゆ？」** — bochi継続
5. **「新聞に追加するゆ？」** — user-profileのinterestsに反映
6. **「/pm-figjam-diagrams でFigJamに図化するゆ？」** — OST・仮説・フローをFigJam図に変換

### pm-figjam-diagrams Handoff

ユーザーが選択肢6を選んだ場合、自動引き継ぎ。
topics/最新ファイルのパスを `/pm-figjam-diagrams` に渡し、bochi連携モード（Pattern B）で起動。

### pm-discovery-interview-prep Handoff

Load: `references/interview-handoff.md`

ユーザーが選択肢2を選んだ場合、自動引き継ぎ。

## Phase G: Learning

ユーザーのフィードバックに基づき学習するゆ。

- **肯定FB**: feedback-log.md に追記 + Phase Cソースを learned-sources.md に追記
- **否定FB**: feedback-log.md に改善ポイント付きで記録
- **サイト品質評価**: E-E-A-T結果を sources/verified.jsonl に蓄積

---

## Edge Cases

- **Phase A: ユーザー沈黙（30秒無反応）** → 1回だけ「考え中ゆ？待つゆ💫」、2回目以降はPhase B進行を提案
- **Phase A: 入力が1単語のみ** → Level 1（明確化）から開始
- **Phase B: ユーザーが全SCAMPER視点を拒否** → 「じゃあ別の角度で考えるゆ？それとも今の方向で深掘りするゆ？」
- **Phase C: WebSearch 0件** → クエリを広げて再検索（最大3回、5イテレーション上限とは別カウント）
- **Phase C: Context7 MCP不可** → WebSearchで代替（既存ルール）
- **Phase D: 2回リトライ後も不合格** → 正直にユーザーに報告（既存HARD-GATE）
- **Phase E: ファイル書き込み失敗** → Discord/CLIに結果を直接出力、保存は次回リトライ
- **Phase F: ユーザーが選択肢を選ばず離脱** → 会話終了として扱う（強制しない）
- **Phase G: feedback-log.md不在** → 自動生成してから追記
