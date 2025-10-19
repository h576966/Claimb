// shared.ts
// deno-lint-ignore-file no-explicit-any
// ----- ENV -----
export const OPENAI_KEY = Deno.env.get("OPENAI_API_KEY") ?? "";
export const RIOT_KEY = Deno.env.get("RIOT_API_KEY") ?? "";
export const APP_SHARED_TOKEN = Deno.env.get("APP_SHARED_TOKEN") ?? "";
// Don’t throw at module init
export const HAS_RIOT_KEY = !!RIOT_KEY && RIOT_KEY.trim().length > 0;
export const HAS_OPENAI_KEY = !!OPENAI_KEY && OPENAI_KEY.trim().length > 0;
// ----- Allowed routing -----
export const ALLOWED_REGIONS = new Set([
    "americas",
    "europe"
]);
export const ALLOWED_PLATFORMS = new Set([
    "na1",
    "euw1",
    "eun1"
]);
export const REGION_BY_PLATFORM = {
    na1: "americas",
    euw1: "europe",
    eun1: "europe"
};
// ----- CORS / HTTP helpers -----
export const cors = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type,Authorization,X-Claimb-App-Token,X-Claimb-Device",
    "Access-Control-Expose-Headers": "X-RateLimit-Remaining,X-Claimb-Shape,X-Claimb-Path",
    "Access-Control-Max-Age": "600"
};
export function json(body, status = 200, extra = {}) {
    return new Response(JSON.stringify(body), {
        status,
        headers: {
            "content-type": "application/json; charset=utf-8",
            ...cors,
            ...extra
        }
    });
}
export const badRequest = (msg) => json({
    error: msg
}, 400);
// ----- Auth -----
export function isAuthorized(req) {
    const appHdr = req.headers.get("x-claimb-app-token")?.trim();
    if (APP_SHARED_TOKEN && appHdr === APP_SHARED_TOKEN) return true;
    const auth = (req.headers.get("authorization") ?? "").trim();
    if (APP_SHARED_TOKEN && auth === `Bearer ${APP_SHARED_TOKEN}`) return true;
    return false;
}
// ----- Rate limit (Upstash best effort) -----
const UP_URL = Deno.env.get("UPSTASH_REDIS_REST_URL");
const UP_TOKEN = Deno.env.get("UPSTASH_REDIS_REST_TOKEN");
export async function rateLimit(id, limit = 60, windowSec = 60) {
    if (!UP_URL || !UP_TOKEN) return {
        allowed: true,
        remaining: limit
    };
    try {
        const key = `rl:${id}:${Math.floor(Date.now() / (windowSec * 1000))}`;
        const r = await fetch(`${UP_URL}/pipeline`, {
            method: "POST",
            headers: {
                Authorization: `Bearer ${UP_TOKEN}`,
                "Content-Type": "application/json"
            },
            body: JSON.stringify({
                pipeline: [
                    [
                        "INCR",
                        key
                    ],
                    [
                        "EXPIRE",
                        key,
                        String(windowSec)
                    ]
                ]
            })
        });
        const res = await r.json().catch(() => null);
        const count = Number(res?.result?.[0] ?? 0);
        return {
            allowed: count <= limit,
            remaining: Math.max(0, limit - count)
        };
    } catch {
        return {
            allowed: true,
            remaining: limit
        };
    }
}
// ----- Utils -----
export function timeoutSignal(ms) {
    const controller = new AbortController();
    const id = setTimeout(() => controller.abort(), ms);
    return {
        signal: controller.signal,
        clear: () => clearTimeout(id)
    };
}
// Trim function prefix and trailing slashes
export function normalizePath(p) {
    let path = p.replace(/\/+$/g, "");
    const m = path.match(/\/claimb-function(\/.*)$/);
    if (m?.[1]) path = m[1];
    if (!path.startsWith("/")) path = "/" + path;
    return path;
}
export function assertRegionOrPlatform(opts) {
    const { region, platform, requireRegion = false, requirePlatform = false } = opts;
    const reg = (region ?? undefined)?.trim();
    const plat = (platform ?? undefined)?.trim();
    if (requireRegion && (!reg || !ALLOWED_REGIONS.has(reg))) throw new Error("invalid_or_missing_region");
    if (requirePlatform && (!plat || !ALLOWED_PLATFORMS.has(plat))) throw new Error("invalid_or_missing_platform");
    if (reg && !ALLOWED_REGIONS.has(reg)) throw new Error("invalid_region");
    if (plat && !ALLOWED_PLATFORMS.has(plat)) throw new Error("invalid_platform");
    return {
        region: reg,
        platform: plat
    };
}
export function deriveRegionFromPlatform(plat) {
    return plat ? REGION_BY_PLATFORM[plat] : undefined;
}
export function parsePositiveInt(x, name) {
    if (x == null) return null;
    const n = Number(x);
    if (!Number.isFinite(n)) throw new Error(`invalid_${name}`);
    const i = Math.floor(n);
    if (i < 0) throw new Error(`invalid_${name}`);
    return i;
}
export function parseEpochSeconds(x, name) {
    if (x == null) return null;
    const n = Number(x);
    if (!Number.isFinite(n)) throw new Error(`invalid_${name}`);
    const i = Math.floor(n);
    if (i < 0) throw new Error(`invalid_${name}`);
    return i;
}
