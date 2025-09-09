# Claimb iOS Implementation Context

## 🎯 **Project Overview**
- **App**: Claimb - League of Legends companion app for iPhone
- **Focus**: Post-game coaching, Champion Pool guidance, Home insights
- **Architecture**: Local-first with SwiftData, no backend
- **Target**: iOS 17+, Swift 6

## 📋 **Implementation Plan**

### **Phase 1: Core Riot API Service (MVP) - ✅ COMPLETED**
**Goal**: Get basic data flowing from Riot APIs with proper caching

#### **Step 1.1: Essential Models ✅ COMPLETED**
- [x] Summoner: `puuid`, `gameName`, `tagLine`, `region`
- [x] Match: `matchId`, `gameCreation`, `gameDuration`, `queueId`, `gameVersion`
- [x] Participant: `puuid`, `championId`, `kills`, `deaths`, `assists`, `win`, `lane`
- [x] Champion: `id`, `name`, `title` (from Data Dragon)
- [x] Baseline: Performance metrics and ranges for coaching analysis

#### **Step 1.2: Riot API Client ✅ COMPLETED**
- [x] Rate limiter: Simple 1.2s delay between requests
- [x] Error handling: Basic retry (3 attempts with exponential backoff)
- [x] Caching: URLCache for GET requests (automatic disk caching)
- [x] Endpoints: Account lookup, match history, match details
- [x] Region conversion: Proper routing for all Riot API endpoints

#### **Step 1.3: API Testing & Debugging ✅ COMPLETED**
- [x] Created `RiotAPITestView.swift` for interactive testing
- [x] Added comprehensive logging for request/response debugging
- [x] Fixed region conversion issue (asia → kr for summoner-v4 and match-v5)
- [x] Fixed match history JSON parsing (array response handling)
- [x] Added response body logging for successful and failed requests
- [x] Fixed summoner response parsing with flexible decoding
- [x] Identified API key permission limitations (403 errors)
- [x] Confirmed working endpoints: Account (asia), Summoner (kr)
- [x] Identified failing endpoints: Match History (403), EUW region (403)

#### **Step 1.4: Account-v1 Regional Endpoint Fix ✅ COMPLETED**
- [x] Identified Account-v1 uses different regional endpoints (europe, americas, asia)
- [x] Added `convertToAccountEndpoint()` function for proper Account-v1 routing
- [x] Updated `buildAccountURL()` to use correct regional endpoints
- [x] Fixed EUW region routing: euw1 → europe.api.riotgames.com
- [x] Fixed NA region routing: na1 → americas.api.riotgames.com
- [x] Fixed Asia region routing: asia → asia.api.riotgames.com

#### **Step 1.5: Match-v5 Regional Endpoint Fix ✅ COMPLETED**
- [x] Identified Match-v5 uses same regional endpoints as Account-v1 (europe, americas, asia)
- [x] Updated `buildMatchHistoryURL()` to use correct regional endpoints
- [x] Updated `buildMatchURL()` to use correct regional endpoints
- [x] Fixed Match History routing: euw1 → europe.api.riotgames.com
- [x] Fixed Match Details routing: euw1 → europe.api.riotgames.com
- [x] All Riot API endpoints now use correct regional routing

#### **Step 1.6: Test View Default Values Update ✅ COMPLETED**
- [x] Updated default test values to PastMyBedTime#8778 (EUW)
- [x] Removed Asia region option from test view
- [x] Updated test tips to reflect new defaults and region support
- [x] App now focuses on EUW, NA, and EUNE regions only (iPhone user focus)
- [x] Test view ready for immediate testing with working account

#### **Step 1.7: Data Dragon Integration ✅ COMPLETED**
- [x] Created DataDragonService for managing static game data
- [x] Champion data: Fetch and cache locally on first launch
- [x] Icons: On-demand loading with URLCache
- [x] Version management: Lock to match's patch version
- [x] Updated Champion model with Data Dragon integration
- [x] Created DataDragonTestView for testing integration
- [x] Added comprehensive error handling and caching

### **Phase 2: SwiftData Integration - ✅ COMPLETED**
**Goal**: Persistent storage with offline capability

#### **Step 2.1: SwiftData Setup ✅ COMPLETED**
- [x] Container: Single container with all models (Summoner, Match, Participant, Champion, Baseline)
- [x] Relationships: Summoner → Matches → Participants
- [x] Caching: 50 matches per summoner limit
- [x] DataManager: Central service for SwiftData operations

#### **Step 2.2: Offline Strategy ✅ COMPLETED**
- [x] Cache-first: Always check local data first
- [x] Background refresh: Every 20 minutes
- [x] Manual refresh: Pull-to-refresh or button
- [x] Clear cache functionality for debugging

### **Phase 3: Basic UI - ✅ COMPLETED**
**Goal**: User interface for login and match history display

