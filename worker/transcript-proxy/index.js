/**
 * Cloudflare Worker — bochi YouTube transcript proxy
 *
 * Fetches transcripts on behalf of cloud-IP-blocked clients (e.g., the
 * Lightsail bot whose AWS IP is blanket-blocked by YouTube).
 *
 * Cloudflare's egress IP is not on YouTube's cloud-IP block list, so this
 * Worker can reach YouTube where the bot cannot.
 *
 * Endpoint:
 *   GET /?id=<video_id>&lang=<lang_code>
 *   GET /?url=<https://www.youtube.com/watch?v=...>&lang=<lang_code>
 *
 * Optional auth:
 *   If WORKER_SHARED_SECRET is set as a Worker secret/var, requests must
 *   include matching `X-Bochi-Token: <secret>` header (recommended for
 *   public Worker URLs to prevent abuse / cost).
 *
 * Response:
 *   200 text/plain — transcript text (one cue per line)
 *   400 — invalid/missing input
 *   401 — bad/missing token
 *   404 — no captions or no language match
 *   502 — upstream YouTube error
 *
 * Deploy:
 *   1. Cloudflare Dashboard → Workers & Pages → Create Worker
 *   2. Edit Code → paste this file → Save and Deploy
 *   3. (recommended) Settings → Variables → add `WORKER_SHARED_SECRET`
 *      as encrypted variable
 *   4. Copy the Worker URL (e.g., https://bochi-yt.<account>.workers.dev/)
 *   5. Set BOCHI_YT_PROXY_URL + BOCHI_YT_PROXY_TOKEN on the bot host
 */

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    // Optional shared-secret check
    const expected = env && env.WORKER_SHARED_SECRET;
    if (expected) {
      const provided = request.headers.get("X-Bochi-Token");
      if (provided !== expected) {
        return new Response("Unauthorized", { status: 401 });
      }
    }

    // Resolve video_id from either ?id= or ?url=
    let videoId = url.searchParams.get("id");
    const watchUrlParam = url.searchParams.get("url");
    if (!videoId && watchUrlParam) {
      videoId = extractVideoId(watchUrlParam);
    }
    if (!videoId || !/^[A-Za-z0-9_-]{11}$/.test(videoId)) {
      return new Response("invalid or missing video id", { status: 400 });
    }
    const lang = (url.searchParams.get("lang") || "en").toLowerCase();

    try {
      const watchUrl = `https://www.youtube.com/watch?v=${videoId}`;
      const html = await fetch(watchUrl, {
        headers: {
          "User-Agent":
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
          "Accept-Language": "en-US,en;q=0.9",
        },
      }).then((r) => r.text());

      const tracksMatch = html.match(/"captionTracks":(\[[^\]]*\])/);
      if (!tracksMatch) {
        return new Response("no captions available for this video", {
          status: 404,
        });
      }
      const tracks = JSON.parse(tracksMatch[1]);

      // language fallback chain
      const track =
        tracks.find((t) => t.languageCode === lang) ||
        tracks.find((t) => t.languageCode.startsWith(lang)) ||
        tracks.find((t) => t.languageCode === "en") ||
        tracks[0];
      if (!track || !track.baseUrl) {
        return new Response("no matching language track", { status: 404 });
      }

      const xml = await fetch(track.baseUrl).then((r) => r.text());
      const cues = [...xml.matchAll(/<text[^>]*>([^<]*)<\/text>/g)];
      const text = cues
        .map((m) => decodeEntities(m[1]))
        .filter(Boolean)
        .join("\n");

      return new Response(text, {
        headers: {
          "Content-Type": "text/plain; charset=utf-8",
          "X-Lang": track.languageCode,
          "X-Source": "cloudflare-worker-bochi-transcript-proxy/1.0",
          "Cache-Control": "public, max-age=86400",
        },
      });
    } catch (e) {
      return new Response(`upstream error: ${e && e.message}`, { status: 502 });
    }
  },
};

function extractVideoId(value) {
  if (/^[A-Za-z0-9_-]{11}$/.test(value)) return value;
  try {
    const u = new URL(value);
    if (u.hostname === "youtu.be") return u.pathname.slice(1);
    if (u.hostname.endsWith("youtube.com")) {
      if (u.pathname === "/watch") return u.searchParams.get("v");
      const m = u.pathname.match(/^\/(shorts|embed|live)\/([A-Za-z0-9_-]{11})/);
      if (m) return m[2];
    }
  } catch {}
  return null;
}

function decodeEntities(s) {
  return s
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&#39;/g, "'")
    .replace(/&quot;/g, '"')
    .replace(/&nbsp;/g, " ");
}
