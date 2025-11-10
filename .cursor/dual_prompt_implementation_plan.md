# Dual Prompt Implementation Plan

## Current State Analysis

### Edge Function (riot_ai.ts)
**Status**: ✅ **ALREADY SUPPORTS IT**
- Line 649: `const instructions = typeof body?.system === "string" ? body.system : ...`
- Line 722-724: Includes `instructions` in OpenAI payload if provided
- **No changes needed** to edge function

### iOS Client (Swift)

#### 1. CoachingPromptBuilder.swift
**Current**: Returns `String` (single prompt)
**Required**: Return `(system: String, user: String)` tuple

**Changes**:
- `createPostGamePrompt()` → return tuple instead of String
- `createPerformanceSummaryPrompt()` → return tuple instead of String
- Split existing prompt into system instructions + user data

#### 2. OpenAIService.swift
**Current**: Calls `createPostGamePrompt()` and passes single string
**Required**: Handle tuple, pass both system and user prompts

**Changes**:
- Capture tuple: `let (systemPrompt, userPrompt) = CoachingPromptBuilder.createPostGamePrompt(...)`
- Pass both to ProxyService

#### 3. ProxyService.swift
**Current**: Only sends `prompt` parameter
**Required**: Add optional `systemInstructions` parameter

**Changes**:
- Add parameter: `systemInstructions: String? = nil`
- Add to requestBody if provided: `if let sys = systemInstructions { requestBody["system"] = sys }`

---

## Required Changes Summary

### Files to Modify: 3
1. ✅ `SupabaseEdgeFunction/riot_ai.ts` - **NO CHANGES NEEDED**
2. 🔄 `Services/Coaching/CoachingPromptBuilder.swift` - **RETURN TYPE CHANGE + PROMPT SPLIT**
3. 🔄 `Services/Coaching/OpenAIService.swift` - **HANDLE TUPLE + PASS SYSTEM PROMPT**
4. 🔄 `Services/Proxy/ProxyService.swift` - **ADD OPTIONAL PARAMETER**

### Breaking Changes: NONE
- All changes are additive or backward compatible
- System prompt is optional (falls back to current behavior if not provided)

---

## Proposed System Prompt

```swift
let systemPrompt = """
You are an expert League of Legends coach specializing in ranked performance improvement.

**YOUR ROLE:**
- Analyze game performance data and provide actionable coaching advice
- Help players identify their biggest improvement opportunities
- Maintain a supportive but direct coaching style

**COACHING PRINCIPLES:**
1. ACTIONABLE: Every insight must be something the player can apply in their next game
2. SPECIFIC: Reference exact moments from timeline data when available
3. HONEST: Acknowledge both strengths and areas needing work
4. FOCUSED: Prioritize the player's declared improvement focus and poor-performing metrics

**TONE GUIDELINES:**
- Be conversational but professional - like a coach, not a textbook
- For wins: Celebrate but identify one growth opportunity
- For losses: Be constructive - explain what could be different next time
- Avoid: Gaming jargon, parentheses, numeric ranges in explanations
- Use: Clear language accessible to all skill levels

**OUTPUT REQUIREMENTS:**
- Format: ONLY valid JSON (no markdown, no extra text)
- Length: Maximum 110 words total across all fields
- Structure: Must include keyTakeaways (3), championSpecificAdvice (2 sentences), nextGameFocus (2)

**METRIC INTERPRETATION:**
When you see baseline comparisons:
- "Excellent" = significantly above average → praise and maintain
- "Good" = above average → acknowledge briefly
- "Needs Improvement" = below average → suggest specific practice focus
- "Poor" = significantly below average → make this a top priority

**FOCUS PRIORITY:**
1. Player's Improvement Focus (if provided) - ALWAYS address this
2. Metrics marked "Poor" - highest priority
3. Metrics marked "Needs Improvement" - secondary priority
4. NEVER suggest improving metrics marked "Good" or "Excellent"

**RELATIVE PERFORMANCE GUIDANCE:**
When analyzing team context:
- If player outperformed teammates in a loss → acknowledge their effort, suggest team play improvements
- If player underperformed compared to team → focus on their individual mistakes
- If player carried the team → celebrate leadership and impact
"""
```

---

## Test Strategy

### Phase 1: Manual API Test (BEFORE implementation)
Create a standalone test that calls the edge function with dual prompts to verify:
1. Edge function accepts both `system` and `prompt` parameters
2. OpenAI API processes the request correctly
3. Response quality improves with system prompt

### Phase 2: Implementation
1. Modify CoachingPromptBuilder.swift
2. Update OpenAIService.swift
3. Update ProxyService.swift
4. Test build

### Phase 3: Validation
1. Compare AI responses before/after
2. Verify JSON format compliance
3. Test with various match scenarios (win/loss, good/poor metrics)

---

## Risk Assessment

### LOW RISK:
- ✅ Edge function already supports it
- ✅ Changes are additive (backward compatible)
- ✅ Can rollback by not passing system prompt

### MEDIUM RISK:
- 🔶 System prompt needs careful tuning (can iterate)
- 🔶 Return type changes require updating all call sites

### MITIGATION:
- Test with real match data before deploying
- Keep system prompt in a constant for easy A/B testing
- Monitor AI response quality in production logs

---

## Estimated Timeline

- **Test Creation**: 30 minutes
- **Test Execution**: 15 minutes
- **Implementation**: 1.5 hours
- **Testing & Validation**: 30 minutes
- **Total**: ~2.5 hours

---

## Success Metrics

### Before (Single Prompt):
- Instructions mixed with data
- AI sometimes "forgets" JSON format rules
- Tone can be inconsistent
- Hard to update coaching philosophy

### After (Dual Prompt):
- Clear separation of instructions vs data
- More consistent JSON compliance
- Consistent coaching tone
- Easy to iterate on system prompt independently

