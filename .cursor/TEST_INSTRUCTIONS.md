# Dual Prompt Testing Instructions

## 📋 Overview

Before implementing the dual prompt (system + user) structure, we need to verify it works correctly with your Supabase edge function and improves response quality.

---

## ✅ What We Know (No Changes Needed)

### Edge Function Already Supports Dual Prompts
The edge function (`riot_ai.ts`) already handles both formats:
- **Line 649**: `const instructions = typeof body?.system === "string" ? body.system : ...`
- **Line 722-724**: Includes `instructions` in OpenAI API payload

**Conclusion**: No edge function changes needed! ✅

---

## 🧪 Test Options

### Option 1: Swift Test in Xcode (RECOMMENDED)

#### Steps:
1. **Open Xcode Project**
   ```bash
   open /Users/niklasjohansson/Dev/Swift/IOS/Claimb/Claimb.xcodeproj
   ```

2. **Add Test File to Project**
   - In Xcode, right-click on `ClaimbTests` folder
   - Choose "Add Files to Claimb..."
   - Select `/Users/niklasjohansson/Dev/Swift/IOS/Claimb/ClaimbTests/DualPromptTest.swift`
   - Ensure "ClaimbTests" target is checked

3. **Run Tests**
   ```
   Cmd + U (Run all tests)
   ```
   
   Or run individual tests:
   - `testSinglePromptBaseline()` - Tests current single prompt
   - `testDualPromptWithSystemInstructions()` - Tests new dual prompt
   - `testCompareSingleVsDualPrompt()` - Compares both side-by-side

4. **Review Output**
   - Open Test Navigator (Cmd + 6)
   - Click on test to see console output
   - Compare response quality, JSON compliance, focus on improvements

#### What to Look For:
- ✅ Both tests complete without errors
- ✅ Both return valid JSON
- ✅ Dual prompt addresses "Deaths" (Needs Improvement metric)
- ✅ Dual prompt has better tone/focus than single prompt

---

### Option 2: Bash Test Script (Alternative)

If you prefer command-line testing:

#### Steps:
1. **Edit Configuration**
   ```bash
   nano /Users/niklasjohansson/Dev/Swift/IOS/Claimb/.cursor/test_dual_prompt.sh
   ```
   
   Replace `APP_TOKEN="your-app-token-here"` with your actual token from `AppConfig.swift`

2. **Run Test**
   ```bash
   cd /Users/niklasjohansson/Dev/Swift/IOS/Claimb
   ./.cursor/test_dual_prompt.sh
   ```

3. **Review Output**
   - Compare Single vs Dual prompt responses
   - Check JSON validity
   - Assess tone and focus differences

---

## 📊 Expected Results

### Single Prompt (Current):
```json
{
  "keyTakeaways": [
    "Great KDA shows strong combat decisions",
    "CS per minute is solid for your role",
    "Work on minimizing deaths to maintain gold lead"
  ],
  "championSpecificAdvice": "Your Aatrox mechanics look strong with that KDA. Focus on timing your engages better to reduce deaths.",
  "nextGameFocus": [
    "Reduce deaths by improving map awareness",
    "Aim for under 2 deaths per game"
  ]
}
```

### Dual Prompt (Expected Improvement):
```json
{
  "keyTakeaways": [
    "Excellent performance - you dominated with that KDA",
    "Your CS per minute is above average, keep it up",
    "Deaths are your biggest improvement area - focus here next game"
  ],
  "championSpecificAdvice": "Your Aatrox combat timing was strong. To improve, watch for overextending after kills - those 3 deaths likely came from pushing advantages too far.",
  "nextGameFocus": [
    "Track enemy jungle position before extending your lead",
    "Set a goal of maximum 2 deaths per game"
  ]
}
```

### Key Differences to Observe:
1. **Clearer Prioritization**: Dual prompt should clearly identify "Deaths" as the focus
2. **Consistent Tone**: More coaching-like, less robotic
3. **Better Structure**: Follows the system instructions more reliably
4. **Actionable Advice**: More specific suggestions tied to the metric

---

## 🚀 Next Steps After Testing

### If Test is Successful (Dual Prompt is Better):
1. ✅ Proceed with full implementation
2. ✅ Modify 3 Swift files (see implementation plan)
3. ✅ Deploy changes
4. ✅ Monitor AI response quality

### If Test Shows No Improvement:
1. ❌ Don't implement dual prompt yet
2. 🔧 Refine system prompt wording
3. 🧪 Re-test with improved system prompt
4. 📝 Document findings

---

## 📝 Files Created for Testing

1. **Implementation Plan**: `.cursor/dual_prompt_implementation_plan.md`
   - Complete analysis of required changes
   - Proposed system prompt
   - Risk assessment

2. **Swift Test**: `ClaimbTests/DualPromptTest.swift`
   - Three test methods
   - Compares single vs dual prompt
   - Validates JSON format

3. **Bash Test** (optional): `.cursor/test_dual_prompt.sh`
   - Command-line alternative
   - Requires manual token configuration

4. **This File**: `.cursor/TEST_INSTRUCTIONS.md`
   - Step-by-step testing guide

---

## ⚠️ Important Notes

1. **Tests Use Real OpenAI API**: These tests make actual API calls and will consume tokens
2. **Network Required**: Tests require internet connection and valid API key
3. **No Code Changes Yet**: Tests use a temporary extension method, no production code is modified
4. **Safe to Run**: Tests don't affect existing functionality

---

## 🎯 Success Criteria

The dual prompt implementation is worth pursuing if:
- ✅ Both test formats work (no errors)
- ✅ Dual prompt consistently produces valid JSON
- ✅ Dual prompt better addresses "Needs Improvement" metrics
- ✅ Tone is more consistent and coaching-like
- ✅ Responses are equally or more concise

If **all criteria met** → Proceed with implementation
If **any criteria not met** → Refine system prompt and re-test

---

## Questions?

If tests fail or results are unclear:
1. Check Xcode console for detailed error messages
2. Review edge function logs in Supabase dashboard
3. Verify API key is valid and has sufficient credits
4. Compare JSON output structure between single/dual responses