#### **Step 3.1: Login Screen ✅ COMPLETED**
- [x] Summoner Name and Tag Line input fields
- [x] Region dropdown (EUW, NA, EUNE)
- [x] Login logic with DataManager integration
- [x] Loading states and error handling
- [x] Navigation to main app on successful login

#### **Step 3.2: Match History Display ✅ COMPLETED**
- [x] Last 5 matches with basic info
- [x] Champion names, KDA, Win/Loss, Duration
- [x] Manual and background refresh
- [x] Loading states and error handling
- [x] MatchCardView for individual match display

#### **Step 3.3: Champion Data Integration 🔄 IN PROGRESS**
- [x] Enhanced champion lookup logic with ID and Key fallback matching
- [x] Created ChampionTestView for debugging champion data
- [x] Champion data loading from Data Dragon (171 champions loaded)
- [ ] **ISSUE**: "Unknown Champion" still displaying in UI
- [ ] **ISSUE**: "Unknown" match results still showing
- [ ] Champion names not displaying correctly in match cards
- [ ] Champion icons not loading properly

## 🔧 **Technical Decisions Made**

### **Data Models**
- **Summoner**: Core identity with Riot ID (gameName + tagLine)
- **Match**: Essential match metadata for coaching analysis
- **Participant**: Performance data for individual players
- **Champion**: Static data from Data Dragon API
- **Baseline**: Performance metrics and ranges for coaching analysis

### **API Strategy**
- **Rate Limiting**: Simple 1.2s delay (no complex queuing)
- **Error Handling**: Basic retry with exponential backoff
- **Caching**: URLCache for automatic disk caching
- **Offline**: Cache-first approach with background refresh
- **Region Conversion**: Proper routing for all Riot API endpoints

### **Scope Constraints**
- **Game Modes**: Only Ranked Solo/Duo, Ranked Flex, Normal/Draft
- **Regions**: EUW, NA, EUNE only
- **Match Limit**: 50 matches cached per summoner
- **Champion Pool**: Show 4 champions by default

## 🚀 **Current Status**
- **Models**: ✅ COMPLETED - All 5 models implemented with proper relationships
- **API Client**: ✅ COMPLETED - RiotClient protocol + RiotHTTPClient with rate limiting & region conversion
- **API Testing**: ✅ COMPLETED - Interactive test interface with comprehensive logging & error handling
- **API Fixes**: ✅ COMPLETED - Fixed region conversion & match history parsing issues
- **Data Dragon**: ✅ COMPLETED - Champion data integration with versioning
- **SwiftData**: ✅ COMPLETED - Persistent storage with offline capability
- **Basic UI**: ✅ COMPLETED - Login screen and match history display
- **Champion Integration**: 🔄 IN PROGRESS - "Unknown Champion" issue still present

## 🐛 **Current Issues**

### **"Unknown Champion" and "Unknown" Match Results Issue 🔄 ONGOING**
- **Problem**: Champion names showing as "Unknown Champion" and match results as "Unknown"
- **Investigation**: 
  - Champion data is loading correctly (171 champions in database)
  - ChampionTestView shows successful lookups by both ID and Key
  - DataManager has enhanced lookup logic with fallback matching
- **Status**: Issue persists despite champion data being available
- **Next Steps**: 
  - Debug the actual champion linking in match parsing
  - Verify participant-champion relationship in UI
  - Check if champion data is being properly passed to MatchCardView

## 📝 **Next Steps**
- **IMMEDIATE**: Fix "Unknown Champion" and "Unknown" match results issue
- **Phase 4**: Post-game coaching analysis (3 bullets + 1 drill)
- **Phase 5**: Champion Pool guidance
- **Phase 6**: Home insights and performance metrics
- **Phase 7**: StoreKit 2 integration for premium features

## 📁 **Key Files**
- **Models**: `Summoner.swift`, `Match.swift`, `Participant.swift`, `Champion.swift`, `Baseline.swift`
- **Services**: `RiotClient.swift`, `RiotHTTPClient.swift`, `DataDragonService.swift`, `DataManager.swift`
- **Views**: `LoginView.swift`, `MainAppView.swift`, `MatchCardView.swift`
- **Test Views**: `RiotAPITestView.swift`, `DataDragonTestView.swift`, `SwiftDataTestView.swift`, `ChampionTestView.swift`
- **Utils**: `RateLimiter.swift`
- **App**: `ClaimbApp.swift`, `ContentView.swift`, `ClaimbSpinner.swift`

## 🔑 **API Keys & Configuration**
- **Riot API Key**: Configured in build settings (not hardcoded)
- **Data Dragon**: No API key required (public endpoints)
- **Rate Limiting**: 1.2s delay between requests
- **Caching**: URLCache for automatic disk caching

## 🧪 **Testing**
- **API Testing**: Interactive test interface with comprehensive logging
- **Data Testing**: SwiftData operations and champion data loading
- **UI Testing**: Login flow and match history display
- **Champion Testing**: Dedicated view for champion data verification
