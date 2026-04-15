# Mode 8: English Vocabulary Notebook Spec

## Overview

英単語をbochiに伝えて登録し、SM-2スペースドリピティションでクイズ復習するゆ。
全単語は永久保存。mastered になっても削除・アーカイブしない。

## Trigger

「単語」「英単語」「単語帳」「クイズ」「復習」「vocab」「単語登録」「単語一覧」
「単語テスト」「vocabulary」「英語」

## Subcommands

| Command | Trigger Examples | Action |
|---------|-----------------|--------|
| 登録 | 「ubiquitous 登録して」「この単語覚えたい」 | 単語エントリを notebook.jsonl に追記 |
| クイズ | 「クイズして」「復習」「vocab quiz」 | SM-2 に基づき単語を選択し出題 |
| 一覧 | 「単語帳見せて」「単語一覧」 | notebook.jsonl の全単語をテーブル表示 |
| 統計 | 「単語の統計」「vocab stats」 | mastery 分布、streak、正答率を表示 |
| 検索 | 「〇〇って登録してある？」「search vocab」 | keyword で notebook.jsonl を検索 |

## Learning Goal (HARD-GATE)

<HARD-GATE>
ユーザーの最終目標: **シリコンバレーのIT企業でPMとして英語が全く不自由なく使えるレベル**。
チームメイトとの日常会話・業務会話・スラングを含めてスムーズに話せること。

全ての判断をこの目標から逆算して行う:
- 単語選定: PM/Tech/Startup ドメインを重視
- フレーズ: ミーティング、プレゼン、1on1、スタンドアップで使う表現
- スラング: シリコンバレー特有の言い回し（ship it, dogfood, bikeshed, etc.）
- レジスター: フォーマル〜カジュアルまで幅広く
</HARD-GATE>

## Proactive Bulk Add (bochi推薦)

bochiはユーザーの目標・属性・現在レベルから逆算して、おすすめ単語を一括追加できる。

### トリガー
- 「おすすめ単語追加して」「単語帳充実させて」「bulk add」
- bochi が単語帳が少ないと判断した場合に提案（total_words < 20 のとき等）
- 初回セットアップ時

### カテゴリ別バッチ
| カテゴリ | 内容 | 優先度 |
|---------|------|--------|
| PM Core | sprint, backlog, stakeholder, prioritize, trade-off, scope creep... | 最高 |
| Meeting & Collaboration | align, sync up, circle back, take offline, action item, follow up... | 最高 |
| Tech Vocabulary | deploy, iterate, scalable, latency, throughput, refactor... | 高 |
| Presentation & Persuasion | compelling, articulate, leverage, advocate, drive consensus... | 高 |
| Silicon Valley Slang | dogfood, ship it, bikeshed, 10x, move the needle, low-hanging fruit... | 中 |
| Business & Strategy | acquisition, retention, churn, runway, burn rate, pivot... | 中 |
| Daily Conversation | grab coffee, heads up, touch base, no worries, sounds good... | 中 |

### 一括追加フロー
```
[1] カテゴリ選択（全部 or ユーザー指定）
[2] 50-100語を自動生成（notebook.jsonl に直接追記）
[3] 追加完了サマリーを表示
[4] 次回クイズで「もう知ってた？」チェック:
    → 「余裕！最初から知ってた」→ notebook.jsonl から削除（学習不要）
    → 通常回答 → SM-2 で継続
```

### Already-Known Check（既知チェック）
クイズ中にユーザーが即答 + 自己評価「余裕！」の場合:
- 「この単語、最初から知ってたゆ？📚」と確認
- YES → notebook.jsonl から削除 + stats.json 更新
- NO → mastery を "reviewing" に昇格（SM-2 通常進行）

## Bare Word Detection (Auto-trigger)

ユーザーが英単語1語（またはフレーズ）だけを送信した場合、Mode 8 登録フローを自動起動する。

### 判定ロジック
```
[Input is a single English word or short phrase (1-4 words)]
  |
  [Difficulty Gate] ターゲット1900レベル以上か？
    |
    YES → 登録フローへ（Step 1 以降）
    NO  → スキップ。通常応答（単語帳には追加しない）
```

### Difficulty Gate: ターゲット1900基準

<HARD-GATE>
以下の基準で単語の難易度を判定し、基礎的すぎる単語は登録しない:

