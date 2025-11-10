# 🚀 Quick Start: Testing Dual Prompt Structure

## TL;DR - What You Need to Know

✅ **Edge function already supports dual prompts** - no deployment needed for testing!

🧪 **We created a test** - verifies dual prompt improves response quality

📝 **3 files will need changes** - if test succeeds (1-2 hours work)

---

## 🎯 Before You Start

The test file (`DualPromptTest.swift`) needs to be **added to your Xcode project** manually.

### Why Manual Addition?
- The file was created but isn't in the Xcode project yet
- This is intentional - you should run the test first before committing to implementation

---

## 🧪 How to Run the Test

### ⭐ EASIEST METHOD: Run from the App

1. **Open Xcode**:
   ```bash
   cd /Users/niklasjohansson/Dev/Swift/IOS/Claimb
   open Claimb.xcodeproj
   ```

2. **Add Test View to Navigation** (temporary):
   - Open `ClaimbApp.swift` or any main view
   - Add this line somewhere you can navigate to it:
   ```swift
   NavigationLink("Test Dual Prompt") {
       DualPromptTestView()
   }
   ```

3. **Run the App** (Cmd + R)

4. **Navigate to "Test Dual Prompt"**

5. **Tap "Run Dual Prompt Test"**
   - Watch the test run
   - Review results directly in the app
   - Copy results with the "Copy" button

### Alternative: Run from Code

If you prefer, you can also call the test directly:

```swift
Task {
    let results = await DualPromptTest.runDualPromptTests()
    print(results.joined(separator: "\n"))
}
```

### What to Look For:

1. **Open the test results in the app**
2. **Look for**:
   - ✅ "JSON format valid"
   - ✅ "Response addresses 'Needs Improvement' metric"
   - 📊 Response length comparison
   - 📝 Full response text for both approaches

3. **Compare Quality**:
   - Does dual prompt focus on "Deaths" (Needs Improvement)?
   - Is the tone more coaching-like?
   - Does it follow the system instructions better?

---

## ⚠️ Troubleshooting

### "Cannot find 'ProxyService' in scope"
**Solution**: Make sure you added the file to **ClaimbTests** target, not **Claimb** target

### "API Key Missing" Error
**Solution**: Check `AppConfig.swift` - ensure you have valid Supabase credentials

### Test Times Out
**Solution**: 
1. Check internet connection
2. Verify Supabase edge function is deployed and running
3. Check Supabase dashboard for function errors

### Build Fails
**Solution**: Clean build folder (Cmd + Shift + K), then rebuild (Cmd + B)

---

## 📊 What to Expect

### Test Output Example:

```
🧪 Test 3: Comparison Test
==========================

📊 Single Prompt Length: 287 chars
📊 Dual Prompt Length: 294 chars

📝 Single Prompt Response:
{
  "keyTakeaways": [
    "Strong KDA shows good combat decisions",
    "CS per minute is solid",
    "Consider improving death count"
  ],
  ...
}

📝 Dual Prompt Response:
{
  "keyTakeaways": [
    "Excellent performance - you dominated with that KDA",
    "Your CS is above average, maintain this",
    "Deaths are your main improvement area - focus here next game"
  ],
  ...
}

✅ Comparison complete - review responses above
```

### Key Differences to Spot:

1. **Priority Focus**:
   - Single: May not prioritize "Needs Improvement" metric
   - Dual: Should clearly focus on "Deaths" as primary area

2. **Tone**:
   - Single: More generic, textbook-like
   - Dual: More coaching-like, personalized

3. **Structure**:
   - Single: May deviate from format occasionally
   - Dual: Should consistently follow JSON schema

4. **Actionability**:
   - Single: General advice
   - Dual: Specific, measurable suggestions

---

## ✅ Decision Time

### If Dual Prompt is BETTER → Proceed with Implementation

**Next Steps**:
1. Review implementation plan: `.cursor/dual_prompt_implementation_plan.md`
2. Implement changes (3 files to modify)
3. Test with real match data
4. Deploy and monitor

**Estimated Time**: 1.5-2 hours

### If NO CLEAR IMPROVEMENT → Refine System Prompt

**Next Steps**:
1. Modify the system prompt in `DualPromptTest.swift`
2. Re-run test
3. Iterate until improvement is clear

---

## 📁 Reference Files

All documentation is in `.cursor/` directory:

1. **TEST_INSTRUCTIONS.md** - Detailed testing guide
2. **dual_prompt_implementation_plan.md** - Complete implementation plan
3. **test_dual_prompt.sh** - Bash alternative (requires token config)
4. **QUICK_START_TESTING.md** - This file

---

## 🎯 Success Criteria

Proceed with implementation if:
- ✅ Both formats work without errors
- ✅ Dual prompt produces valid JSON consistently
- ✅ Dual prompt addresses "Needs Improvement" metrics clearly
- ✅ Tone is more coaching-like and consistent
- ✅ Structure follows system instructions more reliably

**Your call**: If 4/5 criteria met, it's worth implementing!

---

## 💡 Pro Tip

The system prompt in `DualPromptTest.swift` is a starting point. You can:
- Edit it to refine the coaching tone
- Add more specific instructions
- A/B test different approaches
- Iterate without touching production code

Once you find the optimal system prompt through testing, that's what we'll use in the implementation.

---

## Questions?

If anything is unclear:
1. Check the detailed plan: `.cursor/dual_prompt_implementation_plan.md`
2. Review test instructions: `.cursor/TEST_INSTRUCTIONS.md`
3. Ask! Better to clarify before implementing

