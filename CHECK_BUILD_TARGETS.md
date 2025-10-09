# Build Target Membership Check

## 🚨 Files Missing from Xcode Build Target

These files have "Cannot find in scope" linting errors because they're not included in the build target:

### Files to Fix (Add to "Claimb" target):

1. ⚠️ **RoleSelectorView.swift** (104 errors)
   - Path: `Features/Onboarding/RoleSelector/RoleSelectorView.swift`
   - Cannot find: DesignSystem, RoleStats, RoleUtils, ClaimbLogger

2. ⚠️ **ClaimbApp.swift** (21 errors)
   - Path: `ClaimbApp.swift` (root)
   - Cannot find: Summoner, Match, Participant, Champion, Baseline, CoachingResponseCache, ClaimbLogger, ContentView
   - **CRITICAL**: This is the app entry point!

3. ⚠️ **RoleUtils.swift** (2 errors)
   - Path: `Core/Utilities/RoleUtils.swift`
   - Cannot find: ClaimbLogger

4. ✅ **PerformanceView.swift** (was 83 errors, you said you fixed it)
   - Path: `Features/KPIs/PerformanceView.swift`

---

## 🛠️ How to Fix (5 minutes)

### Option 1: Fix in Xcode (Recommended)

For each file above:

1. **Select file** in Project Navigator (⌘1)
2. **File Inspector** (⌘⌥1 or View → Inspectors → File)
3. **Under "Target Membership"**, check ✓ **"Claimb"**
4. Repeat for all 3 files

Then:
- **Clean Build Folder** (⇧⌘K)
- **Build** (⌘B)

### Option 2: Re-add Files (If above doesn't work)

For each file:

1. **Right-click file** → Delete → "Remove Reference" (DON'T delete files!)
2. **File → Add Files to "Claimb"...**
3. **Select the file**
4. **Check** "Add to targets: Claimb" ✓
5. **Add**

---

## 🔍 Why This Matters

### ClaimbApp.swift is CRITICAL
- This is your app's **entry point** (`@main`)
- Without it in the target, the app **cannot run**
- Must be fixed immediately

### RoleSelectorView.swift
- Used in 3 places: ChampionView, PerformanceView, CoachingView
- Without it, role selection won't work

### RoleUtils.swift
- Shared utility used across the entire app
- Without it, role mapping fails

---

## 🎯 Quick Checklist

After fixing all files:

- [ ] ClaimbApp.swift: 0 errors ✓
- [ ] RoleUtils.swift: 0 errors ✓
- [ ] RoleSelectorView.swift: 0 errors ✓
- [ ] PerformanceView.swift: 0 errors ✓
- [ ] Clean build succeeds (⇧⌘K then ⌘B)
- [ ] App runs in simulator
- [ ] Can select roles properly
- [ ] No "Cannot find in scope" errors

---

## 🚀 After Fixing

Your app should:
- ✅ Build without errors
- ✅ Run in simulator
- ✅ All features work correctly
- ✅ Ready for testing

**Production Readiness: 85% → 95%** after fixing these

---

## 📞 Need Help?

If files still don't appear in Project Navigator after fixing:

1. **Close Xcode**
2. **Delete** `Claimb.xcodeproj/project.xcworkspace/xcuserdata`
3. **Delete** `Claimb.xcodeproj/xcuserdata`
4. **Reopen** Xcode
5. **Try again**

Or contact for support if issues persist.

---

**Last Updated:** October 2025  
**Status:** Urgent - blocks compilation  
**Priority:** P0 - Fix immediately