**登録する（difficulty 3-5）**: ターゲット1900 以上の語彙
- 例: specific, hypothesis, accommodate, ubiquitous, leverage, substantial,
  acquisition, deteriorate, controversy, inevitable, reluctant, premise

**登録しない（difficulty 1-2）**: 中学〜高1レベルの基礎日常語彙
- 例: run, big, happy, eat, house, school, beautiful, important, think, good

**判定の目安**:
- 日本の高校2年生が「あ、これ知らない/あやしい」と感じるレベル → 登録
- 日本の中学生でも知っている → スキップ
- 迷ったら登録側に倒す（覚えて損はない）
</HARD-GATE>

### スキップ時の応答
基礎単語と判定した場合、無言でスキップ。わざわざ「簡単すぎるゆ」とは言わない。
ユーザーが明示的に「この単語登録して」と言った場合は難易度に関わらず登録する。

## Flow: Registration

```
[Trigger: user mentions a word to register OR bare English word detected]
  |
  [0] Difficulty Gate: ターゲット1900レベル以上か？
      → NO: スキップ（通常応答）
      → YES: 続行
  |
  [1] Extract word from user input
  |
  [2] Auto-complete entry fields:
      - pos (part of speech): infer from context or ask
      - meaning_ja: generate Japanese meaning
      - meaning_en: generate English definition
      - example: generate example sentence
      - context: current working context or user-specified
      - tags: infer from domain
      - difficulty: 3-5 scale (ターゲット1900基準。Gate通過後なので最低3)
  |
  [3] 即登録（確認ステップなし）
      ユーザーの指示により、確認なしで自動登録する。
      間違いがあればユーザーが「取り消して」と指示する。
  |
  [4] 登録実行:
      - Generate unique ID: vocab-YYYYMMDD-NNN
      - Set sm2 defaults: {interval:1, repetition:0, easiness:2.5, next_review:tomorrow}
      - Set mastery: "new"
      - Append to notebook.jsonl
      - Update stats.json (total_words++)
      - Append daily summary to index.jsonl (1 entry per day, updated)
  |
  [5] Confirm: 「登録したゆ！💗 明日クイズに出すゆ〜」
```

## Flow: Quiz

```
[Trigger: user requests quiz]
  |
  [1] Read notebook.jsonl
  |
  [2] Select words by priority:
      Priority 1: next_review <= today (overdue)
      Priority 2: mastery == "new" (never reviewed)
      Priority 3: mastery == "learning"
      Priority 4: mastery == "reviewing" (reinforcement, random)
      Max per session: user_profile.english_learning.daily_quiz_target (default 5)
  |
  [3] Select quiz format per word:
      | mastery | Default Format |
      |---------|----------------|
      | new / learning | EN→JA (show English, answer meaning) |
      | reviewing | JA→EN or Fill-in-the-blank |
      | mastered | Fill-in-the-blank or Context |
      Override: user can request specific format
  |
  [4] Present question one at a time:
      - EN→JA: 「"ubiquitous" ってどういう意味ゆ？🌟」
      - JA→EN: 「"どこにでもある" を英語で言うとゆ？💫」
      - Fill-in-the-blank: 「Cloud computing has become _____.✨」
      - Context: 「"present everywhere" を表す形容詞はゆ？💗」
  |
  [5] Evaluate user answer:
      - Correct: exact match or semantic equivalent
      - Partial: close but not precise
      - Incorrect: wrong answer
  |
  [6] Show result + correct answer
  |
  [7] Self-assessment (3 levels):
      - 「全然わからなかった」→ SM-2 quality = 1 (interval reset)
      - 「ちょっと怪しい」→ SM-2 quality = 3 (normal progression)
      - 「余裕！」→ SM-2 quality = 5 (interval extension)
  |
  [8] Update SM-2 parameters in notebook.jsonl:
      - Recalculate: interval, repetition, easiness, next_review
      - Update: review_count++, last_reviewed, mastery level
  |
  [9] Append session to review-log.jsonl
  |
  [10] Update stats.json (quiz_streak, total_quizzes, total_correct)
  |
  [11] Session summary: 「今日は N問やったゆ！正答率 X% 💗」
```

## SM-2 Algorithm (Simplified)

