# Mobile-First Spec

## Overview

PMのモバイルジャーニーに最適化した操作設計ゆ。

## Daily Mobile Journey

| Time | Action | Discord Operation | bochi Mode |
|------|--------|-------------------|------------|
| Morning | Read newspaper | Embed scroll + reactions | Mode 2 |
| Commute | Idea memo | Text message -> auto memo | Mode 5 |
| Between meetings | Casual check | 3-5 items -> save with pin | Mode 3 |
| On the move | Permission approval | `yes abcde` | Permission relay |
| Evening | Memory review | "今日のまとめ" | Mode 4 |

## Minimal Interaction Design

### Idea Capture (1 step)
User sends any text in Discord DM -> bochi auto-categorizes and creates memo.
No commands needed. No formatting required.

### Reaction Feedback (1 tap)
- Tap emoji on newspaper/chat item
- bochi interprets and adjusts weights
- No text reply needed

### Skill Invocation (1 message)
- Send shorthand: "req-designer", "データ分析", "brainstorm"
- bochi fuzzy matches and confirms

### Permission Approval (1 message)
- `yes abcde` or `no abcde`
- 5 characters, no ambiguity

## 4 Handoff Patterns

### 1. Bookmark for Desktop
```
[Discord] User reacts 📌 to newspaper article
  -> bochi creates memo with URL and context
  -> [CLI later] Mode 5 surfaces: "📌した記事があるゆ。深掘りするゆ？"
```

### 2. Start Mobile / Finish Desktop
```
[Discord] User: "認証フローのUX改善案メモ: ステップ減らす、OAuth追加"
  -> bochi creates structured memo
  -> [CLI] User works on auth code, bochi surfaces memo
  -> User addresses memo during implementation
```

### 3. Desktop Preview
```
[CLI] bochi generates long topic output
  -> [Discord] bochi sends summary: "トピック作成したゆ: {title} — 詳細はCLIで 💫"
```

### 4. Voice Bridge
```
[Discord] User sends voice message (Discord built-in)
  -> Discord auto-transcribes
  -> bochi receives text, creates memo
  -> "音声メモ受け取ったゆ！📝"
```

## Output Formatting for Mobile

### Character Limits
- Newspaper article summary: max 50 chars
- Casual chat item: max 80 chars
- Memo confirmation: max 100 chars

1項目あたりの推奨文字数。セクション全体の上限はdiscord-ux-spec.md（300文字/セクション）に準拠。

### Visual Hierarchy
- Use bold for titles, not headers (headers take too much mobile space)
- Emoji as visual anchors (category markers)
- Line breaks between items (no tables on mobile)
- Max 5 items per section

### Discord-specific
- No code blocks for general content (hard to read on mobile)
- Links as inline markdown (clickable)
- Reactions as primary feedback mechanism
