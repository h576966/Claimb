# PerformanceView Implementation Plan

## 🎯 **Overview**
Transform PerformanceView from a match list to a KPI-focused performance dashboard that shows role-specific metrics compared against baseline data.

## 📋 **Implementation Phases**

### **Phase 1: Basic Structure & Data Loading** 
*Goal: Get the foundation working with simple KPI display*

#### Step 1.1: Create KPI Data Structures
- [ ] Create `KPIMetric` struct with basic properties
- [ ] Create `PerformanceLevel` enum (poor, belowMean, good, excellent, unknown)
- [ ] Add display names and value formatting methods

#### Step 1.2: Basic PerformanceView Structure
- [ ] Keep existing role selector functionality
- [ ] Replace match list with simple KPI cards
- [ ] Maintain existing loading/error states
- [ ] Add performance overview card

#### Step 1.3: Simple KPI Calculation
- [ ] Calculate basic metrics (deaths per game, vision score/min, kill participation)
- [ ] Use hardcoded "ALL" classTag for baseline lookup
- [ ] Show raw values without baseline comparison initially
- [ ] Filter matches by selected role

### **Phase 2: Baseline Integration**
*Goal: Add baseline comparison and performance levels*

#### Step 2.1: Integrate Baseline Lookup
- [ ] Use `DataManager.getBaseline()` with role + "ALL" classTag
- [ ] Add performance level calculation (P40, mean, P60 thresholds)
- [ ] Implement color coding based on performance levels

#### Step 2.2: Champion Class Mapping
- [ ] Load champion class mapping from `champion_class_mapping_clean.json`
- [ ] Map champions to their classes using existing `DataManager.loadChampionClassMapping()`
- [ ] Use champion class as classTag for baseline lookup
- [ ] Fall back to "ALL" if specific class baseline not found

### **Phase 3: Role-Specific KPIs**
*Goal: Add role-specific metrics and improve calculation*

#### Step 3.1: Add Role-Specific KPI Logic
- [ ] CS per minute (all roles except support)
- [ ] Objective participation (jungle and support)
- [ ] Damage share percentage (mid and bottom)
- [ ] Damage taken share percentage (top)

#### Step 3.2: Improve KPI Calculation
- [ ] Average values across multiple games for selected role
- [ ] Handle edge cases (no data, division by zero)
- [ ] Use most common champion class for baseline lookup
- [ ] Add proper error handling

### **Phase 4: UI Polish & Optimization**
*Goal: Make it look great and perform well*

#### Step 4.1: Enhanced KPI Cards
- [ ] Better visual design with progress indicators
- [ ] Target vs actual comparison display
- [ ] Performance level indicators
- [ ] Smooth animations and transitions

#### Step 4.2: Performance Optimization
- [ ] Cache KPI calculations
- [ ] Async loading with proper state management
- [ ] Error handling improvements
- [ ] Memory optimization

## 🎨 **Design Specifications**

### **Color Coding System**
- **Poor** (< P40): Terracotta color (`DesignSystem.Colors.secondary`)
- **Below Average** (< mean): Yellow color (`DesignSystem.Colors.primary`)
- **Good** (< P60): White color (`DesignSystem.Colors.textPrimary`)
- **Excellent** (≥ P60): Teal color (`DesignSystem.Colors.accent`)

### **KPI Metrics by Role**
- **All Roles**: Deaths per Game, Vision Score/min, Kill Participation
- **Jungle/Support**: Objective Participation
- **All except Support**: CS per Minute
- **Mid/Bottom**: Damage Share
- **Top**: Damage Taken Share

### **UI Components**
- Performance Overview Card (games played, win rate)
- Individual KPI Cards with baseline comparison
- Role Selector (existing)
- Loading/Error states

## 🔧 **Technical Implementation**

### **Data Flow**
1. Load matches for summoner
2. Filter by selected role
3. Calculate KPI values for each game
4. Average values across games
5. Look up baseline data (role + classTag)
6. Determine performance level
7. Display with color coding

### **Key Files to Modify**
- `Claimb/Claimb/Views/PerformanceView.swift` - Main view implementation
- `Claimb/Claimb/Utils/DesignSystem.swift` - Color definitions (if needed)

### **Dependencies**
- Existing `DataManager` for baseline lookup
- Existing `RoleUtils` for role normalization
- Existing `Baseline` model
- Champion class mapping JSON file

## ✅ **Success Criteria**

### **Phase 1 Complete When:**
- [ ] PerformanceView shows KPI cards instead of match list
- [ ] Basic metrics are calculated and displayed
- [ ] Role selector works and filters data
- [ ] No build errors

### **Phase 2 Complete When:**
- [ ] Baseline data is loaded and compared
- [ ] Performance levels are calculated correctly
- [ ] Color coding works as specified
- [ ] Champion class mapping is integrated

### **Phase 3 Complete When:**
- [ ] All role-specific KPIs are implemented
- [ ] KPI calculation handles edge cases
- [ ] Data is properly averaged across games
- [ ] Most common champion class is used for baselines

### **Phase 4 Complete When:**
- [ ] UI is polished and visually appealing
- [ ] Performance is optimized
- [ ] Error handling is robust
- [ ] User experience is smooth

## 🚀 **Next Steps**
Start with Phase 1, Step 1.1 - Create KPI data structures and basic PerformanceView structure.
