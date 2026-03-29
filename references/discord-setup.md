# Discord Integration Setup & Spec

## Prerequisites

- Claude Code v2.1.80+
- Bun runtime (`curl -fsSL https://bun.sh/install | bash`)
- Discord Developer Portal account

## Setup Steps

### 1. Discord Bot Creation

```
Discord Developer Portal (discord.com/developers/applications)
  -> New Application -> name: "bochi"
  -> Bot section -> Reset Token -> copy token
  -> Enable "Message Content Intent" (Privileged Gateway Intents)
```

### 2. Bot Permissions (OAuth2 > URL Generator)

Scope: `bot`

Required permissions:
- View Channels
- Send Messages
- Send Messages in Threads
- Read Message History
- Attach Files
- Add Reactions

### 3. Install Plugin

```bash
# In Claude Code
/plugin install discord@claude-plugins-official

# Configure token
/discord:configure <bot-token>
# Saves to ~/.claude/channels/discord/.env
```

### 4. Launch with Channels

```bash
claude --channels plugin:discord@claude-plugins-official
```

### 5. Pair Owner Account

```
[Discord] DM the bot -> receives 5-letter pairing code
[CLI]     /discord:access pair <code>
[CLI]     /discord:access policy allowlist
```

Access config stored at: `~/.claude/channels/discord/access.json`

## Architecture

```
Discord User (DM or guild mention)
  |
  [Discord API]
  |
  [Discord MCP Plugin] (local stdio subprocess)
  |
  [Claude Code Session] (same context as CLI)
  |
  [bochi SKILL.md] (Mode Router)
  |
  [reply tool] -> Discord response
```

Key: Discord and CLI share the SAME session and context.
No sync needed - they are one process.

## Message Format (incoming)

```xml
<channel source="discord" user_id="..." channel_id="..." thread_id="..." message_id="...">
User's message text here
</channel>
```

## bochi-specific Instructions

These are enforced via SKILL.md Owner-Only Protocol, not MCP server config:

1. Check `user_id` against paired owner (from access.json)
2. Owner messages: full interaction + learn + memorize
3. Non-owner messages: respond with read-only knowledge, no memory writes
4. All memo/topic writes: tag `"channel":"discord"` in index.jsonl
5. Use `reply` tool to respond (pass `chat_id` from channel tag)
6. Newspaper: compact format for mobile readability

## Available Discord Tools

| Tool | Purpose | bochi Usage |
|------|---------|-------------|
| `reply` | Send message back | All responses |
| `react` | Add emoji reaction | Feedback acknowledgment |
| `edit_message` | Edit bot's message | Update newspaper after PDCA |
| `fetch_messages` | Get channel history | Context recovery on restart |
| `download_attachment` | Download to local | User shares images/files |

## Permission Relay

When Claude needs tool approval during Discord-triggered work:

```
Claude needs permission
  |
  [Terminal dialog] + [Discord message with request_id]
  |
  User replies in Discord: "yes abcde" or "no abcde"
  |
  First answer (terminal OR Discord) wins
```

Format: `/^(y|yes|n|no)\s+([a-km-z]{5})$/i`

This enables mobile permission approval while away from terminal.

## Newspaper via Discord

Format optimized for mobile (Discord Embed style):

```
おはようゆ！今日の新聞ゆ 💗

**PM / Product** ✨
1. [タイトル](URL) (32) — 要約
2. [タイトル](URL) (29) — 要約

**AI / ML** 🌟
1. ...

気になったらリアクションしてゆ！
リアクション1個で続き、2個以上で「もっと！」ゆ 💫
```

## Memo Creation from Discord

```
[Discord] User: "req-designerのフェーズ3、質問数減らしたい"
  |
  bochi detects memo-worthy content (Intake Gate: high importance)
  |
  Write tool: ~/bochi-data/memos/YYYY-MM-DD-req-designer-phase3.md
  |
  Read→append→Write: index.jsonl に channel:"discord" で追記
  |
  reply tool: "メモったゆ！📝 CLIで作業するときに教えるゆ 💫"
```

## Multiple Bot Instances

Use `DISCORD_STATE_DIR` for separate configurations:

```bash
DISCORD_STATE_DIR=~/.claude/channels/discord-bochi claude --channels ...
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Bot not responding | Check `claude --channels` is running |
| Token error | Re-run `/discord:configure <token>` |
| Messages lost | Session must stay running; restart queues messages |
| Permission stuck | Approve at terminal or send `yes <id>` in Discord |
| Non-owner writing | Check access.json allowlist policy |
