# Master Quality Review Standard

> World-class code & product quality evaluation rubric.
> Derived from Google eng-practices, ISO/IEC 25010:2023, CISQ/ISO 5055,
> CNCF maturity model, AWS Well-Architected, and FAANG calibration practices.

---

## 0. REVIEW PREREQUISITES (HARD-GATE)

Before scoring ANY item, the reviewer MUST complete ALL of the following.
Failure to complete these steps invalidates the entire review.

```
[ ] PR-1: READ every line of target code (SKILL.md, references/*, hooks, scripts)
[ ] PR-2: READ every line of README.md and README.en.md (if exists)
[ ] PR-3: READ CHANGELOG.md (if exists) to understand version history
[ ] PR-4: RUN the code or skill at least once (or verify test output)
[ ] PR-5: CHECK directory structure (ls -R) to confirm no orphaned/missing files
[ ] PR-6: VERIFY all internal references resolve (links, file paths, imports)
```

**Why these are mandatory:**
- Google eng-practices requires reviewing "every line of code assigned to you"
- Microsoft's Engineering Fundamentals mandate reading ALL changed code lines
- Research shows "rubber stamp" reviews (approving without reading) is the #1
  anti-pattern causing production incidents (AWS Well-Architected DevOps Guidance)

---

## 1. EVALUATION PROTOCOL (Anti-Inflation)

### VP-1: Independent Count Verification
When subagents or estimates report numerical values (test count, line count,
coverage %), verify independently with grep/wc/execution output before using
in decisions.

### VP-2: Blind Re-evaluation
Score ALL rubric items BEFORE looking at previous scores.
Compare afterwards and document delta reasons.
Rationale: Google's calibration committees require managers to justify scores
independently before group comparison. Anchoring bias causes re-evaluations
to cluster within +/-5% of prior scores without this protocol.

### VP-3: Full Rubric Pass/Fail Gate
After completing improvements, judge ALL checklist items (not just improved
ones). Partial score estimation is prohibited. Only measured values are valid.

### VP-4: Evidence Gate (NEW)
Each score MUST include one of:
- Code snippet or file:line reference
- Test execution output
- Metric measurement (coverage %, line count, complexity score)
- Screenshot or log excerpt
Scores without evidence are recorded as 0.

### VP-5: Calibration Check
If the same reviewer evaluates the same artifact twice, and scores differ
by less than 2% without documented changes, flag as potential anchoring.

---

## 2. COGNITIVE BIAS CHECKLIST

Review this list BEFORE starting evaluation. Check applicable items:

| Bias | Signal in Review | Countermeasure |
|------|-----------------|----------------|
| IKEA Effect | Overvaluing self-written code by ~63% (Norton 2011) | Evaluate as if someone else wrote it |
| Confirmation Bias | Seeking evidence that confirms initial impression | Actively search for 1+ counter-evidence per claim |
| Anchoring | Score clustering near prior evaluation | VP-2: Blind re-evaluation first |
| Sunk Cost | Reluctance to flag issues in long-running project | Zero-base: "Would I approve this if reviewing for the first time?" |
| Effort Justification | Rating higher because it was hard to build | Separate effort from outcome quality |
| Halo Effect | High score in one area inflates others | Score each axis independently, in random order |
| Recency Bias | Over-weighting recently-read code sections | Review in 2 passes: structure first, details second |

---

## 3. QUALITY RUBRIC (8 Axes)

Synthesized from ISO/IEC 25010:2023, Google eng-practices, and CISQ.
Score each axis 1-10 with mandatory evidence.

### Axis 1: Design & Architecture (ISO: Maintainability)
| Score | Criteria |
|-------|----------|
| 9-10 | Modular, low coupling, clear separation of concerns. No circular deps. Follows established patterns (Repository, Strategy, etc.) |
| 7-8 | Generally well-structured. Minor coupling issues. Mostly follows patterns |
| 5-6 | Some structural issues. Mixed responsibilities. Refactoring needed |
| 3-4 | Tightly coupled. God objects. Hard to extend |
| 1-2 | No discernible architecture. Spaghetti code |
| **Evidence** | Dependency graph, module boundaries, file organization |

### Axis 2: Functionality & Correctness (ISO: Functional Suitability)
| Score | Criteria |
|-------|----------|
| 9-10 | All requirements met. Edge cases handled. Parallel operations safe. No silent failures |
| 7-8 | Core requirements met. Most edge cases covered |
| 5-6 | Happy path works. Some edge cases missed |
| 3-4 | Partial implementation. Known bugs |
| 1-2 | Does not work as intended |
| **Evidence** | Test results, manual verification output, requirement checklist |

### Axis 3: Complexity & Readability (Google: Complexity)
| Score | Criteria |
|-------|----------|
| 9-10 | Any developer can understand in one reading. Functions <50 lines. No deep nesting. Clear naming |
| 7-8 | Understandable with minor effort. Mostly clear naming |
| 5-6 | Requires context to understand. Some overly complex sections |
| 3-4 | Difficult to follow. Over-engineered or under-documented |
| 1-2 | Incomprehensible without author explanation |
| **Evidence** | Cyclomatic complexity, nesting depth, function length stats |

