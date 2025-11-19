// index.ts
import { cors, json, normalizePath, isAuthorized, HAS_RIOT_KEY, HAS_OPENAI_KEY } from "./shared.ts";
import { handleRiotMatches, handleRiotMatch, handleRiotAccount, handleRiotSummoner, handleRiotTimelineLite, handleAICoach, handleRiotLeagueEntries, handleRiotLeagueEntriesByPUUID } from "./api.ts";
function cleanPath(p) {
    let out = normalizePath(p);
    if (out.length > 1 && out.endsWith("/")) out = out.slice(0, -1);
    return out;
}
const routes = [
    // Health (no auth)
    {
        method: "GET",
        pattern: /\/health$/,
        handler: async () => json({
            ok: true,
            hasRiotKey: HAS_RIOT_KEY,
            hasOpenAIKey: HAS_OPENAI_KEY
        })
    },
    // Riot + AI routes (auth required)
    {
        method: "GET",
        pattern: /\/riot\/matches$/,
        handler: handleRiotMatches
    },
    {
        method: "GET",
        pattern: /\/riot\/match$/,
        handler: handleRiotMatch
    },
    {
        method: "GET",
        pattern: /\/riot\/account$/,
        handler: handleRiotAccount
    },
    {
        method: "GET",
        pattern: /\/riot\/summoner$/,
        handler: handleRiotSummoner
    },
    {
        method: "GET",
        pattern: /\/riot\/league-entries$/,
        handler: handleRiotLeagueEntries
    },
    {
        method: "GET",
        pattern: /\/riot\/league-entries-by-puuid$/,
        handler: handleRiotLeagueEntriesByPUUID
    },
    {
        method: "POST",
        pattern: /\/riot\/timeline-lite$/,
        handler: handleRiotTimelineLite
    },
    {
        method: "POST",
        pattern: /\/ai\/coach$/,
        handler: handleAICoach
    }
];
Deno.serve(async (req) => {
    // CORS preflight
    if (req.method === "OPTIONS") return new Response(null, {
        headers: cors
    });
    const url = new URL(req.url);
    const path = cleanPath(url.pathname);
    const route = routes.find((r) => r.method === req.method && r.pattern.test(path));
    const isHealth = route?.pattern.source === /\/health$/.source;
    // Auth for everything except /health
    if (!isHealth && !isAuthorized(req)) {
        return json({
            error: "unauthorized"
        }, 401, {
            ...cors,
            "X-Claimb-Why": "isAuthorized=false"
        });
    }
    const deviceId = req.headers.get("x-claimb-device") || req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() || req.headers.get("cf-connecting-ip") || "unknown";
    if (route) {
        try {
            const res = await route.handler(req, deviceId);
            // ensure CORS + diagnostics
            const headers = new Headers(res.headers);
            for (const k in cors) headers.set(k, cors[k]);
            headers.set("X-Claimb-Path", path);
            headers.set("X-Claimb-Route", route.pattern.source);
            headers.set("X-Claimb-Device", deviceId);
            // preserve original body stream
            return new Response(res.body, {
                status: res.status,
                headers
            });
        } catch (err) {
            return json({
                error: "handler_error",
                message: String(err)
            }, 500, {
                ...cors,
                "X-Claimb-Path": path,
                "X-Claimb-Error": "handler throw"
            });
        }
    }
    // Index
    return json({
        ok: true,
        method: req.method,
        path,
        routes: routes.map((r) => `${r.method} ${r.pattern}`)
    }, 200, {
        ...cors,
        "X-Claimb-Path": path
    });
});
