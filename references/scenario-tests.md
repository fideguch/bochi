# Scenario Test Suite — bochi Manual QA (49 tests)

> Execute each test via Discord DM. Pass/Fail is binary.

## Mode 1: Idea (6 tests)

| ID | Category | Input | Expected Behavior | Pass Criteria |
|----|----------|-------|--------------------|---------------|
| M1-01 | 語尾ゆ | `AIエージェントの未来について考えてゆ` | All sentences end with ゆ throughout Phases A-E | Every sentence in reply ends with ゆ (spot-check 5+) |
| M1-02 | Phase D critique | `この記事について深掘りして https://example.com/article` | Phase D shows source quality check (信頼度, bias, 反論) | Critique section visible before final output |
| M1-03 | Source citation | Same as M1-02 | Sources appear as `[domain.com](https://...)` hyperlinks | Every citation is a clickable hyperlink with domain label |
| M1-04 | SCAMPER | `新しいSaaSのアイデアを一緒に考えて` | Phase B offers SCAMPER-based viewpoints (Substitute, Combine, etc.) | At least 3 SCAMPER perspectives named |
| M1-05 | File output | `レポートとしてファイル出力して` (after M1-04) | Attached file uses professional tone, no ゆ | File content has zero instances of 語尾ゆ |
| M1-06 | Index update | Complete full idea flow (Phases A-E) | `bochi-data/index.jsonl` gains a new entry | New line with timestamp and topic exists in index.jsonl |

## Mode 2: Newspaper (5 tests)

| ID | Category | Input | Expected Behavior | Pass Criteria |
|----|----------|-------|--------------------|---------------|
| M2-01 | Cache delivery | `朝刊` (with cache/newspaper-draft.md present) | Instant delivery from cache, no WebSearch | Response < 5s, no "searching" indicator |
| M2-02 | Seen exclusion | `新聞` (after reading previous edition) | Articles in seen.jsonl are not repeated | Zero overlap with previously seen article URLs |
| M2-03 | Cache empty fallback | `朝刊` (with empty/missing cache) | Falls back to live WebSearch | Response mentions searching or shows search activity |
| M2-04 | Category weights | `新聞` | Category distribution matches user-profile.yaml weights | Top categories align with configured weight order |
| M2-05 | PDCA reflection | `新聞` (3rd+ delivery) | PDCA reflection section appears | Reflection on previous editions visible in output |

## Mode 3: Casual Chat (3 tests)

| ID | Category | Input | Expected Behavior | Pass Criteria |
|----|----------|-------|--------------------|---------------|
| M3-01 | Related topics | `最近面白いことあった？` | Surfaces topics from cache/memory | At least 1 topic references prior conversation context |
| M3-02 | Parallel stream | `おすすめ` | Serendipity content offered alongside main chat | A tangential but interesting topic is introduced |
| M3-03 | No escalation | `今日暑いね` | Stays in casual mode, does not force Mode 1/2 | No idea-generation phases or structured output triggered |

## Mode 6: Google Brief (4 tests)

| ID | Category | Input | Expected Behavior | Pass Criteria |
|----|----------|-------|--------------------|---------------|
| M6-01 | Calendar instant | `今日の予定` (with cache present) | Calendar events from cache, instant response | Response < 3s with today's events listed |
| M6-02 | Gmail top 10 | `メール確認して` | Displays top 10 emails with sender, subject, date | Exactly 10 or fewer emails listed in structured format |
| M6-03 | Stale revalidate | `今日の予定` (cache > 30min old) | Returns stale data immediately, revalidates in background | Instant response; subsequent call shows fresh data |
| M6-04 | gog unavailable | `今日の予定` (Lightsail gog not running) | Graceful error: explains service unavailable | No stack trace; user-friendly message displayed |

## Mode 7: PM Tools (4 tests)

| ID | Category | Input | Expected Behavior | Pass Criteria |
|----|----------|-------|--------------------|---------------|
| M7-01 | Issue list | `Linearのイシュー一覧見せて` | Delegates to PM skill, returns issue list | Issues displayed with title, status, assignee |
| M7-02 | Issue create | `「ログイン画面のバグ修正」でイシュー作って` | Confirmation prompt before creation | User asked to confirm before issue is created |
| M7-03 | Skill missing | `Jiraのチケット見せて` (Jira MCP not installed) | Clear error: skill/MCP not available | Message names the missing tool and suggests next step |
| M7-04 | Cross-mode handoff | `このアイデアをイシューにして` (after Mode 1 session) | Mode 1 context carried into issue creation | Issue body contains idea summary from prior Mode 1 output |

## Mode 4: Memory (4 tests)

| ID | Category | Input | Expected Behavior | Pass Criteria |
|----|----------|-------|--------------------|---------------|
| M4-01 | Memory recall | `前に話したSaaSについて覚えてる？` | Searches index.jsonl, shows Active/Warm results | Search results displayed with freshness status; 語尾ゆ |
| M4-02 | Memory list | `覚えてること教えて` | Category x Freshness overview table | Structured table with categories and counts |
| M4-03 | Archive suggest | `記憶整理` | Proposes archive candidates (90+ days unreferenced) | Items with last_referenced > 90 days listed |
| M4-04 | Restore from archive | `アーカイブから〇〇戻して` | Restores entry: freshness → active, file moved | File moved from archive/ to original dir; index updated |

