// api.ts
// deno-lint-ignore-file no-explicit-any
import { OPENAI_KEY, RIOT_KEY, HAS_RIOT_KEY, HAS_OPENAI_KEY, json, badRequest, rateLimit, timeoutSignal, assertRegionOrPlatform, deriveRegionFromPlatform, parsePositiveInt, parseEpochSeconds } from "./shared.ts";

// Opt-in verbose logging (set CLAIMB_DEBUG_LOGS=true in edge function env)
const DEBUG_LOGGING = (Deno.env.get("CLAIMB_DEBUG_LOGS") ?? "").toLowerCase() === "true";
function logDebug(message: string, ...args: unknown[]) {
    if (DEBUG_LOGGING) {
        console.log(message, ...args);
    }
}
/* =============================== Constants =============================== */ // Claimb scope
const SUPPORTED_PLATFORMS = new Set([
    "na1",
    "euw1",
    "eun1"
]);
const PLATFORM_TO_REGION = {
    na1: "americas",
    euw1: "europe",
    eun1: "europe"
};
// Riot queues we allow
const Q_NORMAL_DRAFT = 400;
const Q_RANKED_SOLO = 420;
const Q_RANKED_FLEX = 440;
const SUPPORTED_QUEUES = new Set([
    Q_NORMAL_DRAFT,
    Q_RANKED_SOLO,
    Q_RANKED_FLEX
]);
// Riot types we allow (use queue where you can; type is coarser)
const SUPPORTED_TYPES = new Set([
    "ranked",
    "normal"
]);
// Models we allow
const ALLOWED_MODELS = new Set([
    "gpt-5-mini"
]);
/* =============================== Helpers =============================== */ // Minimal retry for transient OpenAI errors / 429s
async function postWithRetry(url, init, tries = 2) {
    let last = null;
    for (let i = 0; i < tries; i++) {
        const res = await fetch(url, init);
        if (res.ok) return res;
        if (res.status !== 429 && res.status < 500) return res;
        last = res;
        await new Promise((r) => setTimeout(r, 300 * (i + 1)));
    }
    return last;
}
// Deterministic extractor for Responses API
function extractOpenAIResult(data) {
    if (data?.output_parsed !== undefined) {
        const parsed = data.output_parsed;
        const t = typeof data?.output_text === "string" && data.output_text.trim();
        return {
            text: t || JSON.stringify(parsed),
            parsed
        };
    }
    const t = typeof data?.output_text === "string" ? data.output_text.trim() : "";
    if (t) return {
        text: t
    };
    const msg = Array.isArray(data?.output) ? data.output.find((x) => x?.type === "message") : null;
    const c = Array.isArray(msg?.content) ? msg.content.find((c) => c?.type === "output_text") : null;
    const textValue = c?.text?.value ?? c?.text ?? "";
    return {
        text: typeof textValue === "string" ? textValue : ""
    };
}
// Validate + resolve region from region/platform, locked to supported set
function resolveRegionOrBadRequest(params) {
    const { region: reg, platform: plat } = assertRegionOrPlatform({
        region: params.region ?? undefined,
        platform: params.platform ?? undefined
    });
    const region = reg ?? deriveRegionFromPlatform(plat);
    if (!region) return {
        error: "invalid_or_missing_region"
    };
    // If a platform was provided, it must be one of ours.
    if (plat && !SUPPORTED_PLATFORMS.has(plat)) return {
        error: "unsupported_platform"
    };
    // If region inferred from platform, it must be americas/europe
    if (plat) {
        const r = PLATFORM_TO_REGION[plat];
        if (!r || r !== region) return {
            error: "platform_region_mismatch"
        };
    } else {
        // If only region provided: must be americas or europe
        if (region !== "americas" && region !== "europe") return {
            error: "unsupported_region"
        };
    }
    return {
        region,
        platform: plat ?? null
    };
}

function parseRiotErrorBody(text) {
    if (!text) return {
        message: null,
        code: null
    };
    const trimmed = text.trim();
    if (!trimmed) return {
        message: null,
        code: null
    };
    try {
        const parsed = JSON.parse(trimmed);
        const status = parsed?.status ?? parsed;
        const message = typeof status?.message === "string" ? status.message : typeof parsed?.message === "string" ? parsed.message : trimmed;
        const code = Number.isFinite(status?.status_code) ? status.status_code : Number.isFinite(status?.code) ? status.code : null;
        return {
            message,
            code
        };
    } catch {
        return {
            message: trimmed,
            code: null
        };
    }
}

