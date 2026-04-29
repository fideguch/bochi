/**
 * Cloudflare Worker — bochi YouTube transcript proxy (Innertube API edition)
 *
 * Fetches transcripts on behalf of cloud-IP-blocked clients (Lightsail bot
 * etc.) by calling YouTube's internal Innertube API rather than scraping
 * the public watch page (which now serves a stub HTML to most non-residential
 * IPs, including Cloudflare's edge).
 *
 * Strategy: pose as the official Android YouTube app — same approach used
 * by pytubefix and yt-dlp. Innertube returns captionTracks directly in JSON.
 *
 * Endpoint:
 *   GET /?id=<video_id>&lang=<lang>
 *   GET /?url=<watch_url>&lang=<lang>
 *   GET /?id=<id>&lang=<lang>&debug=1   — diagnostic JSON instead of text
 *
 * Auth (recommended for public Worker URLs):
 *   X-Bochi-Token: <WORKER_SHARED_SECRET>
 *
 * Status codes:
 *   200 — text/plain transcript
 *   400 — invalid input
 *   401 — bad/missing token
 *   404 — captions truly not present
 *   502 — upstream Innertube error
 *
 * Deploy: see ../README.md
 */

// Public Innertube API key used by the YouTube web client.
const INNERTUBE_KEY = "AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8";

// TVHTML5_SIMPLY_EMBEDDED_PLAYER — the client yt-dlp uses to bypass
// signature-required and bot-detection paths. Does not require login.
const CLIENT = {
  clientName: "TVHTML5_SIMPLY_EMBEDDED_PLAYER",
  clientVersion: "2.0",
  hl: "en",
  gl: "US",
  userAgent:
    "Mozilla/5.0 (PlayStation; PlayStation 4/12.00) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Safari/605.1.15",
};

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

    let videoId = url.searchParams.get("id");
    const watchUrlParam = url.searchParams.get("url");
    if (!videoId && watchUrlParam) videoId = extractVideoId(watchUrlParam);
    if (!videoId || !/^[A-Za-z0-9_-]{11}$/.test(videoId)) {
      return new Response("invalid or missing video id", { status: 400 });
    }
    const lang = (url.searchParams.get("lang") || "en").toLowerCase();
    const debug = url.searchParams.get("debug") === "1";

    let player;
    try {
      player = await fetchPlayer(videoId);
    } catch (e) {
      return new Response(`upstream error: ${e && e.message}`, { status: 502 });
    }

    const tracks =
      player?.captions?.playerCaptionsTracklistRenderer?.captionTracks || [];
    if (debug) {
      return new Response(
        JSON.stringify(
          {
            videoId,
            playabilityStatus: player?.playabilityStatus?.status,
            videoTitle: player?.videoDetails?.title,
            availableLangs: tracks.map((t) => t.languageCode),
            track_count: tracks.length,
          },
          null,
          2,
        ),
        { headers: { "Content-Type": "application/json" } },
      );
    }

    if (tracks.length === 0) {
      return new Response("no captions available for this video", {
        status: 404,
      });
    }

    const track =
      tracks.find((t) => t.languageCode === lang) ||
      tracks.find((t) => t.languageCode.startsWith(lang)) ||
      tracks.find((t) => t.languageCode === "en") ||
      tracks[0];
    if (!track || !track.baseUrl) {
      return new Response("no matching language track", { status: 404 });
    }

    let xml;
    try {
      xml = await fetch(track.baseUrl).then((r) => r.text());
    } catch (e) {
      return new Response(`caption fetch failed: ${e && e.message}`, {
        status: 502,
      });
    }

    const cues = [...xml.matchAll(/<text[^>]*>([^<]*)<\/text>/g)];
    const text = cues
      .map((m) => decodeEntities(m[1]))
      .filter(Boolean)
      .join("\n");

    return new Response(text, {
      headers: {
        "Content-Type": "text/plain; charset=utf-8",
        "X-Lang": track.languageCode,
        "X-Source": "cloudflare-worker-bochi-transcript-proxy/2.0-innertube",
        "Cache-Control": "public, max-age=86400",
      },
    });
  },
};

async function fetchPlayer(videoId) {
  const url = `https://www.youtube.com/youtubei/v1/player?key=${INNERTUBE_KEY}`;
  const body = { context: { client: CLIENT }, videoId };
  const r = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "User-Agent": CLIENT.userAgent,
      "X-Youtube-Client-Name": "85",
      "X-Youtube-Client-Version": CLIENT.clientVersion,
      "Accept-Language": "en-US,en;q=0.9",
      Origin: "https://www.youtube.com",
      Referer: "https://www.youtube.com/",
    },
    body: JSON.stringify(body),
  });
  if (!r.ok) {
    const t = await r.text().catch(() => "");
    throw new Error(`Innertube ${r.status}: ${t.slice(0, 1500)}`);
  }
  return r.json();
}

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
