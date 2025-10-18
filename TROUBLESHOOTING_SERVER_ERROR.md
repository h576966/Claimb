# Troubleshooting: Server Error in Coaching

## 🔍 **Current Issue**

Post-Game Analysis and Performance Summary both fail with:
```
Analysis Failed
Server error. Please try again.
```

## 🎯 **Root Cause**

The edge function on Supabase **has not been updated** with the new `handleAICoach` implementation that supports `text_format` parameter.

### **What's Happening**

1. **iOS App sends:**
   ```json
   {
     "prompt": "...",
     "system": "...",
     "model": "gpt-5-mini",
     "text_format": "json",  // ← NEW parameter
     "reasoning_effort": "low"
   }
   ```

2. **Old edge function doesn't know about `text_format`:**
   - Doesn't map it to `response_format: {type: "json_object"}`
   - Either ignores it or sends invalid payload to OpenAI
   - OpenAI returns error or edge function crashes

3. **Result:** HTTP 400 or 500 error → "Server error" message

## ✅ **Solution**

Deploy the updated `handleAICoach` function to your Supabase edge function.

### **Step-by-Step Fix**

#### **1. Open Your Supabase Edge Function**

Go to: Supabase Dashboard → Edge Functions → `claimb-function` → Edit `riot_ai.ts`

#### **2. Replace the `handleAICoach` Function**

Replace the entire function with this updated version:

```typescript
export async function handleAICoach(req, deviceId) {
  const rl = await rateLimit(`ai:${deviceId}:coach`, 30, 60);
  if (!rl.allowed) return json({ error: "rate_limited" }, 429, { "X-RateLimit-Remaining": "0" });

  let body;
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }

  const prompt = typeof body?.prompt === "string" ? body.prompt : "";
  if (!prompt) return json({ error: "prompt required" }, 400);

  const model = (typeof body?.model === "string" ? body.model : "gpt-5-mini").trim();
  if (model !== "gpt-5-mini") return json({ error: "model not allowed" }, 400);
  if (!HAS_OPENAI_KEY) return json({ error: "openai_key_missing" }, 500);

  const instructions =
    typeof body?.system === "string" ? body.system :
    typeof body?.instructions === "string" ? body.instructions :
    undefined;

  // max_output_tokens: coerce and clamp
  const motRaw = Number(body?.max_output_tokens);
  const max_output_tokens = Number.isFinite(motRaw) ? Math.min(Math.max(1, Math.floor(motRaw)), 2000) : 512;

  // temperature: coerce and clamp [0,1]
  const tRaw = body?.temperature;
  const tNum = tRaw === undefined ? undefined : Number(tRaw);
  const temperature = tNum === undefined || !Number.isFinite(tNum) ? undefined : Math.max(0, Math.min(1, tNum));

  // reasoning effort: default minimal
  const effortFromBody =
    typeof body?.reasoning?.effort === "string" ? body.reasoning.effort :
    typeof body?.reasoning_effort === "string" ? body.reasoning_effort :
    undefined;
  const reasoning = { effort: effortFromBody ?? "minimal" };

  // --- response_format handling (CRITICAL FIX) ---
  let response_format: any = undefined;

  // 1) If caller already provided a proper response_format object, keep it
  if (body?.response_format && typeof body.response_format === "object") {
    response_format = body.response_format;

  // 2) Shim for iOS app param: text_format
  } else {
    const text_format = typeof body?.text_format === "string" 
      ? body.text_format.trim().toLowerCase() 
      : undefined;

    // iOS sends "json" -> use free-form JSON mode
    if (text_format === "json") {
      response_format = { type: "json_object" };

    // Optional: if you ever want to explicitly force plain text
    } else if (text_format === "text" || text_format === "plain") {
      response_format = { type: "text" };
    }
  }

  // 3) Strict schema path (optional, for future use)
  if (!response_format && body?.json_schema) {
    if (body.json_schema.schema) {
      response_format = {
        type: "json_schema",
        json_schema: {
          name: body.json_schema.name ?? "claimb_schema",
          strict: body.json_schema.strict ?? true,
          schema: body.json_schema.schema
        }
      };
    } else if (typeof body.json_schema === "object") {
      response_format = {
        type: "json_schema",
        json_schema: {
          name: "claimb_schema",
          strict: true,
          schema: body.json_schema
        }
      };
    }
  }

  const metadata = body?.metadata && typeof body.metadata === "object" ? body.metadata : undefined;

  const payload = {
    model,
    input: prompt,
    max_output_tokens,
    ...(instructions ? { instructions } : {}),
    ...(temperature !== undefined ? { temperature } : {}),
    ...(reasoning ? { reasoning } : {}),
    ...(response_format ? { response_format } : {}),
    ...(metadata ? { metadata } : {})
  };

  // Log payload for debugging (optional, remove in production)
  console.log("OpenAI payload:", JSON.stringify(payload, null, 2));

  const to = timeoutSignal(20000);
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
      return json({ error: "openai_error", status: r.status, detail: errText }, r.status);
    }

    const data = await r.json();
    const { text, parsed } = extractOpenAIResult(data);

    return json(
      parsed !== undefined ? { text, model, parsed } : { text, model },
      200,
      {
        "X-Claimb-Shape": parsed !== undefined ? "coach-text+parsed" : "coach-text",
        "X-RateLimit-Remaining": String(rl.remaining ?? 0)
      }
    );
  } catch (e) {
    if (e?.name === "AbortError") return json({ error: "upstream_timeout" }, 504);
    console.error("openai responses fetch error", e);
    return json({ error: "upstream_error" }, 502);
  }
}
```

