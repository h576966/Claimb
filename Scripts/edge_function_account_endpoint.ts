// Edge Function Code to Add: Account Endpoint
// Add this to your Supabase edge function to support account lookup by Riot ID

// ------------------ RIOT: Account by Riot ID ------------------
async function handleRiotAccount(req, deviceId) {
    const url = new URL(req.url);
    const gameName = url.searchParams.get("gameName");
    const tagLine = url.searchParams.get("tagLine");
    const region = url.searchParams.get("region") ?? "europe";
    
    if (!gameName || !tagLine) return badRequest("gameName and tagLine are required");
    
    const rl = await rateLimit(`riot:${deviceId}:account`, 60, 60);
    if (!rl.allowed) return json({ error: "rate_limited" }, 429, { "X-RateLimit-Remaining": "0" });
    
    // Convert region to correct format for account API
    const accountRegion = region === "europe" ? "europe" : 
                         region === "americas" ? "americas" : 
                         region === "asia" ? "asia" : "europe";
    
    const endpoint = `https://${accountRegion}.api.riotgames.com/riot/account/v1/accounts/by-riot-id/${encodeURIComponent(gameName)}/${encodeURIComponent(tagLine)}`;
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
            return json({ error: "riot_error", status: r.status }, r.status);
        }
        
        const account = await r.json();
        const shaped = {
            ...account,
            claimb_region: region,
            claimb_accountRegion: accountRegion
        };
        
        return json(shaped, 200, { 
            "X-Claimb-Shape": "account-raw+meta",
            "X-RateLimit-Remaining": String(rl.remaining ?? 0)
        });
    } catch (e) {
        if (e?.name === "AbortError") return json({ error: "upstream_timeout" }, 504);
        console.error("riot account fetch error", e);
        return json({ error: "upstream_error" }, 502);
    }
}

// Add this to your router section (in the main serve function):
if (req.method === "GET" && path.endsWith("/riot/account")) return handleRiotAccount(req, deviceId);

// Update your routes array to include:
routes: ["/riot/matches", "/riot/match", "/riot/summoner", "/riot/account", "/ai/coach"]
