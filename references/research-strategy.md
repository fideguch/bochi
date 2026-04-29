# Domain-Specific Research Strategy

## PM / Product
- Query pattern: "{topic} product discovery framework 2026"
- Priority: Teresa Torres, Marty Cagan, Lenny Rachitsky
- Context7: Not needed (WebSearch-focused)

## Technology / Engineering
- Query pattern: "{topic} implementation architecture best practice 2026"
- Priority: GAFA engineering blogs, arxiv
- Context7: Use for library/framework topics

## Business / Strategy
- Query pattern: "{topic} business model market analysis 2026"
- Priority: HBR, a16z, McKinsey
- Context7: Not needed

## Advertising / Marketing
- Query pattern: "{topic} advertising performance optimization 2026"
- Priority: Google Ads blog, Meta for Business
- Context7: Not needed

## UI-UX / Design
- Query pattern: "{topic} UX design pattern accessibility 2026"
- Priority: NNGroup, Figma blog, Material Design
- Context7: Use for design system topics

## AI / ML
- Query pattern: "{topic} AI agent workflow state of the art 2026"
- Priority: arxiv, Anthropic, OpenAI, DeepMind
- Context7: Use for SDK/API topics

## General (domain unknown)
- Run 3 broad queries → auto-detect domain → switch to above strategy
- Use multiple angles: problem-focused, solution-focused, market-focused

---

## YouTube / X Cross-Domain Strategy

When the topic is fast-moving (model releases, platform policies, IPO/funding,
launch retrospectives, conference talks), augment the WebSearch path with one
YouTube query and one X query in parallel — these reach signal classes WebFetch
alone cannot (video-only talks, live practitioner posts).

### YouTube
- Query pattern: `<topic> talk | interview | demo 2026 site:youtube.com`
- Resolve a known channel handle → channelId → RSS:
  `https://www.youtube.com/feeds/videos.xml?channel_id=<UC_ID>`
- Pull transcript via `scripts/fetch_yt_transcript.py <video_url>` only when
  the title alone is insufficient (saves tokens for short clips).

### X (Nitter)
- Query pattern: `https://nitter.net/<handle>/rss` for known practitioners,
  or `site:x.com <topic>` via WebSearch for ad-hoc.
- Threads (5+ posts) generally outscore single posts on E-E-A-T.

### When NOT to bother
- Static / academic topics (paper interpretation is the exception)
- Topics older than 6 months — articles already aggregate the takes
- Sensitive / private domains (HR, legal) — public SNS is rarely high-quality

Reference: `realtime-access-methods.md` for full access protocol,
`learned-channels.md` for verified channel/account inventory.
