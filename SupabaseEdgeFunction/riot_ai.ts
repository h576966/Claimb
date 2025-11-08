// riot_ai.ts
// deno-lint-ignore-file no-explicit-any
import { OPENAI_KEY, RIOT_KEY, HAS_RIOT_KEY, HAS_OPENAI_KEY, json, badRequest, rateLimit, timeoutSignal, assertRegionOrPlatform, deriveRegionFromPlatform, parsePositiveInt, parseEpochSeconds } from "./shared.ts";
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
            const sliced = events.filter((e) => (e.timestamp ?? 0) <= ms && e.type === "CHAMPION_KILL");
            const k = sliced.filter((e) => e.killerId === pid).length;
            const d = sliced.filter((e) => e.victimId === pid).length;
            const a = sliced.reduce((sum, e) => sum + ((e.assistingParticipantIds ?? []).includes(pid) ? 1 : 0), 0);
            return {
                k,
                d,
                a
            };
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
        const firstBackMs = events.find((e) => (e.type === "ITEM_PURCHASED" || e.type === "ITEM_UNDO") && e.participantId === pid && (e.timestamp ?? 0) > 120_000)?.timestamp ?? null;
        const firstKillMs = events.find((e) => e.type === "CHAMPION_KILL" && e.killerId === pid)?.timestamp ?? null;
        const firstDeathMs = events.find((e) => e.type === "CHAMPION_KILL" && e.victimId === pid)?.timestamp ?? null;
        const platesPre14 = events.filter((e) => e.type === "TURRET_PLATE_DESTROYED" && (e.killerId === pid || (e.assistingParticipantIds ?? []).includes(pid)) && (e.timestamp ?? 0) <= 14 * 60_000).length;
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
            console.warn("riot league entries error", await r.text().catch(() => ""));
            return json({ error: "riot_error", status: r.status }, r.status);
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
        // First get summoner to get summonerId
        const summonerEndpoint = `https://${plat}.api.riotgames.com/lol/summoner/v4/summoners/by-puuid/${encodeURIComponent(puuid)}`;
        const summonerRes = await fetch(summonerEndpoint, {
            headers: { "X-Riot-Token": RIOT_KEY },
            signal: to.signal
        });

        if (!summonerRes.ok) {
            console.warn("riot summoner for league lookup error", await summonerRes.text().catch(() => ""));
            return json({ error: "riot_error", status: summonerRes.status }, summonerRes.status);
        }

        const summoner = await summonerRes.json();
        const summonerId = summoner.id;

        // Then get league entries
        const leagueEndpoint = `https://${plat}.api.riotgames.com/lol/league/v4/entries/by-summoner/${encodeURIComponent(summonerId)}`;
        const leagueRes = await fetch(leagueEndpoint, {
            headers: { "X-Riot-Token": RIOT_KEY },
            signal: to.signal
        });

        to.clear();

        if (!leagueRes.ok) {
            console.warn("riot league entries by puuid error", await leagueRes.text().catch(() => ""));
            return json({ error: "riot_error", status: leagueRes.status }, leagueRes.status);
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
    const instructions = typeof body?.system === "string" ? body.system : typeof body?.instructions === "string" ? body.instructions : undefined;
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

    // Fetch and inject timeline data if match metadata is provided
    let enhancedPrompt = prompt;
    if (matchId && puuid && regionOrPlatform) {
        try {
            const timelineData = await fetchTimelineLiteForPrompt(matchId, puuid, regionOrPlatform);
            if (timelineData) {
                const formatted = formatTimelineForPrompt(timelineData);
                enhancedPrompt = prompt + "\n\n**TIMELINE:** " + formatted + "\nFocus on: Early game checkpoints, timing efficiency, resource advantages.";
                console.log("Timeline data injected for match:", matchId);
            }
        } catch (err) {
            // Log but don't fail - timeline is optional enhancement
            console.warn("Timeline fetch failed, continuing without timeline:", err?.message || err);
        }
    }

    const payload = {
        model,
        input: enhancedPrompt,
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

    // Debug logging for OpenAI payload
    console.log("OpenAI Responses API payload:", JSON.stringify(payload, null, 2));
    const to = timeoutSignal(20_000);
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
        if (e?.name === "AbortError") return json({
            error: "upstream_timeout"
        }, 504);
        console.error("openai responses fetch error", e);
        return json({
            error: "upstream_error"
        }, 502);
    }
}

