# Contributing to bochi

## Adding a New Mode

1. Create `references/<mode-name>-spec.md` with sections: Overview, Trigger, Flow, Output, Edge Cases
2. Update `SKILL.md`:
   - Add entry to Mode Router
   - Add triggers to Trigger Logic section
   - Add spec to References table
3. Add scenario tests to `references/scenario-tests.md` (minimum 3 per mode)
4. Update test count in scenario-tests.md header

## Adding Scenario Tests

- ID format: `M<mode>-<number>` (e.g., `M4-01`) or `<category>-<number>` (e.g., `UX-01`)
- Each test needs: ID, Category, Input, Expected Behavior, Pass Criteria
- Pass criteria must be binary (pass/fail, not subjective)

## Modifying Specs

- Run `grep -r "<keyword>" references/ SKILL.md` before editing to check for cross-file references
- If changing a design decision (e.g., removing penalties), update ALL files that reference the old rule
- Edge Cases section is mandatory for all spec files

## Naming Conventions

- File names: `kebab-case` with suffix `-spec.md`, `-checklist.md`, or `-framework.md`
- Test IDs: uppercase prefix + zero-padded number
- JSONL fields: `snake_case`

## Spec Format

```markdown
# <Title>

## Overview
<1-2 sentences>

## Trigger
<When this spec is loaded>

## Flow
<Numbered or diagram steps>

## Output
<Expected output format>

## Edge Cases
<Bullet list of edge cases with handling>
```

## Quality Checks

Before submitting changes:

- [ ] `npx markdownlint-cli2 "**/*.md"` passes
- [ ] All `references/*.md` files referenced in SKILL.md exist
- [ ] Scenario test count matches header
- [ ] No cross-file contradictions (grep for changed keywords)
