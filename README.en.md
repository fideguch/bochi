# bochi v2.0 — PM Companion

A Claude Code skill that transforms idea seeds (memos, URLs, sparks) into structured hypotheses and supports daily PM activities as a thinking companion.

## What's New in v2.0

- **5-Mode Router**: Idea expansion + Newspaper + Casual chat + Memory management + Companion
- **Context Signal Triggers**: Naturally responds to abstract thinking requests like "think through", "help me think"
- **Persistent Data Layer**: JSONL index + 3-layer memory management at `~/.claude/bochi-data/`
- **Pipeline Position**: Explicit upstream/downstream: bochi → brainstorming → requirements_designer
- **Discord Integration**: Idea memos and newspaper via mobile through Channels
- **Cross-Context Memory**: Auto-share memos between Discord and CLI

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

## 5 Modes

| Mode | Trigger | Purpose |
|------|---------|---------|
| 1 Idea | `bochiして`, URL, thinking verbs + context | Deep dive + expand + research |
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

## Design Target Scores

> The following are self-assessed design target scores, not third-party evaluations.

| Category | Score |
|----------|-------|
| GAFA 6-Axis Total | 57/60 (95.0%) |
| Ideation Power | 8/10 |
| Research Power | 8/10 |
| Expansion Power | 8/10 |
| Refinement Power | 9/10 |
| **Overall** | **90/100** |

## Folder Structure

```
bochi/
├── SKILL.md                        # Main skill (433 lines, 5-mode router + context signals)
├── README.md                       # Japanese documentation
├── README.en.md                    # This file
└── references/
    ├── quality-criteria.md         # E-E-A-T quality scoring
    ├── trusted-domains.md          # Trusted domain list
    ├── research-strategy.md        # Domain-specific research strategy
    ├── socratic-levels.md          # Socratic 8-level questions
    ├── expansion-framework.md      # SCAMPER expansion framework
    ├── critique-checklist.md       # Critique checklist
    ├── output-template.md          # Output template (OST-integrated)
    ├── interview-handoff.md        # interview-prep handoff spec
    ├── feedback-log.md             # User feedback history (auto-append)
    ├── learned-sources.md          # High-quality source accumulation
    ├── newspaper-spec.md           # [v2.0] Newspaper mode spec
    ├── pdca-spec.md                # [v2.0] PDCA daily reflection spec
    ├── casual-chat-spec.md         # [v2.0] Casual chat mode spec
    ├── memory-spec.md              # [v2.0] Memory management spec
    ├── companion-spec.md           # [v2.0] Companion mode spec
    ├── discord-setup.md            # [v2.0] Discord integration guide
    ├── skill-tracking-spec.md      # [v2.0] Skill usage tracking spec
    └── mobile-first-spec.md        # [v2.0] Mobile-first UX spec
```

## License & Credits

All framework copyrights and trademarks belong to their original authors. This skill is independently designed and implemented with reference to these methodologies.