/* =========== Helper: Fetch Timeline for Prompt Enhancement =========== */
async function fetchTimelineLiteForPrompt(matchId, puuid, regionOrPlatform) {
    if (!HAS_RIOT_KEY) return null;

    // Resolve region from platform if needed
    let region = regionOrPlatform;
    if (SUPPORTED_PLATFORMS.has(regionOrPlatform?.toLowerCase())) {
        region = PLATFORM_TO_REGION[regionOrPlatform.toLowerCase()];
    }

    // Validate region
    const validRegions = new Set(Object.values(PLATFORM_TO_REGION));
    if (!validRegions.has(region?.toLowerCase())) {
        console.warn("Invalid region for timeline:", regionOrPlatform);
        return null;
    }

    const endpoint = `https://${region}.api.riotgames.com/lol/match/v5/matches/${encodeURIComponent(matchId)}/timeline`;
    const to = timeoutSignal(5000); // 5 second timeout for timeline

    try {
        const r = await fetch(endpoint, {
            headers: {
                "X-Riot-Token": RIOT_KEY
            },
            signal: to.signal
        });
        to.clear();

        if (!r.ok) {
            console.warn("Riot timeline API error:", r.status);
            return null;
        }

        const tl = await r.json();
        const pid = (tl?.metadata?.participants?.indexOf?.(puuid) ?? -1) + 1;
        if (pid <= 0) {
            console.warn("PUUID not found in timeline match");
            return null;
        }

        const frames = tl?.info?.frames ?? [];
        const events = frames.flatMap((f) => f?.events ?? []);
        const frameInterval = tl?.info?.frameInterval || 60_000;
        const idxAt = (ms) => Math.max(0, Math.floor(ms / frameInterval));
        const minOf = (ms) => typeof ms === "number" && isFinite(ms) ? Math.round(ms / 60_000) : null;

        function kdaAt(ms) {
            const sliced = events.filter((e) => (e.timestamp ?? 0) <= ms && e.type === "CHAMPION_KILL");
            const k = sliced.filter((e) => e.killerId === pid).length;
            const d = sliced.filter((e) => e.victimId === pid).length;
            const a = sliced.reduce((sum, e) => sum + ((e.assistingParticipantIds ?? []).includes(pid) ? 1 : 0), 0);
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
                a,
                kda: `${k}/${d}/${a}`
            };
        }

        const at10 = snapAt(10 * 60_000);
        const at15 = snapAt(15 * 60_000);
        const firstBackMs = events.find((e) => (e.type === "ITEM_PURCHASED" || e.type === "ITEM_UNDO") && e.participantId === pid && (e.timestamp ?? 0) > 120_000)?.timestamp ?? null;
        const firstKillMs = events.find((e) => e.type === "CHAMPION_KILL" && e.killerId === pid)?.timestamp ?? null;
        const firstDeathMs = events.find((e) => e.type === "CHAMPION_KILL" && e.victimId === pid)?.timestamp ?? null;
        const platesPre14 = events.filter((e) => e.type === "TURRET_PLATE_DESTROYED" && (e.killerId === pid || (e.assistingParticipantIds ?? []).includes(pid)) && (e.timestamp ?? 0) <= 14 * 60_000).length;

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
    } catch (err) {
        if (err?.name === "AbortError") {
            console.warn("Timeline fetch timeout");
        } else {
            console.error("Timeline fetch error:", err);
        }
        return null;
    }
}

function formatTimelineForPrompt(data) {
    if (!data) return "";

    const c10 = data.checkpoints?.["10min"];
    const c15 = data.checkpoints?.["15min"];
    const t = data.timings;

    if (!c10 || !c15) return "";

    let result = `10min: ${c10.cs} CS (${c10.kda}), ${c10.gold}g | 15min: ${c15.cs} CS (${c15.kda}), ${c15.gold}g`;

    // Add timings if available
    const timings = [];
    if (t.firstBackMin) timings.push(`First back: ${t.firstBackMin}min`);
    if (t.firstKillMin) timings.push(`First kill: ${t.firstKillMin}min`);
    if (t.firstDeathMin) timings.push(`First death: ${t.firstDeathMin}min`);

    if (timings.length > 0) {
        result += ` | ${timings.join(", ")}`;
    }

    if (data.platesPre14 > 0) {
        result += ` | Turret plates: ${data.platesPre14}`;
    }

    return result;
}