function buildRiotError(status, platform, endpoint, rawText) {
    const { message, code } = parseRiotErrorBody(rawText);
    const kind = status === 403 ? "riot_forbidden" : "riot_error";
    const payload = {
        error: kind,
        status,
        endpoint,
        ...(platform ? { platform } : {}),
        ...(message ? { message } : {}),
        ...(code != null ? { riotStatusCode: code } : {}),
        ...(status === 403 ? {
            hint: "Riot API returned 403 Forbidden. Verify RIOT_API_KEY scope, allow list, and development/production entitlement."
        } : {})
    };

    return {
        payload,
        header: kind,
        logDetails: {
            status,
            platform,
            endpoint,
            riotStatusCode: code,
            riotMessage: message,
            raw: rawText?.slice(0, 200) ?? null
        }
    };
}
/* ======================= RIOT: matches by PUUID ======================= */ export async function handleRiotMatches(req, deviceId) {
    if (!HAS_RIOT_KEY) return json({
        error: "server_not_configured",
        missing: [
            "RIOT_API_KEY"
        ]
    }, 500);
    const url = new URL(req.url);
    const puuid = url.searchParams.get("puuid");
    const regionParam = url.searchParams.get("region");
    const platformParam = url.searchParams.get("platform");
    const startRaw = url.searchParams.get("start");
    const countRaw = url.searchParams.get("count");
    const typeParam = url.searchParams.get("type")?.trim() || null;
    const queueParam = url.searchParams.get("queue");
    const startTimeParam = url.searchParams.get("startTime");
    const endTimeParam = url.searchParams.get("endTime");
    if (!puuid) return badRequest("puuid is required");
    const resolved = resolveRegionOrBadRequest({
        region: regionParam,
        platform: platformParam
    });
    if ("error" in resolved) return badRequest(resolved.error);
    const { region } = resolved;
    const start = Math.max(0, parsePositiveInt(startRaw, "start") ?? 0);
    const parsedCount = parsePositiveInt(countRaw, "count");
    const count = Math.min(100, Math.max(1, parsedCount ?? 20));
    // Validate queue/type strictly to Claimb scope
    let queue = null;
    if (queueParam != null) {
        const q = Number(queueParam);
        if (!Number.isFinite(q) || q < 0) return badRequest("invalid_queue");
        if (!SUPPORTED_QUEUES.has(Math.floor(q))) return badRequest("unsupported_queue");
        queue = Math.floor(q);
    }
    if (typeParam && !SUPPORTED_TYPES.has(typeParam)) return badRequest("invalid_type");
    // If type=normal and queue was given, it must be Draft (400)
    if (typeParam === "normal" && queue != null && queue !== Q_NORMAL_DRAFT) return badRequest("normal_requires_queue_400");
    let startTime = null;
    let endTime = null;
    try {
        startTime = parseEpochSeconds(startTimeParam, "startTime");
        endTime = parseEpochSeconds(endTimeParam, "endTime");
    } catch (e) {
        return badRequest(e?.message ?? "invalid_time");
    }
    if (startTime != null && endTime != null && endTime < startTime) return badRequest("endTime_lt_startTime");
    const rl = await rateLimit(`riot:${deviceId}:matches`, 60, 60);
    if (!rl.allowed) return json({
        error: "rate_limited"
    }, 429, {
        "X-RateLimit-Remaining": "0"
    });
    const endpoint = new URL(`https://${region}.api.riotgames.com/lol/match/v5/matches/by-puuid/${encodeURIComponent(puuid)}/ids`);
    endpoint.searchParams.set("start", String(start));
    endpoint.searchParams.set("count", String(count));
    if (typeParam) endpoint.searchParams.set("type", typeParam);
    if (queue != null) endpoint.searchParams.set("queue", String(queue));
    if (startTime != null) endpoint.searchParams.set("startTime", String(startTime));
    if (endTime != null) endpoint.searchParams.set("endTime", String(endTime));
    const to = timeoutSignal(8000);
    try {
        const r = await fetch(endpoint.toString(), {
            headers: {
                "X-Riot-Token": RIOT_KEY
            },
            signal: to.signal
        });
        to.clear();
        if (!r.ok) {
            console.warn("riot matches error", await r.text().catch(() => ""));
            return json({
                error: "riot_error",
                status: r.status
            }, r.status);
        }
        const ids = await r.json();
        return json(ids, 200, {
            "X-RateLimit-Remaining": String(rl.remaining ?? 0),
            "X-Claimb-Shape": "matches-ids[]"
        });
    } catch (e) {
        if (e?.name === "AbortError") return json({
            error: "upstream_timeout"
        }, 504);
        console.error("riot matches fetch error", e);
        return json({
            error: "upstream_error"
        }, 502);
    }
}
/* ========================== RIOT: match detail ========================= */ export async function handleRiotMatch(req, deviceId) {
    if (!HAS_RIOT_KEY) return json({
        error: "server_not_configured",
        missing: [
            "RIOT_API_KEY"
        ]
    }, 500);
    const url = new URL(req.url);
    const matchId = url.searchParams.get("matchId");
    const regionParam = url.searchParams.get("region");
    const platformParam = url.searchParams.get("platform");
    if (!matchId) return badRequest("matchId is required");
    const resolved = resolveRegionOrBadRequest({
        region: regionParam,
        platform: platformParam
    });
    if ("error" in resolved) return badRequest(resolved.error);
    const { region } = resolved;
    const rl = await rateLimit(`riot:${deviceId}:match`, 60, 60);
    if (!rl.allowed) return json({
        error: "rate_limited"
    }, 429, {
        "X-RateLimit-Remaining": "0"
    });
    const endpoint = `https://${region}.api.riotgames.com/lol/match/v5/matches/${encodeURIComponent(matchId)}`;
    const to = timeoutSignal(8000);
    try {
        const r = await fetch(endpoint, {
            headers: {
                "X-Riot-Token": RIOT_KEY
            },
            signal: to.signal
        });
        to.clear();
        if (!r.ok) {
            console.warn("riot match error", await r.text().catch(() => ""));
            return json({
                error: "riot_error",
                status: r.status
            }, r.status);
        }
        const match = await r.json();
        match.claimb_matchId = matchId;
        match.claimb_region = region;
        return json(match, 200, {
            "X-Claimb-Shape": "match-raw+meta",
            "X-RateLimit-Remaining": String(rl.remaining ?? 0)
        });
    } catch (e) {
        if (e?.name === "AbortError") return json({
            error: "upstream_timeout"
        }, 504);
        console.error("riot match fetch error", e);
        return json({
            error: "upstream_error"
        }, 502);
    }
}
/* ======================== RIOT: account lookup ======================== */ export async function handleRiotAccount(req, deviceId) {
    if (!HAS_RIOT_KEY) return json({
        error: "server_not_configured",
        missing: [
            "RIOT_API_KEY"
        ]
    }, 500);
    const url = new URL(req.url);
    const gameName = url.searchParams.get("gameName");
    const tagLine = url.searchParams.get("tagLine");
    const puuid = url.searchParams.get("puuid");
    const regionParam = url.searchParams.get("region");
    const platformParam = url.searchParams.get("platform");
    const resolved = resolveRegionOrBadRequest({
        region: regionParam,
        platform: platformParam
    });
    if ("error" in resolved) return badRequest(resolved.error);
    const { region } = resolved;
    if (!puuid && !(gameName && tagLine)) return badRequest("provide either puuid or gameName+tagLine");
    const rl = await rateLimit(`riot:${deviceId}:account`, 30, 60);
    if (!rl.allowed) return json({
        error: "rate_limited"
    }, 429, {
        "X-RateLimit-Remaining": "0"
    });
    const base = `https://${region}.api.riotgames.com/riot/account/v1/accounts`;
    const endpoint = puuid ? `${base}/by-puuid/${encodeURIComponent(puuid)}` : `${base}/by-riot-id/${encodeURIComponent(gameName)}/${encodeURIComponent(tagLine)}`;
    const to = timeoutSignal(8000);
    try {
        const r = await fetch(endpoint, {
            headers: {
                "X-Riot-Token": RIOT_KEY
            },
            signal: to.signal
        });
        to.clear();
        if (!r.ok) {
            console.warn("riot account error", await r.text().catch(() => ""));
            return json({
                error: "riot_error",
                status: r.status
            }, r.status);
        }
        const acc = await r.json();
        const shaped = {
            ...acc,
            claimb_region: region,
            claimb_lookup: puuid ? "by-puuid" : "by-riot-id"
        };
        return json(shaped, 200, {
            "X-Claimb-Shape": "account-raw+meta",
            "X-RateLimit-Remaining": String(rl.remaining ?? 0)
        });
    } catch (e) {
        if (e?.name === "AbortError") return json({
            error: "upstream_timeout"
        }, 504);
        console.error("riot account fetch error", e);
        return json({
            error: "upstream_error"
        }, 502);
    }
}
/* ===================== RIOT: summoner by PUUID ===================== */ export async function handleRiotSummoner(req) {
    if (!HAS_RIOT_KEY) return json({
        error: "server_not_configured",
        missing: [
            "RIOT_API_KEY"
        ]
    }, 500);
    const url = new URL(req.url);
    const puuid = url.searchParams.get("puuid");
    const platformParam = url.searchParams.get("platform");
    if (!puuid) return badRequest("puuid is required");
    // Require supported platform explicitly for this endpoint
    const plat = (platformParam ?? "").trim().toLowerCase();
    if (!SUPPORTED_PLATFORMS.has(plat)) return badRequest("unsupported_platform");
    const endpoint = `https://${plat}.api.riotgames.com/lol/summoner/v4/summoners/by-puuid/${encodeURIComponent(puuid)}`;
    const to = timeoutSignal(8000);
    try {
        const r = await fetch(endpoint, {
            headers: {
                "X-Riot-Token": RIOT_KEY
            },
            signal: to.signal
        });
        to.clear();
        if (!r.ok) {
            console.warn("riot summoner error", await r.text().catch(() => ""));
            return json({
                error: "riot_error",
                status: r.status
            }, r.status);
        }
        const summoner = await r.json();
        const shaped = {
            ...summoner,
            claimb_platform: plat,
            claimb_region: PLATFORM_TO_REGION[plat] ?? null,
            claimb_puuid: puuid
        };
        return json(shaped, 200, {
            "X-Claimb-Shape": "summoner-raw+meta"
        });
    } catch (e) {
        if (e?.name === "AbortError") return json({
            error: "upstream_timeout"
        }, 504);
        console.error("riot summoner fetch error", e);
        return json({
            error: "upstream_error"
        }, 502);
    }
}
/* ========== RIOT: timeline-lite (LLM-friendly checkpoints) ========== */ export async function handleRiotTimelineLite(req, deviceId) {
    if (!HAS_RIOT_KEY) return json({
        error: "server_not_configured",
        missing: [
            "RIOT_API_KEY"
        ]
    }, 500);
    const rl = await rateLimit(`riot:${deviceId}:timeline-lite`, 60, 60);
    if (!rl.allowed) return json({
        error: "rate_limited"
    }, 429, {
        "X-RateLimit-Remaining": "0"
    });
    let body;
    try {
        body = await req.json();
    } catch {
        return badRequest("invalid_json");
    }
    const regionParam = (body?.region ?? "").trim();
    const platformParam = (body?.platform ?? "").trim();
    const matchId = (body?.matchId ?? "").trim();
    const puuid = (body?.puuid ?? "").trim();
    if (!matchId) return badRequest("matchId is required");
    if (!puuid) return badRequest("puuid is required");
    const resolved = resolveRegionOrBadRequest({
        region: regionParam,
        platform: platformParam
    });
    if ("error" in resolved) return badRequest(resolved.error);
    const { region } = resolved;
    const endpoint = `https://${region}.api.riotgames.com/lol/match/v5/matches/${encodeURIComponent(matchId)}/timeline`;
    const to = timeoutSignal(8000);
    try {
        const r = await fetch(endpoint, {
            headers: {
                "X-Riot-Token": RIOT_KEY
            },
            signal: to.signal
        });
        to.clear();
        if (!r.ok) {
            const err = await r.text().catch(() => "");
            console.warn("riot timeline error", r.status, err);
            return json({
                error: "riot_error",
                status: r.status
            }, r.status);
        }
        const tl = await r.json();
        const pid = (tl?.metadata?.participants?.indexOf?.(puuid) ?? -1) + 1;
        if (pid <= 0) return json({
            error: "puuid not in match"
        }, 404);
        const frames = tl?.info?.frames ?? [];
        const events = frames.flatMap((f) => f?.events ?? []);
        const frameInterval = tl?.info?.frameInterval || 60_000;
        const idxAt = (ms) => Math.max(0, Math.floor(ms / frameInterval));
        const minOf = (ms) => typeof ms === "number" && isFinite(ms) ? Math.round(ms / 60_000) : null;
        function kdaAt(ms) {
            let k = 0, d = 0, a = 0;

            for (const event of events) {
                if ((event.timestamp ?? 0) > ms || event.type !== "CHAMPION_KILL") continue;

                if (event.killerId === pid) k++;
                if (event.victimId === pid) d++;
                if ((event.assistingParticipantIds ?? []).includes(pid)) a++;
            }

            return { k, d, a };
        }
        function snapAt(ms) {
            const fr = frames[idxAt(ms)];
            const pf = fr?.participantFrames?.[String(pid)];
            const { k, d, a } = kdaAt(ms);
            return {
                cs: (pf?.minionsKilled ?? 0) + (pf?.jungleMinionsKilled ?? 0),
                gold: pf?.totalGold ?? pf?.currentGold ?? 0,
                xp: pf?.xp ?? 0,
                k,
                d,
                a
            };
        }
        const at10 = snapAt(10 * 60_000);
        const at15 = snapAt(15 * 60_000);
        // Single pass through events for timings (optimization)
        let firstBackMs = null;
        let firstKillMs = null;
        let firstDeathMs = null;
        let platesPre14 = 0;

        for (const event of events) {
            const timestamp = event.timestamp ?? 0;

            // First back (after 2 minutes)
            if (!firstBackMs &&
                (event.type === "ITEM_PURCHASED" || event.type === "ITEM_UNDO") &&
                event.participantId === pid &&
                timestamp > 120_000) {
                firstBackMs = timestamp;
            }

            // First kill
            if (!firstKillMs &&
                event.type === "CHAMPION_KILL" &&
                event.killerId === pid) {
                firstKillMs = timestamp;
            }

            // First death
            if (!firstDeathMs &&
                event.type === "CHAMPION_KILL" &&
                event.victimId === pid) {
                firstDeathMs = timestamp;
            }

            // Turret plates before 14 minutes
            if (event.type === "TURRET_PLATE_DESTROYED" &&
                (event.killerId === pid ||
                    (event.assistingParticipantIds ?? []).includes(pid)) &&
                timestamp <= 14 * 60_000) {
                platesPre14++;
            }
        }
        return json({
            matchId,
            region,
            puuid,
            participantId: pid,
            checkpoints: {
                "10min": {
                    ...at10,
                    kda: `${at10.k}/${at10.d}/${at10.a}`
                },
                "15min": {
                    ...at15,
                    kda: `${at15.k}/${at15.d}/${at15.a}`
                }
            },
            timings: {
                firstBackMin: minOf(firstBackMs),
                firstKillMin: minOf(firstKillMs),
                firstDeathMin: minOf(firstDeathMs)
            },
            platesPre14
        }, 200, {
            "X-Claimb-Shape": "timeline-lite",
            "X-RateLimit-Remaining": String(rl.remaining ?? 0)
        });
    } catch (e) {
        if (e?.name === "AbortError") return json({
            error: "upstream_timeout"
        }, 504);
        console.error("timeline-lite error", e);
        return json({
            error: "upstream_error"
        }, 502);
    }
}
/* ===================== RIOT: league entries by summonerId ===================== */
export async function handleRiotLeagueEntries(req, deviceId) {
    if (!HAS_RIOT_KEY) return json({
        error: "server_not_configured",
        missing: ["RIOT_API_KEY"]
    }, 500);

    const url = new URL(req.url);
    const summonerId = url.searchParams.get("summonerId");
    const platformParam = url.searchParams.get("platform");

    if (!summonerId) return badRequest("summonerId is required");

    const plat = (platformParam ?? "").trim().toLowerCase();
    if (!SUPPORTED_PLATFORMS.has(plat)) return badRequest("unsupported_platform");

    const rl = await rateLimit(`riot:${deviceId}:league`, 30, 60);
    if (!rl.allowed) return json({ error: "rate_limited" }, 429, { "X-RateLimit-Remaining": "0" });

    const endpoint = `https://${plat}.api.riotgames.com/lol/league/v4/entries/by-summoner/${encodeURIComponent(summonerId)}`;
    const to = timeoutSignal(8000);

    try {
        const r = await fetch(endpoint, {
            headers: { "X-Riot-Token": RIOT_KEY },
            signal: to.signal
        });
        to.clear();

        if (!r.ok) {
            const raw = await r.text().catch(() => "");
            const errorInfo = buildRiotError(r.status, plat, "league-entries", raw);
            console.warn("riot league entries error", errorInfo.logDetails);
            return json(errorInfo.payload, r.status, { "X-Claimb-Why": errorInfo.header });
        }

        const entries = await r.json();
        const shaped = {
            entries,
            claimbPlatform: plat,
            claimbRegion: PLATFORM_TO_REGION[plat] ?? null,
            claimbSummonerId: summonerId
        };

        return json(shaped, 200, {
            "X-Claimb-Shape": "league-entries+meta",
            "X-RateLimit-Remaining": String(rl.remaining ?? 0)
        });
    } catch (e) {
        if (e?.name === "AbortError") return json({ error: "upstream_timeout" }, 504);
        console.error("riot league entries fetch error", e);
        return json({ error: "upstream_error" }, 502);
    }
}

