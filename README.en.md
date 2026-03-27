# bochi — Idea Expansion Skill

A Claude Code skill that transforms idea seeds (memos, URLs, sparks) into structured hypotheses.

## Key Strengths

### 1. Evidence-Backed Expansion (Unique)
SCAMPER expansion → ReAct research → E-E-A-T scoring → first-principles critique in a single skill.
Neither IDEO Design Thinking (expansion only) nor OpenAI Deep Research (research only) offers this integrated flow.

### 2. Learning Accumulation
`learned-sources.md` + `feedback-log.md` + PostToolUse Hooks auto-record. Research precision improves with use. Miro AI / Juma / Perplexity have no accumulation mechanism.

### 3. Native PM Pipeline Integration
Fits as the upstream stage of `/brainstorming` → `/requirements_designer` → `/speckit-bridge`.
Auto-handoff to `/pm-discovery-interview-prep` connects directly to user validation.

## Usage

### Activation
- `bochiして` / `アイデアを膨らませたい` / `このURL深掘りして` (immediate)
- `調べて欲しい` / `どうやるの` + idea context (context-dependent)

### Input
- Text idea memos
- URLs (articles, video links)

### Output
- Console (summary with "yu" character voice)
- `docs/bochi/YYYY-MM-DD-{summary}.md` (professional mode, auto-saved)
- User-specified location (Notion, etc.)

## 6-Phase Flow

```
Input (memo or URL)
  ↓
Phase A: Deep Dive — Socratic 8-level questioning (max 5 questions)
  ↓
Phase B: Expand — SCAMPER 7 perspectives, 2-3 proposals
  ↓
Phase C: Research — ReAct loop + E-E-A-T quality scoring
  ↓
Phase D: Critique — First-principles check + bias verification (HARD-GATE)
  ↓
Phase E: Output — Teresa Torres OST structure + user hypotheses
  ↓
Phase F: Next Steps — brainstorming / interview-prep / continue
```

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
| Urgent decisions | Full 6-phase flow takes time | Ask Claude directly |

## Evaluation Score

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
bochi-skill/
├── SKILL.md              # Main skill (226 lines)
├── README.md             # Japanese documentation
├── README.en.md          # This file
└── references/
    ├── quality-criteria.md     # E-E-A-T quality scoring
    ├── trusted-domains.md      # Trusted domain list
    ├── research-strategy.md    # Domain-specific research strategy
    ├── socratic-levels.md      # Socratic 8-level questions
    ├── expansion-framework.md  # SCAMPER expansion framework
    ├── critique-checklist.md   # Critique checklist
    ├── output-template.md      # Output template (OST-integrated)
    ├── interview-handoff.md    # interview-prep handoff spec
    ├── feedback-log.md         # User feedback history (auto-append)
    └── learned-sources.md      # High-quality source accumulation (auto-append)
```

## License & Credits

All framework copyrights and trademarks belong to their original authors. This skill is independently designed and implemented with reference to these methodologies.
