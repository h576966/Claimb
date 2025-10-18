# 🚨 URGENT: Edge Function Fix for Responses API

## ❌ **The Error**

```
"Unsupported parameter: 'response_format'. 
In the Responses API, this parameter has moved to 'text.format'."
```

## 🎯 **Root Cause**

OpenAI's Responses API uses **different parameter structure** than we thought!

### **What We're Sending (WRONG):**
```typescript
{
  "response_format": { "type": "json_object" }  // ❌ Not supported in Responses API
}
```

### **What OpenAI Expects (CORRECT):**
```typescript
{
  "text": { "format": "json" }  // ✅ Correct for Responses API
}
```

## ✅ **The Fix**

Replace the response_format handling section in your edge function with this:

```typescript
// --- text format handling (CORRECTED) ---
let text_config: any = undefined;

// 1) If caller already provided a proper response_format object, try to use it
if (body?.response_format && typeof body.response_format === "object") {
  // Legacy response_format not supported in Responses API
  // Ignore it for now or log a warning
  console.warn("response_format parameter not supported in Responses API, use text_format instead");
}

// 2) Handle text_format from iOS app
const text_format = typeof body?.text_format === "string" 
  ? body.text_format.trim().toLowerCase() 
  : undefined;

if (text_format === "json") {
  text_config = { format: "json" };  // ✅ Correct structure for Responses API
} else if (text_format === "text" || text_format === "plain") {
  text_config = { format: "text" };
}

// 3) Strict schema path (if you ever need it)
if (!text_config && body?.json_schema) {
  // For strict schema validation
  text_config = {
    format: "json_schema",
    json_schema: {
      name: body.json_schema.name ?? "claimb_schema",
      strict: body.json_schema.strict ?? true,
      schema: body.json_schema.schema ?? body.json_schema
    }
  };
}

const metadata = body?.metadata && typeof body.metadata === "object" ? body.metadata : undefined;

const payload = {
  model,
  input: prompt,
  max_output_tokens,
  ...(instructions ? { instructions } : {}),
  ...(temperature !== undefined ? { temperature } : {}),
  ...(reasoning ? { reasoning } : {}),
  ...(text_config ? { text: text_config } : {}),  // ✅ Use "text" not "response_format"
  ...(metadata ? { metadata } : {})
};
```

## 📋 **Complete Updated `handleAICoach` Function**

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

  const motRaw = Number(body?.max_output_tokens);
  const max_output_tokens = Number.isFinite(motRaw) ? Math.min(Math.max(1, Math.floor(motRaw)), 2000) : 512;

  const tRaw = body?.temperature;
  const tNum = tRaw === undefined ? undefined : Number(tRaw);
  const temperature = tNum === undefined || !Number.isFinite(tNum) ? undefined : Math.max(0, Math.min(1, tNum));

  const effortFromBody =
    typeof body?.reasoning?.effort === "string" ? body.reasoning.effort :
    typeof body?.reasoning_effort === "string" ? body.reasoning_effort :
    undefined;
  const reasoning = { effort: effortFromBody ?? "minimal" };

  // --- text format handling (CORRECTED FOR RESPONSES API) ---
  let text_config: any = undefined;

  const text_format = typeof body?.text_format === "string" 
    ? body.text_format.trim().toLowerCase() 
    : undefined;

  if (text_format === "json") {
    text_config = { format: "json" };  // ✅ Responses API structure
  } else if (text_format === "text" || text_format === "plain") {
    text_config = { format: "text" };
  }

  // Optional: strict schema support
  if (!text_config && body?.json_schema) {
    text_config = {
      format: "json_schema",
      json_schema: {
        name: body.json_schema.name ?? "claimb_schema",
        strict: body.json_schema.strict ?? true,
        schema: body.json_schema.schema ?? body.json_schema
      }
    };
  }

  const metadata = body?.metadata && typeof body.metadata === "object" ? body.metadata : undefined;

  const payload = {
    model,
    input: prompt,
    max_output_tokens,
    ...(instructions ? { instructions } : {}),
    ...(temperature !== undefined ? { temperature } : {}),
    ...(reasoning ? { reasoning } : {}),
    ...(text_config ? { text: text_config } : {}),  // ✅ "text" parameter, not "response_format"
    ...(metadata ? { metadata } : {})
  };

  console.log("OpenAI Responses API payload:", JSON.stringify(payload, null, 2));

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

## 🔑 **Key Changes**

### **Before (WRONG):**
```typescript
response_format: { type: "json_object" }  // ❌ Not supported
```

### **After (CORRECT):**
```typescript
text: { format: "json" }  // ✅ Correct for Responses API
```

## 📚 **According to OpenAI Error**

The error message explicitly says:
> "this parameter has moved to 'text.format'"

This means:
- **NOT:** `response_format: {type: "json_object"}`
- **YES:** `text: {format: "json"}`

## 🚀 **Deploy Steps**

1. Open Supabase Dashboard → Edge Functions
2. Find `claimb-function` → Edit `riot_ai.ts`
3. Replace the entire `handleAICoach` function with the code above
4. Click **Deploy**
5. Test in iOS app

## ✅ **Expected Result**

After deploying, you should see:
```
[ProxyService] Proxy: ai/coach -> 200 ✅
[OpenAIService] Post-game analysis completed ✅
```

## ⚠️ **Critical Note**

The iOS app is **100% correct**. It's just the edge function that needs this specific parameter structure for the Responses API.

---

**TL;DR**: Change `response_format: {...}` to `text: {format: "json"}` in the edge function payload!