/* ===================== RIOT: league entries by PUUID ===================== */
export async function handleRiotLeagueEntriesByPUUID(req, deviceId) {
    if (!HAS_RIOT_KEY) return json({
        error: "server_not_configured",
        missing: ["RIOT_API_KEY"]
    }, 500);

    const url = new URL(req.url);
    const puuid = url.searchParams.get("puuid");
    const platformParam = url.searchParams.get("platform");

    if (!puuid) return badRequest("puuid is required");

    const plat = (platformParam ?? "").trim().toLowerCase();
    if (!SUPPORTED_PLATFORMS.has(plat)) return badRequest("unsupported_platform");

    const rl = await rateLimit(`riot:${deviceId}:league`, 30, 60);
    if (!rl.allowed) return json({ error: "rate_limited" }, 429, { "X-RateLimit-Remaining": "0" });

    const to = timeoutSignal(8000);

    try {
        // Use direct PUUID endpoint - no need to lookup summoner ID first
        const leagueEndpoint = `https://${plat}.api.riotgames.com/lol/league/v4/entries/by-puuid/${encodeURIComponent(puuid)}`;
        const leagueRes = await fetch(leagueEndpoint, {
            headers: { "X-Riot-Token": RIOT_KEY },
            signal: to.signal
        });

        to.clear();

        if (!leagueRes.ok) {
            const raw = await leagueRes.text().catch(() => "");
            const errorInfo = buildRiotError(leagueRes.status, plat, "league-entries-by-puuid", raw);
            console.warn("riot league entries by puuid error", errorInfo.logDetails);
            return json(errorInfo.payload, leagueRes.status, { "X-Claimb-Why": errorInfo.header });
        }

        const entries = await leagueRes.json();
        const shaped = {
            entries,
            claimbPlatform: plat,
            claimbRegion: PLATFORM_TO_REGION[plat] ?? null,
            claimbPUUID: puuid
        };

        return json(shaped, 200, {
            "X-Claimb-Shape": "league-entries+meta",
            "X-RateLimit-Remaining": String(rl.remaining ?? 0)
        });
    } catch (e) {
        if (e?.name === "AbortError") return json({ error: "upstream_timeout" }, 504);
        console.error("riot league entries by puuid fetch error", e);
        return json({ error: "upstream_error" }, 502);
    }
}

