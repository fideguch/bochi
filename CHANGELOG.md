# Changelog

All notable changes to bochi are documented here.

## v2.4 (2026-03-28) — Edge Case Completeness + DRY

### Added

- Edge Cases sections for all 14 spec files (9 new: companion, discord-ux, error-reporting, memory, mobile-first, pdca, response-speed, self-healing, skill-tracking)
- Session Continuity Protocol in lightsail-claude.md (6h restart recovery with fetch_messages, profile preload, open memo surfacing)
- EC-01/EC-02 edge case scenario tests (archive dir missing, orphaned index entry)

### Changed

- SKILL.md: Removed duplicate "Mode 2-7: Spec References" table (DRY, ~329 to ~313 lines)
- RS-03 scenario test: "Conclusion first" differentiated to "Progressive timing"
- CI threshold: 47 → 49 tests
- Scenario test suite: 47 → 49 tests

## v2.3 (2026-03-28) — Thinking Hub + Quality

### Added

- Product Vision section in SKILL.md
- `references/idea-expansion-spec.md` (Mode 1 Phases A-G extracted)
- Discord Proactive Save rules in Intake Gate
- Discord-to-S3-to-CLI feedback loop in companion-spec
- Edge Cases for socratic-levels, expansion-framework, output-template
- JSONL Recovery procedure in self-healing-spec
- Mode 4/5 scenario tests (7 new, total 47)
- CI/CD: `.github/workflows/quality.yml` + `.markdownlint.json`
- `CONTRIBUTING.md`, `CHANGELOG.md`, `examples/mode-1-walkthrough.md`
- Deployment Checklist in lightsail-claude.md

### Changed

- SKILL.md: Mode 1 inlined spec replaced with reference link (DRY)
- SKILL.md: Discord Output Rules simplified to reference links (DRY)
- SKILL.md: Feedback Signal table replaced with reference link (DRY)
- SKILL.md: ~444 lines reduced to ~329 lines

## v2.2 (2026-03-28) — Lightsail + Mode 6/7

### Added

- `deploy/lightsail-claude.md` for server-specific CLAUDE.md
- Mode 6: Google Brief (`references/google-brief-spec.md`)
- Mode 7: PM Tools Bridge (`references/pm-tools-bridge-spec.md`)
- 40 scenario tests in `references/scenario-tests.md`

### Fixed

- E-E-A-T boundary clarification (28/40 threshold)
- Critique specificity improvements
- feedback-log and learned-sources format definitions
- Mobile-first, response-speed, discord-ux character count alignment

## v2.1 (2026-03-28) — Speed + Signals

### Added

- `references/response-speed-spec.md` (7 speed techniques)
- `references/discord-ux-spec.md` (section splitting, reactions, feedback)
- Seen-tracking cache (`seen.jsonl`)

### Changed

- Discord output: character-cut replaced with section-based splitting

## v2.0 (2026-03-27) — Initial Release

### Added

- 5 modes: Idea, Newspaper, Casual Chat, Memory, Companion
- SCAMPER expansion framework
- ReAct research loop with E-E-A-T scoring
- Phase D critique with HARD-GATE
- bochi-data persistence layer with index.jsonl
- Owner-only learning protocol
- Pipeline position: bochi -> brainstorming handoff
