# Mode 4: Memory Management Spec

## Overview

蓄積した記憶（topics, memos, sources）の検索・整理・アーカイブを管理するゆ。

## Trigger

「記憶整理」「覚えてること教えて」「アーカイブ」「何覚えてる？」

## Sub-commands

### 4a: Search (検索)

Trigger: 「〇〇について覚えてる？」「前に話した〇〇」

```
[1] Read user query (natural language)
[2] grep index.jsonl for matches in: title, summary, tags
[3] Apply optional parameters:
    - limit: number of results to return (default: 5, max: 30)
    - sort: "newest_first" (default) | "oldest_first" | "relevance"
    - tag_filter: restrict results to entries matching specific tag(s)
[4] Present results with title + summary + date
[5] User selects → send file as Discord attachment
```

Parameter examples:
```bash
# Default search (5 results, newest first)
grep -i "keyword" ~/.claude/bochi-data/index.jsonl | \
  python3 -c "import sys,json; lines=sys.stdin.readlines(); entries=[json.loads(l) for l in lines]; entries.sort(key=lambda x: x.get('date',''), reverse=True); [print(json.dumps(e)) for e in entries[:5]]"

# Tag-filtered search (e.g., "Vibe Coding" tag, up to 30 results)
grep '"Vibe Coding"' ~/.claude/bochi-data/index.jsonl | \
  python3 -c "import sys,json; lines=sys.stdin.readlines(); entries=[json.loads(l) for l in lines]; entries.sort(key=lambda x: x.get('date',''), reverse=True); [print(json.dumps(e)) for e in entries[:30]]"

# Multi-tag filter (entries with BOTH tags)
grep '"Vibe Coding"' ~/.claude/bochi-data/index.jsonl | grep '"PDCA"' | \
  python3 -c "import sys,json; lines=sys.stdin.readlines(); entries=[json.loads(l) for l in lines]; entries.sort(key=lambda x: x.get('date',''), reverse=True); [print(json.dumps(e)) for e in entries[:30]]"
```

Note: When called from forge_ace PM-Admin, use tag_filter + sort: newest_first + limit: 30 to internalize Admin's judgment patterns.

Output:
```
あったゆ 💫

1. **{title}** — {summary} ({date})
2. **{title}** — {summary} ({date})
3. ...

見たいのあるゆ？ファイル送るゆ 📎
```

When user selects:
```
reply(text="これゆ ✨", files=["$HOME/.claude/bochi-data/{path}"])
```

### 4b: Review (一覧)

Trigger: 「覚えてること教えて」「記憶一覧」

```
[1] Read index.jsonl
[2] Group by category and freshness
[3] Show counts and recent items per category
```

Output:
```
bochiの記憶状況ゆ 📚

| Category | Active | Warm | Archive | Total |
|----------|--------|------|---------|-------|
| PM       | 5      | 2    | 1       | 8     |
| AI       | 3      | 1    | 0       | 4     |
| ...      |        |      |         |       |

最近のトピック:
1. {title} ({date}) — {category}
2. ...

整理したいカテゴリがあったら教えてゆ！
```

### 4c: Archive (アーカイブ提案)

Trigger: 「記憶整理」「アーカイブ」or monthly auto-suggestion

```
[1] Find Warm items (90-180 days, no recent references)
[2] Present candidates for archiving
[3] User approves -> update freshness in index.jsonl
[4] Move files to archive/ directory
```

Output:
```
アーカイブ候補があるゆ 📦

以下のN件、最近参照されてないゆ:
1. **{title}** ({date}) — 最終参照: {last_ref_date}
2. ...

全部OKなら「全部OK」、個別に残すなら番号教えてゆ！
```

Archive process (uses `Bash` tool for file operations):
1. `mv ~/.claude/bochi-data/{topics|memos}/OLD.md ~/.claude/bochi-data/archive/`
2. Edit index.jsonl entry: `freshness: "active"|"warm"` -> `"archive"`, update `"path"` to `archive/OLD.md`
3. Log in reflections (PDCA)

### 4d: Restore (復元)

Trigger: 「アーカイブから〇〇戻して」

```
[1] grep index.jsonl for archived items matching keyword
[2] Present matches
[3] User selects -> restore freshness to "active"
[4] Move file back from archive/
```

## Auto-suggestions

### Weekly (Monday, during PDCA)
- Demote Active items >90 days without reference to Warm (silent, no user prompt)

### Monthly (1st of month, during PDCA)
- Propose Warm->Archive for items >180 days
- Show in PDCA reflection, not as standalone message

## Never Delete

Archive is the final state. Files in archive/ are never automatically deleted.
User can manually delete if they want, but bochi will never suggest deletion.

## Edge Cases

- **Search keyword matches zero entries** → 「その話題はまだ覚えてないゆ。調べるゆ？💫」+ Mode 1提案
- **index.jsonl corrupted** → self-healing-spec JSONL Recovery手順に委譲
- **archive/ directory missing** → 移動操作前に自動作成
- **Restore target file already exists** → -restored サフィックスで重複回避、コンフリクトをログ
- **Orphaned index entry (file missing)** → 「ファイルが見つからないゆ」と報告、エラーログに記録
- **Archive candidates >20件** → 上位10件（最古順）を表示、「全部見るゆ？」で展開