/* =========== AI: Coaching via OpenAI Responses API (clean) =========== */ export async function handleAICoach(req, deviceId) {
    const rl = await rateLimit(`ai:${deviceId}:coach`, 30, 60);
    if (!rl.allowed) return json({
        error: "rate_limited"
    }, 429, {
        "X-RateLimit-Remaining": "0"
    });
    let body;
    try {
        body = await req.json();
    } catch {
        return json({
            error: "invalid_json"
        }, 400);
    }
    const prompt = typeof body?.prompt === "string" ? body.prompt : "";
    if (!prompt) return json({
        error: "prompt required"
    }, 400);
    const model = (typeof body?.model === "string" ? body.model : "gpt-5-mini").trim();
    if (!ALLOWED_MODELS.has(model)) return json({
        error: "model not allowed"
    }, 400);
    if (!HAS_OPENAI_KEY) return json({
        error: "openai_key_missing"
    }, 500);

    // Optional match metadata for timeline fetching
    const matchId = typeof body?.matchId === "string" ? body.matchId.trim() : null;
    const puuid = typeof body?.puuid === "string" ? body.puuid.trim() : null;
    const regionOrPlatform = typeof body?.region === "string" ? body.region.trim() : null;

    // Optional system/dev prompt (Responses uses `instructions`)
    const rawInstructions = typeof body?.system === "string" ? body.system : typeof body?.instructions === "string" ? body.instructions : undefined;
    // max_output_tokens: 1..2000
    const motRaw = Number(body?.max_output_tokens);
    const max_output_tokens = Number.isFinite(motRaw) ? Math.min(Math.max(1, Math.floor(motRaw)), 2000) : 512;
    // temperature [0..2]
    const tNum = body?.temperature === undefined ? undefined : Number(body.temperature);
    const temperature = tNum === undefined || !Number.isFinite(tNum) ? undefined : Math.max(0, Math.min(2, tNum));
    // Reasoning: accept minimal/low/medium/high; default "low" (broad compatibility)
    const effortFromBody = typeof body?.reasoning?.effort === "string" ? body.reasoning.effort : typeof body?.reasoning_effort === "string" ? body.reasoning_effort : undefined;
    const validEfforts = new Set([
        "minimal",
        "low",
        "medium",
        "high"
    ]);
    const reasoning = {
        effort: validEfforts.has((effortFromBody ?? "").toLowerCase()) ? effortFromBody : "low"
    };
    // TEXT format for Responses API (corrected for GPT-5-mini)
    let text = undefined;
    const fmt = typeof body?.text_format === "string" ? body.text_format.trim().toLowerCase() : undefined;

    if (fmt === "json") {
        text = {
            format: {
                type: "json_object"
            }
        };
    } else if (fmt === "text" || fmt === "plain") {
        text = {
            format: {
                type: "text"
            }
        };
    }

    // JSON Schema support for structured responses
    if (!text && body?.json_schema) {
        const schema = body.json_schema.schema ? body.json_schema.schema : body.json_schema;
        text = {
            format: {
                type: "json_schema",
                json_schema: {
                    name: body.json_schema.name ?? "claimb_schema",
                    strict: body.json_schema.strict ?? true,
                    schema: schema
                }
            }
        };
    }
    const metadata = body?.metadata && typeof body.metadata === "object" ? body.metadata : undefined;

    // Fetch and inject timeline data if match metadata is provided (optimized processor)
    let enhancedPrompt = prompt;
    let timelineIncluded = false;

    if (matchId && puuid && regionOrPlatform) {
        try {
            // Use optimized timeline processor for better performance
            const formatted = await timelineProcessor.processForPrompt(matchId, puuid, regionOrPlatform);
            if (formatted) {
                enhancedPrompt =
                    `${prompt}\n\n**EARLY GAME TIMELINE (use this to evaluate laning pace and resource setup):**\n${formatted}`;
                timelineIncluded = true;
                logDebug("Timeline data successfully injected for match:", matchId);
            } else {
                console.warn("Timeline processor returned null for match:", matchId);
            }
        } catch (err) {
            // Log but don't fail - timeline is optional enhancement
            console.warn("Timeline fetch failed for match:", matchId, "Error:", err?.message || err);
        }
    } else {
        logDebug("No match metadata provided - timeline not attempted");
    }

    // Log timeline inclusion rate for monitoring
    console.log(`Timeline inclusion: ${timelineIncluded ? 'SUCCESS' : 'FAILED'} for match: ${matchId || 'N/A'}`);

    const JSON_NOTE = "IMPORTANT: Output must be valid json.";
    let instructions = rawInstructions;
    if (text?.format?.type === "json_object" && instructions && !/json/i.test(instructions)) {
        instructions = `${instructions}\n\n${JSON_NOTE}`;
    }
    let finalPrompt = enhancedPrompt;
    if (text?.format?.type === "json_object" && !/json/i.test(finalPrompt)) {
        finalPrompt = `${enhancedPrompt}\n\n${JSON_NOTE}`;
    }

    const payload = {
        model,
        input: finalPrompt,
        max_output_tokens,
        ...instructions ? {
            instructions
        } : {},
        ...temperature !== undefined ? {
            temperature
        } : {},
        ...reasoning ? {
            reasoning
        } : {},
        ...text ? {
            text
        } : {},
        ...metadata ? {
            metadata
        } : {}
    };

    // Debug logging for OpenAI payload (opt-in via env flag)
    logDebug("OpenAI Responses API payload:", JSON.stringify(payload, null, 2));
    const to = timeoutSignal(30_000); // 30 second timeout (timeline fetch + OpenAI processing + buffer)
    try {
        const init = {
            method: "POST",
            headers: {
                Authorization: `Bearer ${OPENAI_KEY}`,
                "Content-Type": "application/json"
            },
            body: JSON.stringify(payload),
            signal: to.signal
        };
        const r = await postWithRetry("https://api.openai.com/v1/responses", init, 2);
        to.clear();
        if (!r.ok) {
            const errText = await r.text().catch(() => "");
            console.warn("openai responses error", r.status, errText);
            return json({
                error: "openai_error",
                status: r.status,
                detail: errText
            }, r.status);
        }
        const data = await r.json();
        const { text: outText, parsed } = extractOpenAIResult(data);
        return json(parsed !== undefined ? {
            text: outText,
            model,
            parsed
        } : {
            text: outText,
            model
        }, 200, {
            "X-Claimb-Shape": parsed !== undefined ? "coach-text+parsed" : "coach-text",
            "X-RateLimit-Remaining": String(rl.remaining ?? 0)
        });
    } catch (e) {
        if (e?.name === "AbortError") {
            console.warn("OpenAI API timeout (30s exceeded)");
            return json({
                error: "upstream_timeout"
            }, 504);
        }
        console.error("OpenAI API fetch error:", e?.message || e);
        return json({
            error: "upstream_error"
        }, 502);
    }
}

