# bochi v2.3 — PM Companion

A Claude Code skill that transforms idea seeds (memos, URLs, sparks) into structured hypotheses and supports daily PM activities as a thinking companion.

## Product Vision

bochi is a "thinking hub accessible from anywhere" for PMs.

1. **Thinking Hub**: Access the same memory from Discord DM, Mac CLI, or anywhere
2. **S3 Data Hub**: bochi-data → S3 → all environments synced. Data is always current
3. **Proactive Memo Save**: bochi proposes saving valuable conversations without waiting for "save this"

## What's New in v2.3

- **Thinking Hub**: Ideas born in Discord DM auto-propagate to Mac CLI via S3
- **Mode 1 Spec Extraction**: Phases A-G moved to `references/idea-expansion-spec.md` (DRY)
- **Proactive Memo Save**: 4 trigger conditions added to Intake Gate
- **Edge Cases**: Added to socratic-levels, expansion-framework, output-template, self-healing
- **CI/CD**: markdownlint + reference integrity + test count verification
- **DX Files**: CONTRIBUTING.md, CHANGELOG.md, examples/mode-1-walkthrough.md
- **47 Scenario Tests**: 7 new Mode 4/5 tests (all 7 modes covered)

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
| 3 Casual Chat | `雑談`, `何か面白い？` | Related updates + serendipity |
| 4 Memory | `記憶整理`, `覚えてること教えて` | Search, review, archive |
| 5 Companion | `メモある？`, `前に話したやつ` | Surface relevant memos during work |
| 6 Google Brief | `今日の予定`, `メール確認` | Calendar + Gmail from cache |
| 7 PM Tools | `イシュー一覧`, `チケット作って` | Linear/GitHub Issue delegation |

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

## Quality Score (Rubric Self-Assessment)

> Based on GAFA Rubric v2 (5 dimensions x 20 points = 100 max).

| Dimension | v2.2 | v2.3 | Notes |
|-----------|------|------|-------|
| Maintainability | 15 | 16 | Mode 1 extraction + DRY. References table duplication remains |
| Reliability | 15 | 15 | Major mode Edge Cases added. Full spec coverage pending |
| Testing & CI | 10 | 14 | CI added + 47 tests. Mode 4/5 tests thin |
| DX | 16 | 17 | CONTRIBUTING + CHANGELOG + examples all present |
| Product | 16 | 16 | Vision added. S3 scripts not yet implemented |
| **Total** | **72** | **78** | **Grade C+ → targeting B+(87)** |

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