```
Input: quality (1 | 3 | 5), current sm2 state
Output: updated sm2 state

if quality < 3:
    repetition = 0
    interval = 1
else:
    if repetition == 0:
        interval = 1
    elif repetition == 1:
        interval = 6
    else:
        interval = round(interval * easiness)
    repetition += 1

easiness = max(1.3, easiness + 0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02))
next_review = today + interval days
```

### Mastery Transitions

| From | To | Condition |
|------|-----|-----------|
| new | learning | First review completed (any quality) |
| learning | reviewing | repetition >= 2 AND interval >= 6 |
| reviewing | mastered | repetition >= 5 AND interval >= 21 |
| mastered | reviewing | quality == 1 (forgot, interval reset) |
| reviewing | learning | quality == 1 AND repetition was < 3 |
| learning | new | Never happens (no regression below learning) |

## Data Format: notebook.jsonl

One JSON object per line. Fields:

| Field | Type | Description |
|-------|------|-------------|
| id | string | `vocab-YYYYMMDD-NNN` (unique, sequential per day) |
| word | string | English word, phrase, or grammatical expression (そのまとまりで保存) |
| pos | string | 以下のいずれか (下記参照) |
| meaning_ja | string | Japanese meaning |
| meaning_en | string | English definition |
| example | string | Example sentence using the word/phrase |
| example_ja | string\|null | 例文の日本語訳（フレーズ・文法表現では特に重要） |
| context | string | Where the word was encountered |
| tags | string[] | Domain tags (business, tech, academic, daily, etc.) |
| registered_at | string | ISO 8601 timestamp with timezone |
| difficulty | number | 1-5 (1=common, 5=rare/specialized) |
| sm2 | object | `{interval, repetition, easiness, next_review}` |
| review_count | number | Total times reviewed |
| last_reviewed | string\|null | ISO 8601 timestamp of last review |
| mastery | string | `new` \| `learning` \| `reviewing` \| `mastered` |

### pos（品詞・種類）ガイド

| pos | 対象 | 例 |
|-----|------|-----|
| noun | 名詞 | acquisition, hypothesis, premise |
| verb | 動詞 | accommodate, deteriorate, leverage |
| adjective | 形容詞 | ubiquitous, substantial, reluctant |
| adverb | 副詞 | inevitably, predominantly, substantially |
| phrase | 句動詞・複数語表現 | take into account, come up with, carry out |
| idiom | 慣用句・イディオム | break the ice, cut corners, the bottom line |
| grammar | 文法構文・言い回し | not only A but also B, the more... the more..., it is ~ that... |
| collocation | よく使われる語の組み合わせ | make a decision, reach a conclusion, raise concerns |

**フレーズ・文法表現の登録ルール**:
- `word` フィールドにはそのまとまりをそのまま保存（分解しない）
- `meaning_ja` は「どういう場面で使うか」を含める
- `example` は実際の文中での使用例を必ず含める
- `example_ja` は日本語訳を付ける（フレーズは特に重要）
- クイズでは穴埋め or 文脈形式を優先（フレーズは単語より長いため）

## Data Format: review-log.jsonl

One JSON object per quiz session:

```json
{
  "session_id": "review-20260414-001",
  "date": "2026-04-14",
  "words_tested": 5,
  "correct": 4,
  "results": [
    {"word_id": "vocab-20260414-001", "format": "en_to_ja", "quality": 5, "correct": true},
    {"word_id": "vocab-20260413-002", "format": "fill_blank", "quality": 3, "correct": true}
  ],
  "duration_minutes": 8
}
```

## Data Format: stats.json

```json
{
  "total_words": 42,
  "mastery_distribution": {"new": 5, "learning": 12, "reviewing": 18, "mastered": 7},
  "quiz_streak": 3,
  "last_quiz_date": "2026-04-14",
  "total_quizzes": 15,
  "total_correct": 58,
  "updated_at": "2026-04-14T22:00:00+09:00"
}
```

## Output Format: Registration

```
単語を登録するゆ！✨

📝 **ubiquitous** (adjective)
- 意味: どこにでもある、偏在する
- English: present, appearing, or found everywhere
- 例文: Cloud computing has become ubiquitous in modern business.
- 文脈: DDD documentation
- タグ: business, tech
- 難易度: ★★★☆☆

登録したゆ！💗 明日クイズに出すゆ〜
```

## Output Format: Quiz