/* =========== Optimized Timeline Processing (TypeScript 5.0 Performance Lessons) =========== */

// Uniform object shapes (TypeScript 5.0 lesson: reduced polymorphism)
interface TimelineCheckpoint {
    readonly cs: number;
    readonly gold: number;
    readonly xp: number;
    readonly k: number;
    readonly d: number;
    readonly a: number;
    readonly kda: string;
}

interface TimelineTimings {
    readonly firstBackMin: number | null;
    readonly firstKillMin: number | null;
    readonly firstDeathMin: number | null;
}

interface ProcessedTimelineData {
    readonly checkpoints: {
        readonly "10min": TimelineCheckpoint;
        readonly "15min": TimelineCheckpoint;
    };
    readonly timings: TimelineTimings;
    readonly platesPre14: number;
}

interface ProcessedTimeline {
    readonly events: readonly any[];
    readonly frames: readonly any[];
    readonly participantId: number;
    readonly frameInterval: number;
    readonly processed: ProcessedTimelineData;
}

// Pre-computed formatting templates (TypeScript 5.0 lesson: string caching)
const FORMATTING_TEMPLATES = {
    checkpoint: (min: number, cs: number, kda: string, gold: number) =>
        `- ${min} min — ${cs} CS (${kda}), ${gold}g`,
    timings: (timings: string[]) =>
        `- Timing milestones: ${timings.join(", ")}`,
    plates: (count: number) =>
        `- Turret plates before 14 min: ${count}`,
    usage: "- Coaching usage: comment on early laning pace, recall timing, kill pressure, and how these affected mid-game setup."
} as const;

