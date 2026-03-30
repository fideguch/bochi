# bochi v2.4 — PM Companion

A Claude Code skill that transforms idea seeds (memos, URLs, sparks) into structured hypotheses and supports daily PM activities as a thinking companion.

## Product Vision

bochi is a "thinking hub accessible from anywhere" for PMs.

1. **Thinking Hub**: Access the same memory from Discord DM, Mac CLI, or anywhere
2. **S3 Data Hub**: bochi-data → S3 → all environments synced. Data is always current
3. **Proactive Memo Save**: bochi proposes saving valuable conversations without waiting for "save this"

## What's New in v2.4

- **Edge Cases Complete**: All 14 spec files now have Edge Cases sections (v2.3: 5/14 → 14/14)
- **SKILL.md DRY Complete**: Mode 2-7 duplicate table removed (329 → 350 lines)
- **Session Continuity Protocol**: 6h restart recovery with fetch_messages, profile preload, open memo surfacing
- **49 Scenario Tests**: 2 Edge Case tests added + RS-03 differentiated (47 → 49)

<details>
<summary>v2.0-v2.3 changes</summary>

### v2.3 — Thinking Hub + Quality

- Mode 1 spec extraction, proactive memo save, CI/CD, DX files, 47 tests

### v2.2 — Lightsail + Mode 6/7

- deploy/lightsail-claude.md, Mode 6 Google Brief, Mode 7 PM Tools, 40 tests

### v2.1 — Speed + Signals

- response-speed-spec (7 techniques), discord-ux-spec, seen-tracking cache

### v2.0 — Initial Release

- 5-Mode Router, Context Signal Triggers, Persistent Data Layer, Discord Integration
</details>

## Key Strengths

### 1. Evidence-Backed Expansion (Unique)
SCAMPER expansion → ReAct research → E-E-A-T scoring → first-principles critique in a single skill.
Neither IDEO Design Thinking (expansion only) nor OpenAI Deep Research (research only) offers this integrated flow.

### 2. Learning Accumulation
`learned-sources.md` + `feedback-log.md` + PDCA reflections + PostToolUse Hooks auto-record. Research precision improves with use. Miro AI / Juma / Perplexity have no accumulation mechanism.