```
英単語クイズの時間ゆ！🌟 今日は 5問 いくゆ〜

Q1. "ubiquitous" ってどういう意味ゆ？

> [user answers]

正解ゆ！💗 「どこにでもある」
どのくらいの手応えだったゆ？
1. 全然わからなかった
2. ちょっと怪しい
3. 余裕！
```

## Output Format: List

```
単語帳を見せるゆ 📚 (全42語)

| # | Word | Mastery | Next Review | Tags |
|---|------|---------|-------------|------|
| 1 | ubiquitous | 🟢 mastered | 2026-05-01 | business |
| 2 | leverage | 🟡 reviewing | 2026-04-16 | business |
| 3 | iterate | 🔵 learning | 2026-04-15 | tech |
| 4 | ephemeral | 🔴 new | — | tech |

Mastery: 🔴 new  🔵 learning  🟡 reviewing  🟢 mastered
```

## Output Format: Statistics

```
英単語の統計ゆ 📊

📚 総登録数: 42語
🔴 new: 5語 | 🔵 learning: 12語 | 🟡 reviewing: 18語 | 🟢 mastered: 7語
🔥 連続クイズ日数: 3日
📝 累計クイズ: 15回 (正答率 77.3%)
最終クイズ: 2026-04-14
```

## Persistence Rule (CRITICAL)

<HARD-GATE>
英単語データは永久保存する。以下の操作は禁止:
- notebook.jsonl からのエントリ削除
- mastered 単語のアーカイブ移動
- freshness decay の適用（bochi メモの active→warm→archive は vocab に適用しない）
- 古い単語の自動クリーンアップ

SM-2 の interval が伸びるだけで、単語自体は永続する。
全単語がいつでも検索・クイズ・一覧で引き出せる状態を維持する。
</HARD-GATE>

## Cross-Mode Integration

| Mode | Integration |
|------|-------------|
| Mode 2 (Newspaper) | 新聞記事で出会った単語 → 「登録するゆ？」と提案 |
| Mode 5 (Companion) | 作業中に登録済み単語が文脈に出現 → 「前に覚えた単語ゆ！💫」 |
| Mode 1 (Deep Dive) | リサーチ中の専門用語 → 登録提案 |

## index.jsonl Integration

個別の単語は index.jsonl に追加しない（肥大化防止）。
日次サマリーを1エントリとして追加・更新:

```json
{"id":"vocab-summary-20260414","type":"vocab-summary","title":"英単語 +3語 (ubiquitous, leverage, iterate)","date":"2026-04-14","category":"English","tags":["vocab"],"freshness":"active","path":"vocab/notebook.jsonl"}
```

> index.jsonl の freshness は検索用メタデータ。vocab エントリは永久に "active"。

## Edge Cases

- **取り消し** → 「〇〇 取り消して」「さっきの消して」「undo」で直前または指定の単語を notebook.jsonl から削除し stats.json を更新。永続保存原則の例外: ユーザー明示指示による取り消しのみ許可。
- **Duplicate word registration** → 「その単語はもう登録してあるゆ！📝 復習するゆ？」
- **Empty notebook on quiz request** → 「まだ単語が登録されてないゆ。何か覚えたい単語あるゆ？💗」
- **All words mastered, none due** → 「今日は復習する単語がないゆ！🌟 新しい単語を登録するゆ？」
- **notebook.jsonl corrupted line** → Skip invalid lines, log warning, continue with valid entries
- **Quiz with only 1-2 words** → Proceed with available words, note: 「まだ少ないけどやるゆ！✨」
- **User gives wrong format answer** → Accept semantic equivalents; when ambiguous, ask for clarification
- **Batch registration** → 「まとめて登録」: accept comma-separated or list, process each with auto-complete

## Implementation Status

| Component | Status | Evidence |
|-----------|--------|----------|
| vocab-notebook-spec.md | ✅ Created | This file |
| notebook.jsonl | ✅ Created | Empty file at bochi-data/vocab/ |
| review-log.jsonl | ✅ Created | Empty file at bochi-data/vocab/ |
| stats.json | ✅ Created | Initial values at bochi-data/vocab/ |
| user-profile.yaml | ✅ Modified | english_learning section added |
| SKILL.md Mode Router | ✅ Modified | Mode 8 (Vocab) added |
| SKILL.md Data Layer | ✅ Modified | vocab/ entry added |
| SKILL.md Write Ownership | ✅ Modified | vocab/ added |
| SKILL.md description | ✅ Modified | vocab trigger words added |