/**
 * Optimized timeline processor focused on single-use performance
 * Inspired by TypeScript 5.0 performance improvements:
 * - Uniform object shapes to reduce polymorphism
 * - Single-pass processing for faster computation
 * - Direct function calls instead of dynamic dispatch
 * 
 * Note: No caching needed - each match analyzed once and cached locally in iOS app
 */
class TimelineProcessor {
    private readonly SUPPORTED_PLATFORMS = new Set(["na1", "euw1", "eun1"]);
    private readonly PLATFORM_TO_REGION: Record<string, string> = {
        na1: "americas",
        euw1: "europe",
        eun1: "europe"
    };

    /**
     * Main entry point for timeline processing
     * Returns formatted timeline string or null if processing fails
     * Optimized for single-use: fetch → process → format → return
     */
    async processForPrompt(matchId: string, puuid: string, regionOrPlatform: string): Promise<string | null> {
        // Early returns for invalid input (performance optimization)
        if (!matchId?.trim() || !puuid?.trim() || !regionOrPlatform?.trim()) {
            return null;
        }

        if (!HAS_RIOT_KEY) {
            return null;
        }

        const region = this.resolveRegion(regionOrPlatform);
        if (!region) {
            console.warn("Invalid region for timeline:", regionOrPlatform);
            return null;
        }

        // Direct processing - no caching needed for single-use scenario
        const processed = await this.fetchAndProcessTimeline(matchId, puuid, region);
        if (!processed) {
            return null;
        }

        return this.formatForPrompt(processed.processed);
    }

