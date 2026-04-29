# bochi Learned Channels & Accounts (YouTube / X)

Verified inventory of high-signal YouTube channels and X accounts the Phase C
ReAct loop can use directly. Append-only — promote to this file only after a
positive user-feedback round, mirroring `learned-sources.md`.

## Format

```
YYYY-MM-DD | Platform | Handle | channelId/user_id | Domain | E-E-A-T (typical) | Why it's worth it
```

---

## YouTube — Verified

<!-- Auto-append area -->
<!-- Initial seeds: add via `pm-discovery-interview-prep` or after a successful Phase D pass that cited this channel. -->

## X — Verified

<!-- Auto-append area -->

## Blacklist

<!-- Channels/accounts that produced low-quality or hallucinated info. Skip on future runs. -->

---

## Initial Seed Candidates (un-verified — treat as Tier-2 until graded)

These are starting points for PM/Tech/AI domains. Score with the standard
4-axis E-E-A-T before relying on them.

### YouTube

| Handle | channelId | Domain | Notes |
|--------|-----------|--------|-------|
| @LennysPodcast | (resolve via curl) | PM | Lenny Rachitsky long-form PM interviews |
| @YCombinator | UCcefcZRL2oaA_uBNeo5UOWg | PM/Startup | YC office hours, founder interviews |
| @AnthropicAI | (resolve via curl) | AI | Official Anthropic talks |
| @theprimeagen | UC8ENHE5xdFSwx71u3fDH5Xw | Engineering | Senior engineer takes |
| @t3dotgg | UCbRP3c757lWg9M-U7TyEkXA | Engineering | Theo on web tooling |

> Resolve placeholder channelIds via:
> `curl -s -L https://www.youtube.com/@<handle> | grep -oE '"channelId":"[^"]+"' | head -1`

### X

| Handle | Domain | Notes |
|--------|--------|-------|
| @lennysan | PM | Lenny Rachitsky |
| @jasonlk | Startup | Jason Lemkin (SaaStr) |
| @sama | AI | Sam Altman |
| @karpathy | AI | Andrej Karpathy |
| @amasad | Engineering | Amjad Masad (Replit) |

---

## Operating Rules

- New entries enter the **Initial Seed** section first; only graduate to
  **Verified** after one successful Phase D pass.
- A channel/account loses its slot if it produces a flagged source twice in a
  rolling 30-day window.
- Re-grade quarterly — channels can drift in quality.