### Axis 4: Testing & Reliability (ISO: Reliability + CISQ)
| Score | Criteria |
|-------|----------|
| 9-10 | 80%+ coverage. Unit + integration + E2E. Tests are correct and well-designed. Failure modes tested |
| 7-8 | 70%+ coverage. Good test variety. Minor gaps |
| 5-6 | 50-70% coverage. Mostly happy-path tests |
| 3-4 | <50% coverage. Tests exist but are brittle or incomplete |
| 1-2 | No tests or tests don't run |
| **Evidence** | Coverage report output, test execution log, test count (verified by grep) |

### Axis 5: Security (ISO: Security + CISQ)
| Score | Criteria |
|-------|----------|
| 9-10 | No hardcoded secrets. Input validated at boundaries. OWASP Top 10 addressed. Dependencies audited |
| 7-8 | No critical vulnerabilities. Most inputs validated |
| 5-6 | Some validation gaps. No known exploits |
| 3-4 | Hardcoded values or unvalidated inputs present |
| 1-2 | Known vulnerabilities. Secrets in code |
| **Evidence** | Security scan output, manual audit findings, dependency audit |

### Axis 6: Documentation & Usability (ISO: Usability)
| Score | Criteria |
|-------|----------|
| 9-10 | README covers install/usage/API/examples. Code comments explain "why". CHANGELOG maintained. Accurate and up-to-date |
| 7-8 | Good README. Most functions documented. Minor gaps |
| 5-6 | Basic README. Some inline comments |
| 3-4 | Minimal documentation. README is outdated or incomplete |
| 1-2 | No documentation |
| **Evidence** | README line count, doc coverage check, broken link scan |

### Axis 7: Performance & Efficiency (ISO: Performance Efficiency)
| Score | Criteria |
|-------|----------|
| 9-10 | Optimized for target environment. No unnecessary computation. Resource usage measured and within bounds |
| 7-8 | Generally efficient. Minor optimization opportunities |
| 5-6 | Acceptable performance. Some known bottlenecks |
| 3-4 | Noticeable performance issues |
| 1-2 | Unacceptable performance for intended use |
| **Evidence** | Benchmark results, profiling output, resource measurements |

### Axis 8: Community & OSS Maturity (CNCF + Awesome List criteria)
| Score | Criteria |
|-------|----------|
| 9-10 | LICENSE + CoC + Contributing guide + Issue templates + CI/CD + Branch protection + Active maintenance (<6mo) + Multiple contributors |
| 7-8 | LICENSE + README + CI. Active maintenance. Responsive to issues |
| 5-6 | LICENSE + README. Some CI. Occasional maintenance |
| 3-4 | Minimal community standards. Infrequent updates |
| 1-2 | No license. No community infrastructure |
| **Evidence** | GitHub community standards check, last commit date, CI status |

---

## 4. SCORING SUMMARY TEMPLATE

```markdown
## Quality Review: [Project Name] v[X.Y]
Date: YYYY-MM-DD
Reviewer: [name]
Review Type: [initial / re-evaluation / calibration]

### Prerequisites Completed
- [x] PR-1 through PR-6 all verified

### Blind Scores (scored BEFORE viewing prior evaluations)
| # | Axis | Score | Evidence |
|---|------|-------|----------|
| 1 | Design & Architecture | X/10 | [specific reference] |
| 2 | Functionality & Correctness | X/10 | [specific reference] |
| 3 | Complexity & Readability | X/10 | [specific reference] |
| 4 | Testing & Reliability | X/10 | [specific reference] |
| 5 | Security | X/10 | [specific reference] |
| 6 | Documentation & Usability | X/10 | [specific reference] |
| 7 | Performance & Efficiency | X/10 | [specific reference] |
| 8 | Community & OSS Maturity | X/10 | [specific reference] |
| **Total** | | **XX/80** | **XX%** |

### Comparison with Prior Score (if re-evaluation)
| Axis | Prior | Current | Delta | Reason |
|------|-------|---------|-------|--------|
| ... | ... | ... | ... | [documented change] |

### Bias Self-Check
- [ ] Reviewed cognitive bias checklist before scoring
- [ ] No IKEA effect (evaluated as if third-party code)
- [ ] No anchoring (scored blind before comparing)
- [ ] Evidence attached for every score > 0

### Severity Classification
| Severity | Count | Items |
|----------|-------|-------|
| CRITICAL | 0 | |
| HIGH | 0 | |
| MEDIUM | 0 | |
| LOW | 0 | |

### Action Items
1. [CRITICAL/HIGH items with fix plan]
```

---

## 5. PASS THRESHOLDS (Spec/Code Quality — Axis 1)

