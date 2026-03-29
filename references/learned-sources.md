# bochi Learned Sources

## Format
YYYY-MM-DD | Domain | URL | E-E-A-T Score | User Rating (1-5)

## How to Append
After Phase G positive feedback, update both:
1. This reference file (human-readable log):
```
YYYY-MM-DD | domain.com | https://... | 32/40 | 4
```
2. Runtime data (JSONL for programmatic access, Read→append→Write pattern):
`{"url":"...","domain":"...","eeat_score":32,"date":"...","rating":4}`
→ Read sources/verified.jsonl → 末尾に追加 → Write tool で書き出し

## Verified High-Quality Sources
2026-03-28 | note.com | (initial seed) | 30/40 | 4
2026-03-28 | lenny.substack.com | (initial seed) | 35/40 | 5
2026-03-28 | reforge.com | (initial seed) | 33/40 | 4

## Blacklisted Sources (low quality)
(none yet)
