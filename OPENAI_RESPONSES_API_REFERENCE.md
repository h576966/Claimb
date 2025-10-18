# OpenAI Responses API - Reference Guide

**Last Updated:** October 18, 2025  
**Model:** `gpt-5-mini` (Responses API exclusive)  
**Documentation:** [OpenAI Responses API Docs](https://platform.openai.com/docs/api-reference/responses)

---

## ✅ Current Implementation Status

### iOS App → Edge Function → OpenAI Flow

```
iOS App (Swift)
    ↓ sends JSON body
Edge Function (Deno/TypeScript)
    ↓ transforms & validates
OpenAI Responses API
    ↓ returns response
Edge Function
    ↓ wraps response
iOS App
```

---

## 📤 iOS App Request Format

**File:** `Services/Proxy/ProxyService.swift`

```json
{
  "prompt": "GAME CONTEXT...",           // User prompt with data
  "system": "You are a coach...",        // System instructions
  "model": "gpt-5-mini",                 // Model name
  "max_output_tokens": 800,              // Token limit
  "temperature": 0.4,                    // Number (0-2)
  "text_format": "json",                 // String: "json" or "text"
  "reasoning": {                         // Nested format
    "effort": "low"                      // "minimal", "low", "medium", "high"
  }
}
```

---

## 🔄 Edge Function Transformation

**What the edge function MUST do:**

### 1. ✅ Text Format Mapping

```typescript
// iOS sends: text_format="json" (string)
const fmt = typeof body?.text_format === "string" 
  ? body.text_format.trim().toLowerCase() 
  : undefined;

// Map to Responses API format:
let text: any = undefined;

if (fmt === "json") {
  text = { format: "json" };  // ✅ String value
} else if (fmt === "text") {
  text = { format: "text" };  // ✅ String value
}

// For strict schemas (future use):
// text = { 
//   format: { 
//     type: "json_schema", 
//     json_schema: { name, strict, schema } 
//   } 
// };
```

### 2. ✅ System → Instructions

```typescript
const instructions = typeof body?.system === "string" 
  ? body.system 
  : undefined;
```

### 3. ✅ Keep These As-Is

```typescript
const model = body?.model;              // "gpt-5-mini"
const max_output_tokens = body?.max_output_tokens;  // 800
const temperature = body?.temperature;  // 0.4 (number)
const reasoning = body?.reasoning;      // { effort: "low" }
```

---

## 📨 Final OpenAI Payload

**What the edge function sends to OpenAI:**

```json
{
  "model": "gpt-5-mini",
  "input": "GAME CONTEXT...",
  "instructions": "You are a coach...",
  "max_output_tokens": 800,
  "temperature": 0.4,
  "reasoning": { "effort": "low" },
  "text": { "format": "json" }
}
```

---

## ⚠️ Critical Gotchas

### 1. ❌ DON'T Send `response_format`

```typescript
// ❌ WRONG - This is for Chat Completions API
{
  "response_format": { "type": "json_object" }
}

// ✅ CORRECT - Use text.format for Responses API
{
  "text": { "format": "json" }
}
```

### 2. ✅ Temperature Range & Coexistence

- **Range:** `0-2` (Responses API supports wider range than Chat Completions)
- **Type:** Must be a **number**, not a string
- **top_p:** Can be used alongside `temperature` if needed (0-1 range)
- **Current:** Using `0.4` for balanced consistency and variety

### 3. ✅ Token Parameter Name

```typescript
// ❌ WRONG - Chat Completions API name
"max_tokens": 800

// ✅ CORRECT - Responses API name
"max_output_tokens": 800
```

### 4. ✅ Text Format Shapes

```typescript
// Simple JSON mode (current use)
text: { format: "json" }  // ✅ String value

// Plain text mode
text: { format: "text" }  // ✅ String value

// Strict schema mode (for fixed structure)
text: { 
  format: { 
    type: "json_schema",
    json_schema: {
      name: "post_game_analysis",
      strict: true,
      schema: { /* JSON Schema */ }
    }
  }
}  // ✅ Object with nested structure
```

---

## 🎯 Supported Parameters (Responses API)

| Parameter | Type | Required | Notes |
|-----------|------|----------|-------|
| `model` | string | ✅ Yes | Must be `gpt-5-mini` |
| `input` | string | ✅ Yes | User prompt/data |
| `instructions` | string | ❌ No | System instructions (maps from `system`) |
| `max_output_tokens` | integer | ❌ No | Default: 512, Max: 2000 |
| `temperature` | number | ❌ No | Range: 0-2, Default: 1 |
| `top_p` | number | ❌ No | Range: 0-1, works with temperature |
| `reasoning` | object | ❌ No | `{ effort: "minimal" \| "low" \| "medium" \| "high" }` |
| `text` | object | ❌ No | `{ format: "json" \| "text" }` or schema object |
| `metadata` | object | ❌ No | Up to 16 key-value pairs |

---

## 🚫 Unsupported Parameters (Responses API)

These are **NOT** supported and will cause errors:

- ❌ `response_format` (use `text.format` instead)
- ❌ `max_tokens` (use `max_output_tokens` instead)
- ❌ `max_completion_tokens` (use `max_output_tokens` instead)
- ❌ `n` (number of completions)
- ❌ `stream` (streaming not supported)
- ❌ `stop` (stop sequences)
- ❌ `presence_penalty`
- ❌ `frequency_penalty`
- ❌ `logit_bias`
- ❌ `user`

---

## 📊 Reasoning Effort Levels

| Level | Use Case | Token Usage | Response Quality |
|-------|----------|-------------|------------------|
| `minimal` | Quick responses | Lowest | Fast, direct |
| `low` | **Current default** | Low | Good balance |
| `medium` | Complex analysis | Medium | More thorough |
| `high` | Deep reasoning | Highest | Most detailed |

**Current Usage:** `"low"` for post-game analysis and performance summaries.

---

## 🔧 Future Enhancements

### 1. Strict JSON Schema (for guaranteed structure)

Instead of free-form JSON mode, we could enforce exact structure:

```typescript
text: {
  format: {
    type: "json_schema",
    json_schema: {
      name: "post_game_analysis",
      strict: true,
      schema: {
        type: "object",
        properties: {
          keyTakeaways: { 
            type: "array", 
            items: { type: "string" } 
          },
          championSpecificAdvice: { type: "string" },
          nextGameFocus: { 
            type: "array", 
            items: { type: "string" } 
          }
        },
        required: ["keyTakeaways", "championSpecificAdvice", "nextGameFocus"],
        additionalProperties: false
      }
    }
  }
}
```

**Benefits:**
- Guaranteed structure every time
- No parsing errors from unexpected JSON shapes
- Type safety enforced at API level

### 2. top_p Sampling (if needed)

Could add `top_p` parameter for more fine-grained control:

```json
{
  "temperature": 0.4,
  "top_p": 0.9
}
```

**Note:** Both parameters can coexist. The model handles their interplay automatically.

---

## 📚 References

- [OpenAI Responses API Documentation](https://platform.openai.com/docs/api-reference/responses)
- [OpenAI Platform - Text Format](https://platform.openai.com/docs/guides/text-generation)
- [Microsoft Learn - OpenAI Responses](https://learn.microsoft.com/en-us/azure/ai-services/openai/how-to/responses)

---

## ✅ Verification Checklist

Before deploying edge function updates:

- [ ] `text_format: "json"` maps to `text: { format: "json" }` (string value)
- [ ] `system` maps to `instructions`
- [ ] `temperature` passed as number (not string)
- [ ] `max_output_tokens` (not `max_tokens`)
- [ ] `reasoning` object preserved as-is
- [ ] NO `response_format` parameter sent
- [ ] Model is `gpt-5-mini`

---

## 🐛 Common Errors & Solutions

### Error: "Unsupported parameter: 'response_format'"

**Cause:** Edge function sending Chat Completions parameter to Responses API  
**Solution:** Remove `response_format`, use `text.format` instead

### Error: "Invalid type for 'text.format': expected a text format, but got a string instead"

**Cause:** Incorrect nesting of text format  
**Solution:** Use `{ format: "json" }` not `{ format: { type: "json_object" } }`

### Error: "Unsupported parameter: 'temperature'"

**Cause:** Edge function incorrectly removing temperature  
**Solution:** Keep temperature parameter (it IS supported, range 0-2)

### Error: "Invalid type for 'temperature': expected a number"

**Cause:** Sending temperature as string  
**Solution:** Ensure temperature is sent as number (`0.4` not `"0.4"`)

---

## 📝 Change Log

**2025-10-18:**
- Cleaned up iOS request body (removed redundant `reasoning_effort`)
- Updated temperature from `0.3` to `0.4`
- Verified all parameters against official Responses API docs
- Created this reference document

**2025-10-17:**
- Implemented split system/user prompts
- Added JSON format enforcement via `text_format`
- Added reasoning effort control

**2025-10-16:**
- Initial Responses API integration
- Migrated from Chat Completions to Responses API format