| Gate | Threshold | Action on Fail |
|------|-----------|----------------|
| Ship-ready (external release) | 70/80 (87.5%) + 0 CRITICAL + 0 HIGH | Fix before release |
| Internal-ready (team use) | 56/80 (70%) + 0 CRITICAL | Fix CRITICAL, track HIGH |
| Prototype (demo only) | 40/80 (50%) | Document known issues |
| Reject | <40/80 or any unaddressed CRITICAL | Redesign required |

---

## 5B. UX REALITY AXIS (Axis 2)

> Derived from bochi v2.4 incident: spec scored 84/100 but Mode 2/3 runtime
> infrastructure was completely unbuilt. Users got a broken experience.
>
> **Core insight**: Spec quality and user experience are independent axes.
> A perfect spec with missing infrastructure = broken product.

### Why This Axis Exists

| Evaluation System | What It Measures | Blind Spot |
|-------------------|-----------------|------------|
| Axis 1 (8-axis rubric above) | Code quality, ISO 25010 | Assumes "spec says X = X works" |
| Axis 2 (UX Reality) | Does the user actually experience it? | — |

### UX Reality Dimensions (5 dimensions, 100 points)

| Dimension | Points | What to Evaluate |
|-----------|--------|-----------------|
| Infrastructure Readiness | 20 | Do directories, crons, services assumed by spec actually exist? (verify with `ls`, `crontab -l`, CronList) |
| Functional Verification | 30 | Does each feature return expected output on real execution? (smoke test each mode/endpoint) |
| Degradation Awareness | 15 | When fallback activates, does the user get feedback? (not just silent slowdown) |
| Data Flow Integrity | 20 | Do data pipelines (sync, dedup, PDCA) actually flow end-to-end? |
| End-to-End Latency | 15 | Are spec latency targets met in real measurement? (react <2s, cache <5s, etc.) |

### Verification Methods

1. **Filesystem Audit**: `ls`/`cat` every file/dir the spec assumes exists. Cheapest, most reliable.
2. **Shadow Execution**: Trace spec flowcharts step-by-step on real system.
3. **Trigger Inventory**: Compare CronList output against spec's cron table. Missing = Gap.
4. **Degradation Path Tracing**: Intentionally delete cache/data, verify fallback + user notification.
5. **User Journey Replay**: Execute the documented user journey end-to-end on real device.

### Integrated Score

```
Overall Grade = min(Axis 1 Grade, Axis 2 Grade)
```

**Why min()**: If spec is 84% but UX Reality is 55%, the user experience is 55%.
Averaging hides the gap. min() is the harshest detector of spec-reality divergence.

### When to Apply Axis 2

- **Always**: Before version release, run UX Reality Tier 1 (Infrastructure) via shell
- **Score reporting**: Show both axes. If Axis 2 is unmeasured, mark as "unverified"
- **PDCA**: Include Infrastructure Health (cache status, cron count, last sync, error count)

---

## 6. ANTI-PATTERN WATCHLIST

These patterns signal the review itself is flawed:

| Pattern | Signal | Action |
|---------|--------|--------|
| Rubber Stamp | Review completed in <5min for >100 lines | Redo with timer |
| Optimistic Estimate | "This should add +X points" | VP-3: Full rubric re-eval |
| Subagent Inflation | Agent reports different numbers than grep | VP-1: Independent verification |
| Score Anchoring | Re-eval within +/-2% without changes | VP-2: Blind evaluation |
| Phantom Addition | Plan says "add" for existing content | Read file before planning |
| Delegated Verification | Critical detail from subagent only | Read the file yourself |
| Scope Avoidance | Skipping axes that seem "fine" | All 8 axes mandatory |
| Halo Carry | One strong axis inflating weak ones | Randomize axis evaluation order |

---

## Sources

- Google eng-practices: [Standard of Code Review](https://google.github.io/eng-practices/review/reviewer/standard.html), [What to Look For](https://google.github.io/eng-practices/review/reviewer/looking-for.html)
- [Microsoft Engineering Fundamentals: Code Reviews](https://microsoft.github.io/code-with-engineering-playbook/code-reviews/)
- [Meta: Move faster, wait less](https://engineering.fb.com/2022/11/16/culture/meta-code-review-time-improving/)
- [ISO/IEC 25010:2023 Software Quality Model](https://www.iso.org/standard/35733.html)
- [CISQ Code Quality Standards / ISO 5055](https://www.it-cisq.org/standards/code-quality-standards/)
- [AWS Well-Architected: Code Review Anti-patterns](https://docs.aws.amazon.com/wellarchitected/latest/devops-guidance/anti-patterns-for-code-review.html)
- [CNCF Graduation Criteria](https://github.com/cncf/toc/blob/main/process/graduation_criteria.md)
- Norton, Mochon & Ariely (2011): "The IKEA Effect" — Journal of Consumer Psychology
- [Google GRAD Performance Calibration System](https://www.acciyo.com/performance-review-at-google-the-grad-system/)
