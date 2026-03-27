# Mode 5: Companion Spec

## Overview

他スキル作業中にbochiの記憶を呼び出し、クロスコンテキストで知見を共有するゆ。

## Trigger

During other skill work: 「bochi」「メモある？」「前に話したやつ」「関連メモ」

## Flow

```
[Trigger: companion call during work]
  |
  [1] Detect current context:
      - Current working directory
      - Active skill (if identifiable from conversation)
      - Recent file edits
  |
  [2] Build search query from context
  |
  [3] grep index.jsonl for:
      - Tags matching current skill/project
      - Category matching current domain
      - Status: open memos (priority)
  |
  [4] Read matching files (max 3)
  |
  [5] Present concise summary
  |
  [6] User acts on memo -> update status
```

## Output Format

```
関連メモがあるゆ 💫

## Open Memos 📝
1. **{title}** ({date})
   > {memo content excerpt}
   Tags: {tags}

## Related Topics 📚
1. **{title}** ({date}) — {1行要約}

対応したら「対応したゆ」って教えてゆ！
```

## Context Detection Heuristics

| Signal | Search Strategy |
|--------|----------------|
| Working in `skills/X/` | Search tags for skill name "X" |
| File contains "requirements" | Search category:PM, tags:requirements |
| Recent conversation mentions topic | Search title/tags for topic keywords |
| User says "前に話した〇〇" | Direct keyword search on 〇〇 |

## Memo Status Updates

When user says "対応したゆ" or "done" or "完了":
1. Identify which memo was addressed (ask if ambiguous)
2. Edit the memo file: add `## Resolution` section with date and context
3. Update index.jsonl entry: add `"status":"addressed"`

## Auto-surface (Proactive)

When bochi detects high-relevance context match (≥2 tag overlaps):
- Surface without being asked
- Keep it brief: 1-2 lines max
- Format: 「💡 関連メモがあるゆ: {title} — 見るゆ？」
- Only once per session per memo (don't repeat)

## Cross-Channel Memo Flow

```
[Discord] User sends idea/note
  -> bochi creates memo in memos/YYYY-MM-DD-slug.md
  -> Appends to index.jsonl with channel:"discord"

[CLI] User works on related skill
  -> bochi auto-surfaces the memo (Mode 5)
  -> User addresses it
  -> Status updated to "addressed"
```

## Memo File Format

```markdown
# {Title}

- Date: YYYY-MM-DD
- Channel: cli|discord
- Tags: [tag1, tag2]
- Status: open|addressed
- Related: [topic-id-1, topic-id-2]

## Content
{User's original message or structured note}

## Context
{What was happening when this memo was created}

## Resolution (added when addressed)
- Date: YYYY-MM-DD
- Action taken: {what was done}
```