    /**
     * Resolve region from platform or validate region
     * Uniform logic to reduce polymorphic behavior
     */
    private resolveRegion(regionOrPlatform: string): string | null {
        const input = regionOrPlatform.toLowerCase();

        // Check if it's a platform first
        if (this.SUPPORTED_PLATFORMS.has(input)) {
            return this.PLATFORM_TO_REGION[input];
        }

        // Check if it's a valid region
        const validRegions = new Set(Object.values(this.PLATFORM_TO_REGION));
        if (validRegions.has(input)) {
            return input;
        }

        return null;
    }

    /**
     * Fetch timeline data and process it into uniform structure
     * Single responsibility: fetch + process in one step to avoid multiple iterations
     */
    private async fetchAndProcessTimeline(matchId: string, puuid: string, region: string): Promise<ProcessedTimeline | null> {
        const endpoint = `https://${region}.api.riotgames.com/lol/match/v5/matches/${encodeURIComponent(matchId)}/timeline`;
        const to = timeoutSignal(8000);

        try {
            const response = await fetch(endpoint, {
                headers: { "X-Riot-Token": RIOT_KEY },
                signal: to.signal
            });

            to.clear();

            if (!response.ok) {
                console.warn("Riot timeline API error:", response.status, "for match:", matchId);
                return null;
            }

            const rawTimeline = await response.json();
            return this.processRawTimeline(rawTimeline, puuid);

        } catch (err) {
            if (err?.name === "AbortError") {
                console.warn("Timeline fetch timeout (8s exceeded) for match:", matchId);
            } else {
                console.error("Timeline fetch error for match:", matchId, err?.message || err);
            }
            return null;
        }
    }

    /**
     * Process raw timeline data into optimized structure
     * Key optimization: single pass through events and frames
     */
    private processRawTimeline(rawTimeline: any, puuid: string): ProcessedTimeline | null {
        const participantId = (rawTimeline?.metadata?.participants?.indexOf?.(puuid) ?? -1) + 1;
        if (participantId <= 0) {
            console.warn("PUUID not found in timeline match");
            return null;
        }

        const frames = rawTimeline?.info?.frames ?? [];
        const events = frames.flatMap((f: any) => f?.events ?? []);
        const frameInterval = rawTimeline?.info?.frameInterval || 60_000;

        // Early return if no meaningful data
        if (frames.length === 0) {
            return null;
        }

        // Process all data in single pass (TypeScript 5.0 lesson: reduced iterations)
        const processed = this.computeTimelineMetrics(frames, events, participantId, frameInterval);

        return {
            events: Object.freeze(events), // Immutable for safety
            frames: Object.freeze(frames),
            participantId,
            frameInterval,
            processed: Object.freeze(processed) // Uniform object shape
        };
    }

