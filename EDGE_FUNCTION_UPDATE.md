# Edge Function Update for Responses API

## Overview
The iOS app now uses OpenAI's **Responses API** format with `text.format` instead of the legacy `response_format` parameter. Your Supabase edge function needs a small update to support this.

## What Changed in the App

### Before (Legacy Format - ❌ Doesn't work with gpt-5-mini)
```swift
responseFormat: ["type": "json_object"]  // Old Chat Completions API
```

### After (Responses API Format - ✅ Works with gpt-5-mini)
```swift
textFormat: "json"  // New Responses API
```

## Edge Function Updates Required

### 1. Update Request Body Parsing

**Location:** Your `ai/coach` endpoint in Supabase edge function

**Before:**
```typescript
const { 
  prompt, 
  system, 
  model, 
  max_output_tokens, 
  temperature, 
  response_format,  // ❌ Old parameter
  reasoning_effort 
} = await req.json();
```

**After:**
```typescript
const { 
  prompt, 
  system, 
  model, 
  max_output_tokens, 
  temperature, 
  text_format,  // ✅ New parameter from iOS app
  reasoning_effort 
} = await req.json();
```

### 2. Map to OpenAI's Responses API Format

**Before:**
```typescript
const payload = {
  model,
  input: prompt,
  instructions: system,
  max_output_tokens,
  temperature,
  response_format: response_format,  // ❌ Wrong for Responses API
  reasoning: { effort: reasoning_effort }
};
```

**After:**
```typescript
const payload = {
  model,
  input: prompt,
  instructions: system,
  max_output_tokens,
  temperature,
  ...(text_format ? { text: { format: text_format } } : {}),  // ✅ Correct format
  ...(reasoning_effort ? { reasoning: { effort: reasoning_effort } } : {})
};
```

### 3. Complete Example

```typescript
// Edge function: /functions/claimb-function/ai/coach
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

serve(async (req) => {
  try {
    // Parse request from iOS app
    const { 
      prompt, 
      system, 
      model, 
      max_output_tokens, 
      temperature,
      text_format,        // New parameter
      reasoning_effort 
    } = await req.json();

    // Build payload for OpenAI Responses API
    const payload = {
      model: model || "gpt-5-mini",
      input: prompt,
      max_output_tokens: max_output_tokens || 1000,
    };

    // Add optional parameters
    if (system) {
      payload.instructions = system;  // System prompt → instructions
    }

    if (temperature !== undefined && temperature !== null) {
      payload.temperature = temperature;
    }

    // Add text format for JSON enforcement (Responses API)
    if (text_format) {
      payload.text = { format: text_format };  // "json" → {format: "json"}
    }

    // Add reasoning effort for gpt-5 models
    if (reasoning_effort && model.includes("gpt-5")) {
      payload.reasoning = { effort: reasoning_effort };  // "low", "medium", "high"
    }

    // Call OpenAI Responses API
    const response = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${Deno.env.get("OPENAI_API_KEY")}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      const errorBody = await response.text();
      console.error("OpenAI API error:", errorBody);
      
      return new Response(
        JSON.stringify({
          error: "openai_error",
          status: response.status,
          detail: errorBody
        }),
        { status: response.status, headers: { "Content-Type": "application/json" } }
      );
    }

    const data = await response.json();
    
    // Extract text from Responses API format
    let text = "";
    if (data.output && Array.isArray(data.output)) {
      // Responses API format
      for (const item of data.output) {
        if (item.type === "message" && item.content) {
          for (const content of item.content) {
            if (content.type === "text") {
              text += content.text;
            }
          }
        } else if (item.type === "reasoning" && item.text) {
          // Skip reasoning text, only use final output
        }
      }
    } else if (data.choices && data.choices[0]?.message?.content) {
      // Fallback to Chat Completions format
      text = data.choices[0].message.content;
    } else if (data.output_text) {
      // Direct output_text field
      text = data.output_text;
    }

    return new Response(
      JSON.stringify({
        text: text,
        model: data.model || model
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );

  } catch (error) {
    console.error("Edge function error:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
```

## Testing Checklist

After updating your edge function:

1. ✅ Deploy the edge function to Supabase
2. ✅ Test with gpt-5-mini model
3. ✅ Verify `text_format: "json"` is properly mapped
4. ✅ Check that JSON responses are valid
5. ✅ Verify reasoning effort is working for gpt-5 models

## Expected Request from iOS App

```json
{
  "prompt": "User data and context here...",
  "system": "You are a League of Legends coach...",
  "model": "gpt-5-mini",
  "max_output_tokens": 800,
  "temperature": 0.3,
  "text_format": "json",
  "reasoning_effort": "low"
}
```

## Expected Response to iOS App

```json
{
  "text": "{\"keyTakeaways\": [...], \"championSpecificAdvice\": \"...\", \"nextGameFocus\": [...]}",
  "model": "gpt-5-mini"
}
```

## Troubleshooting

### Error: "Unsupported parameter: 'response_format'"
- ✅ **Fixed!** You updated the iOS app to use `text_format`
- Now update edge function to map `text_format` → `text: {format: "json"}`

### Error: "Invalid request"
- Check that `text` field is an object: `{format: "json"}`
- Not a string: ~~`"json"`~~

### No JSON in response
- Verify `text_format` is being passed through
- Check OpenAI response structure extraction logic
- Ensure prompt instructs to return JSON

## References

- [OpenAI Responses API Documentation](https://platform.openai.com/docs/api-reference/responses/create)
- [Structured Outputs Guide](https://platform.openai.com/docs/guides/structured-outputs)