#### **3. Deploy the Edge Function**

Click **Deploy** or use the Supabase CLI:
```bash
supabase functions deploy claimb-function
```

#### **4. Test in the iOS App**

1. Force quit the app
2. Relaunch
3. Go to Coaching tab
4. The post-game analysis should now work!

## 🔍 **How to Verify It's Working**

### **In Xcode Console, Look For:**

**Before fix (error):**
```
[ProxyService] Proxy: ai/coach -> 400
[ProxyService] Proxy: AI coach returned error | errorBody={"error":"..."}
```

**After fix (success):**
```
[ProxyService] Proxy: ai/coach -> 200
[ProxyService] Retrieved AI coaching response (Responses API - output_text)
[OpenAIService] Post-game analysis completed
```

## 📋 **Quick Verification Checklist**

- [ ] Edge function deployed with updated `handleAICoach`
- [ ] `text_format` parameter is mapped to `response_format: {type: "json_object"}`
- [ ] OpenAI API key is set in Supabase environment variables
- [ ] iOS app is running the latest code (commit: 8d46b79)
- [ ] Xcode console shows successful 200 response

## 🐛 **If It Still Doesn't Work**

### **Check Supabase Logs**

1. Go to Supabase Dashboard → Logs → Edge Functions
2. Look for errors around the time you tried the coaching
3. Share the error logs for further diagnosis

### **Check OpenAI Response**

If you see in edge function logs:
```
openai responses error 400 {...}
```

The issue is with the OpenAI API call. Check:
- Is `response_format` being set correctly?
- Is the OpenAI API key valid?
- Is gpt-5-mini available?

## 📚 **Related Files**

- iOS App: `Services/Proxy/ProxyService.swift`
- iOS App: `Services/Coaching/OpenAIService.swift`
- Edge Function: `riot_ai.ts` → `handleAICoach` function
- Documentation: `EDGE_FUNCTION_UPDATE.md`

## 💡 **Key Takeaway**

The iOS app is **already correct**. The issue is that the edge function needs to be updated to handle the `text_format` parameter and map it to the proper `response_format` structure for OpenAI's Responses API.