    /**
     * Compute all timeline metrics in a single pass
     * Optimized to avoid multiple iterations over the same data
     */
    private computeTimelineMetrics(
        frames: readonly any[],
        events: readonly any[],
        participantId: number,
        frameInterval: number
    ): ProcessedTimelineData {
        // Helper functions with consistent signatures (reduced polymorphism)
        const idxAt = (ms: number): number => Math.max(0, Math.floor(ms / frameInterval));
        const minOf = (ms: number | null): number | null =>
            typeof ms === "number" && isFinite(ms) ? Math.round(ms / 60_000) : null;

        // Optimized single-pass KDA calculation
        const kdaAt = (ms: number): { k: number; d: number; a: number } => {
            let k = 0, d = 0, a = 0;

            for (const event of events) {
                if ((event.timestamp ?? 0) > ms || event.type !== "CHAMPION_KILL") continue;

                if (event.killerId === participantId) k++;
                if (event.victimId === participantId) d++;
                if ((event.assistingParticipantIds ?? []).includes(participantId)) a++;
            }

            return { k, d, a };
        };

        // Snapshot at specific time with uniform object shape
        const snapAt = (ms: number): TimelineCheckpoint => {
            const frame = frames[idxAt(ms)];
            const participantFrame = frame?.participantFrames?.[String(participantId)];
            const { k, d, a } = kdaAt(ms);

            return {
                cs: (participantFrame?.minionsKilled ?? 0) + (participantFrame?.jungleMinionsKilled ?? 0),
                gold: participantFrame?.totalGold ?? participantFrame?.currentGold ?? 0,
                xp: participantFrame?.xp ?? 0,
                k,
                d,
                a,
                kda: `${k}/${d}/${a}`
            };
        };

        // Compute checkpoints
        const at10 = snapAt(10 * 60_000);
        const at15 = snapAt(15 * 60_000);

        // Single pass through events for timings (optimization)
        let firstBackMs: number | null = null;
        let firstKillMs: number | null = null;
        let firstDeathMs: number | null = null;
        let platesPre14 = 0;

        for (const event of events) {
            const timestamp = event.timestamp ?? 0;

            // First back (after 2 minutes)
            if (!firstBackMs &&
                (event.type === "ITEM_PURCHASED" || event.type === "ITEM_UNDO") &&
                event.participantId === participantId &&
                timestamp > 120_000) {
                firstBackMs = timestamp;
            }

            // First kill
            if (!firstKillMs &&
                event.type === "CHAMPION_KILL" &&
                event.killerId === participantId) {
                firstKillMs = timestamp;
            }

            // First death
            if (!firstDeathMs &&
                event.type === "CHAMPION_KILL" &&
                event.victimId === participantId) {
                firstDeathMs = timestamp;
            }

            // Turret plates before 14 minutes
            if (event.type === "TURRET_PLATE_DESTROYED" &&
                (event.killerId === participantId ||
                    (event.assistingParticipantIds ?? []).includes(participantId)) &&
                timestamp <= 14 * 60_000) {
                platesPre14++;
            }
        }

        return {
            checkpoints: {
                "10min": at10,
                "15min": at15
            },
            timings: {
                firstBackMin: minOf(firstBackMs),
                firstKillMin: minOf(firstKillMs),
                firstDeathMin: minOf(firstDeathMs)
            },
            platesPre14
        };
    }

    /**
     * Format processed timeline data for prompt
     * Uses pre-computed templates for performance (TypeScript 5.0 string caching lesson)
     */
    private formatForPrompt(data: ProcessedTimelineData): string {
        const lines: string[] = [];

        // Checkpoints with pre-computed templates
        lines.push(FORMATTING_TEMPLATES.checkpoint(
            10,
            data.checkpoints["10min"].cs,
            data.checkpoints["10min"].kda,
            data.checkpoints["10min"].gold
        ));

        lines.push(FORMATTING_TEMPLATES.checkpoint(
            15,
            data.checkpoints["15min"].cs,
            data.checkpoints["15min"].kda,
            data.checkpoints["15min"].gold
        ));

        // Timing milestones (conditional formatting)
        const timingHighlights: string[] = [];
        if (data.timings.firstBackMin) timingHighlights.push(`First back: ${data.timings.firstBackMin} min`);
        if (data.timings.firstKillMin) timingHighlights.push(`First kill: ${data.timings.firstKillMin} min`);
        if (data.timings.firstDeathMin) timingHighlights.push(`First death: ${data.timings.firstDeathMin} min`);

        if (timingHighlights.length > 0) {
            lines.push(FORMATTING_TEMPLATES.timings(timingHighlights));
        }

        // Turret plates
        if (data.platesPre14 > 0) {
            lines.push(FORMATTING_TEMPLATES.plates(data.platesPre14));
        }

        // Usage guidance
        lines.push(FORMATTING_TEMPLATES.usage);

        return `EARLY GAME SNAPSHOT\n${lines.join("\n")}`;
    }
}

// Singleton instance for reuse across requests (performance optimization)
const timelineProcessor = new TimelineProcessor();
