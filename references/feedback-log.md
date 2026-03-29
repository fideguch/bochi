# bochi Feedback Log

## Format
YYYY-MM-DD | Type (positive/negative/suggestion) | Mode/Phase | Content

## How to Append
After Phase G or explicit user feedback, append to this reference file:
```bash
echo 'YYYY-MM-DD | positive | Mode 1 Phase C | description' >> ~/.claude/skills/bochi/references/feedback-log.md
```
Note: This file is the reference spec. Runtime feedback data is also logged to `~/bochi-data/stats/usage.jsonl`.

## Log
2026-03-28 | positive | Mode 1 Phase C | E-E-A-T scoring identified high-quality note.com source (32/40)
2026-03-28 | suggestion | audit | spec contradictions found — added cross-spec consistency check to workflow