## Mode 5: Companion (3 tests)

| ID | Category | Input | Expected Behavior | Pass Criteria |
|----|----------|-------|--------------------|---------------|
| M5-01 | Memo surface | `メモある？` (during other skill work) | Shows related memos from bochi-data | Open memos displayed with title and excerpt |
| M5-02 | Auto-surface | Working on topic with >=2 tag overlaps in memos | Proactive suggestion: 「💡 関連メモがあるゆ」 | Auto-surface triggers without user asking |
| M5-03 | Memo resolution | `対応したゆ` (after M5-01) | Updates memo status to addressed | Memo file gets Resolution section; index status updated |

## Discord UX (5 tests)

| ID | Category | Input | Expected Behavior | Pass Criteria |
|----|----------|-------|--------------------|---------------|
| UX-01 | Section split | Any input producing long output | Messages split at section boundaries, each < 2000 chars | No message exceeds Discord limit; splits at headers |
| UX-02 | React immediate | Any input | Emoji reaction appears before text reply | Reaction timestamp precedes first reply timestamp |
| UX-03 | Progressive disclosure | `AIの歴史について教えて` | Summary first via edit, then detailed reply as new message | Edit updates visible, then a new message notification |
| UX-04 | Conclusion first | `SaaSの価格戦略を考えて` | First paragraph is the conclusion/recommendation | Opening sentence is actionable, not background context |
| UX-05 | Approved emoji | Any input | Only approved emoji set used | No 👋🙂😊❤️👍😄 in any reaction or text |

## Response Speed (3 tests)

| ID | Category | Input | Expected Behavior | Pass Criteria |
|----|----------|-------|--------------------|---------------|
| RS-01 | React latency | Any input | Emoji reaction within 2 seconds | Stopwatch confirms reaction ≤ 2s from send |
| RS-02 | Parallel search | `AIエージェントの最新動向を調べて` | Multiple WebSearch queries fire concurrently | 3 searches visible in logs or response time < sequential estimate |
| RS-03 | Progressive timing | `来週のマーケティング戦略を考えて` | First substantive message arrives within 10s via Progressive Disclosure | Stopwatch: placeholder or conclusion within 10s of send |

## Error Handling (3 tests)

| ID | Category | Input | Expected Behavior | Pass Criteria |
|----|----------|-------|--------------------|---------------|
| EH-01 | MCP failure | Trigger with MCP server stopped | Graceful message explaining temporary issue | No raw error/stack trace; user-friendly fallback message |
| EH-02 | Session restart | Send message after 6h+ idle | Session recovers, responds normally with ゆ | Valid response with 語尾ゆ; no crash or silence |
| EH-03 | Missing bochi-data | Delete bochi-data/ then send any message | Auto-creates directory or explains setup needed | No crash; either auto-recovery or clear instruction |

## Character (2 tests)

| ID | Category | Input | Expected Behavior | Pass Criteria |
|----|----------|-------|--------------------|---------------|
| CH-01 | 語尾ゆ consistency | Send 3 varied messages, collect 10+ sentences total | Every sentence ends with ゆ | 10/10 sentences end with ゆ |
| CH-02 | Banned emoji | Review all reactions and text across 5+ messages | No banned emoji (👋🙂😊❤️👍😄) | Zero instances of banned emoji found |

## Edge Case Coverage (2 tests)

| ID | Category | Input | Expected Behavior | Pass Criteria |
|----|----------|-------|--------------------|---------------|
| EC-01 | Archive dir missing | `記憶整理` (with archive/ deleted) | bochi auto-creates archive/ and proceeds | No error; archive/ exists after operation |
| EC-02 | Orphaned index entry | Add fake entry to index.jsonl pointing to nonexistent file | Reports "ファイルが見つからないゆ" | No crash; user-friendly message; orphan logged |

## CLAUDE.md Verification (5 tests)

| ID | Category | Input | Expected Behavior | Pass Criteria |
|----|----------|-------|--------------------|---------------|
| CM-01 | Post-deploy ゆ | `デプロイ後の最初のテストゆ` | 語尾ゆ maintained after fresh deploy | All sentences end with ゆ |
| CM-02 | No gog CLI | `今日の予定` | Uses cache files only, never attempts gog CLI directly | No gog subprocess or CLI call in logs |
| CM-03 | Phase D active | `このトピックを深掘りして: リモートワーク` | Phase D critique executes with source evaluation | Critique section with reliability/bias assessment visible |
| CM-04 | 6h restart quality | Send message after 6h+ gap | Same output quality as fresh session | Response structure, ゆ, and depth match fresh session |
| CM-05 | No browser/GUI | `このサイトを開いて https://example.com` | Does not attempt browser launch or GUI action | No Playwright/puppeteer/open commands; uses WebSearch or explains limitation |