> The PostToolUse Hook (`bochi-feedback-capture.sh`) is included in [my_dotfiles](https://github.com/fideguch/my_dotfiles) under `claude/scripts/hooks/` and symlinked to `~/.claude/scripts/hooks/` by `set_up.sh`.

### 3. Native PM Pipeline Integration
Fits as the upstream stage (thought expansion) of `/brainstorming` (design exploration) → `/requirements_designer` → `/speckit-bridge`.
Auto-handoff to `/pm-discovery-interview-prep` connects directly to user validation.

### 4. Mobile-First PM Journey
Morning newspaper → commute memos → meeting-gap casual chat → evening memory review.

## 7 Modes

| Mode | Trigger | Purpose |
|------|---------|---------|
| 1 Idea | `bochiして`, URL, thinking verbs + context | Deep dive + expand + research |
| 2 Newspaper | `新聞`, `朝刊`, cron 08:00 JST | Daily curated news by interest |
| 3 Casual Chat | `おすすめ`, `何か面白い？` | Related updates + serendipity |
| 4 Memory | `記憶整理`, `覚えてること教えて` | Search, review, archive |
| 5 Companion | `メモある？`, `前に話したやつ` | Surface relevant memos during work |
| 6 Google Brief | `今日の予定`, `メール確認` | Calendar + Gmail from cache |
| 7 PM Tools | `イシュー一覧`, `チケット作って` | Linear/GitHub Issue delegation |

## Quick Start

```bash
# Install
cd ~/.claude/skills && git clone <repo-url> bochi

# Data directory is created on first use at ~/.claude/bochi-data/

# Basic usage — say: "bochiして" or "新聞" or "おすすめ"

# Discord setup (optional) — see references/discord-setup.md
```

## Mode 1: Idea Expansion (7-Phase Flow)

```
Input (memo or URL)
  → Phase A: Deep Dive — Socratic 8-level questioning (max 5 questions)
  → Phase B: Expand — SCAMPER 7 perspectives, 2-3 proposals
  → Phase C: Research — ReAct loop + E-E-A-T quality scoring
  → Phase D: Critique — First-principles check + bias verification (HARD-GATE)
  → Phase E: Output — Teresa Torres OST structure + user hypotheses
  → Phase F: Next Steps — brainstorming / interview-prep / continue
  → Phase G: Learning — feedback → profile update
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
│   ├── trending/*.jsonl     # Category trending article pool
│   ├── meta.json            # Cache TTL management
│   ├── calendar.md          # Google Calendar cache (S3 sync)
│   └── gmail.md             # Gmail top 10 cache (S3 sync)
├── errors/                  # Error logs + diagnosis reports
│   └── known-patterns.jsonl # Known error pattern DB
└── archive/                 # Archived old data (never deleted)
```

### 3-Layer Freshness

| Layer | Condition | Access |
|-------|-----------|--------|
| Active | <90 days or recently referenced | Auto-surface |
| Warm | 90-180 days, no references | Explicit search only |
| Archive | >180 days or user-approved | Archive search only |

## Integrated Frameworks

| Framework | Phase | Origin |
|-----------|-------|--------|
| Socratic Method 8 Levels | Phase A | Socrates / Pedagogy |
| SCAMPER | Phase B | Bob Eberle (1971) |
| ReAct Pattern | Phase C | Yao et al. (2022) |
| E-E-A-T | Phase C/D | Google Search Quality Guidelines |
| First-Principles Thinking | Phase D | Jensen Huang / NVIDIA |
| Opportunity Solution Tree | Phase E | Teresa Torres |
| Mom Test / JTBD | Phase F (handoff) | Rob Fitzpatrick / Clayton Christensen |

## When NOT to Use

| Use Case | Reason | Alternative |
|----------|--------|-------------|
| Team brainstorming | Designed for individual PMs | Miro AI, FigJam AI |
| Exhaustive source survey | 3-5 searches have limits | OpenAI Deep Research |
| Requirements already clear | Expansion phase unnecessary | /requirements_designer |
| Quantitative data analysis | Qualitative idea expansion only | /pm-data-analysis |
| Bug fixes for existing product | Not a new idea | /brainstorming |
| Urgent decisions | Full flow takes time | Ask Claude directly |

## Quality Score (Rubric Self-Assessment)

> Based on GAFA Rubric v2 (5 dimensions x 20 points = 100 max).

| Dimension | v2.3 | v2.4 | Notes |
|-----------|------|------|-------|
| Maintainability | 16 | 17 | SKILL.md 350 lines. Mode 2-7 duplicate table removed |
| Reliability | 15 | 17 | Edge Cases 14/14 specs complete. All fallbacks explicit |
| Testing & CI | 14 | 15 | 49 tests. Edge Case tests added. RS-03 differentiated |
| DX | 17 | 18 | Quick Start improved. Session Continuity Protocol added |
| Product | 16 | 17 | S3 scripts verified present. Vision + proactive save + S3 loop documented |
| **Total** | **78** | **84** | **Grade B — practical ceiling without structural changes** |

## Architecture

### Owner-Only Learning

Owner (paired user) gets full interaction + learn + memorize. Others get read-only responses.

### Discord UX

- React-first (HARD-GATE): reaction before any text
- Section splitting: each message <=300 chars, reply-reference chains
- Progressive Disclosure: react -> placeholder -> edit -> final reply (push notification)

### External Dependencies

| Dependency | Required | Purpose |
|------------|----------|---------|
| Discord MCP Plugin | Optional | Discord DM integration |
| Context7 MCP | Optional | Library docs in tech research |
| gog CLI | Optional | Google Calendar/Gmail sync (Mac only) |
| github_project_manager skill | Optional | Mode 7 GitHub Issue delegation |
| Figma MCP | Optional | FigJam diagram generation |

## Folder Structure

```
bochi/
├── SKILL.md                        # Main skill (350 lines, 7-mode router)
├── README.md                       # Japanese documentation
├── README.en.md                    # This file
├── CONTRIBUTING.md                 # [v2.3] Contribution guide
├── CHANGELOG.md                    # [v2.3] Version history
├── .markdownlint.json              # [v2.3] Lint config
├── .github/workflows/quality.yml   # [v2.3] CI/CD
├── deploy/
│   ├── lightsail-claude.md         # [v2.2] Lightsail CLAUDE.md + [v2.5] File Protection, Quality Standards
│   ├── protect-readonly.sh         # [v2.5] PreToolUse hook: blocks writes to protected files
│   └── restart-bot.sh              # [v2.5] Safe deploy script (6-point smoke test)
├── tests/                          # [v2.5] Infrastructure, data, Discord E2E tests
│   ├── infra-check.sh, data-integrity.sh, s3-sync-test.sh
│   ├── discord-e2e.sh, run-all.sh
│   └── ...                         # 5 shell scripts total
├── examples/
│   └── mode-1-walkthrough.md       # [v2.3] Mode 1 E2E walkthrough
└── references/                     # 27 files (specs + data, on-demand load)
    ├── idea-expansion-spec.md      # [v2.3] Mode 1 Phases A-G
    ├── newspaper-spec.md           # Mode 2
    ├── casual-chat-spec.md         # Mode 3
    ├── memory-spec.md              # Mode 4
    ├── companion-spec.md           # Mode 5 + S3 sync loop
    ├── google-brief-spec.md        # [v2.2] Mode 6
    ├── pm-tools-bridge-spec.md     # [v2.2] Mode 7
    ├── discord-ux-spec.md          # [v2.1] Discord UX
    ├── response-speed-spec.md      # [v2.1] Speed optimization (7 techniques)
    ├── self-healing-spec.md        # Self-healing + JSONL recovery
    ├── scenario-tests.md           # [v2.4] 49 scenario tests
    └── ...                         # 15 more spec/data files
```

## License & Credits

All framework copyrights and trademarks belong to their original authors. This skill is independently designed and implemented with reference to these methodologies.
