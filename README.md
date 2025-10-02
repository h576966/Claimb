# Claimb - League of Legends Companion App

<div align="center">
  <img src="Claimb/Claimb/Assets.xcassets/AppIcon.appiconset/1024.png" alt="Claimb Logo" width="120" height="120">
  
  **Your personal League of Legends coach in your pocket**
  
  [![iOS](https://img.shields.io/badge/iOS-18.0+-blue.svg)](https://developer.apple.com/ios/)
  [![Swift](https://img.shields.io/badge/Swift-6.1+-orange.svg)](https://swift.org/)
  [![SwiftUI](https://img.shields.io/badge/SwiftUI-6.0-green.svg)](https://developer.apple.com/xcode/swiftui/)
  [![SwiftData](https://img.shields.io/badge/SwiftData-1.0-purple.svg)](https://developer.apple.com/documentation/swiftdata/)
</div>

## 🎯 **What is Claimb?**

Claimb is a **local-first** League of Legends companion app designed for iPhone users who want to improve their gameplay through data-driven insights and personalized coaching. Unlike other apps that require constant internet connectivity, Claimb works offline and respects your privacy by keeping all data on your device.

### **Core Features**
- 📊 **Performance Analytics**: Track your performance with role-specific KPIs and baseline comparisons
- 🏆 **Champion Pool Management**: Analyze your champion performance and get optimization insights
- 🧠 **AI Coaching**: Post-game analysis with personalized insights, timeline data, and actionable advice with specific timing
- ⏱️ **Timeline Integration**: Early game analysis with exact minute marks for specific feedback (e.g., "At 6:30, you should have...")
- 🏅 **Rank Tracking**: Display Solo/Duo and Flex rank information with LP tracking
- 🔄 **Offline-First**: Works without internet after initial data sync (with optimistic caching for AI responses)
- 🎮 **iPhone-Optimized**: Designed specifically for one-handed mobile use with Apple Watch-like interface

## 🏗️ **Architecture**

### **Technology Stack**
- **Platform**: iOS 18+ (iPhone only)
- **Language**: Swift 6.1+
- **UI Framework**: SwiftUI 6.0
- **Data Persistence**: SwiftData
- **Networking**: URLSession with async/await
- **APIs**: Supabase Edge Functions (Riot Games API, Data Dragon API, OpenAI API)

### **Design Principles**
- **Local-First**: All data stored locally, no backend required
- **Privacy-Focused**: No data leaves your device
- **Offline-Capable**: Full functionality without internet connection
- **Performance-Oriented**: Optimized for quick usage sessions
- **Apple Watch Aesthetic**: Dark card-based layouts with clean typography

## 📱 **Current Features**

### **✅ Fully Implemented**
- **Account Management**: Login with Riot ID (Summoner Name + Tag) with persistent sessions
- **Match History**: View recent matches with detailed statistics (100 matches cached)
- **Champion Data**: Complete champion database (171 champions) with Data Dragon integration
- **Performance Analytics**: KPI-focused dashboard with role-specific metrics and baseline comparisons
- **Champion Pool Analysis**: Track champion performance, win rates, and filtering options
- **AI Coaching**: Dual-focused coaching system with post-game analysis and performance summaries
- **Timeline Data Integration**: Early game analysis with specific timing insights and minute marks
- **Optimistic Caching**: Instant cached responses with transparent background refresh for AI coaching
- **Lane Matchup Analysis**: AI analysis includes opponent champion and team composition context
- **Rank Tracking**: Solo/Duo and Flex rank display with LP tracking and win/loss records
- **Streak Analysis**: Losing/winning streak detection and recent performance tracking
- **Performance Indicators**: Visual streak warnings and recent win/loss records in Performance view
- **Offline Caching**: 100 matches cached per summoner with background refresh
- **Region Support**: EUW, NA, EUNE with proper API routing through Supabase proxy
- **Role-Based Analysis**: Track performance by role with persistent role selection
- **Baseline Comparisons**: Compare performance against role-specific baselines from real data
- **Secure API Architecture**: All external API calls through Supabase edge functions
- **UIState Pattern**: Consistent loading, error, and empty states across all views
- **Design System**: Complete Apple Watch-like interface with dark card-based layouts

### **✅ Recently Completed (Architecture Modernization)**
- **Supabase Edge Function Integration**: Secure API calls through server-side proxy
- **Simplified Architecture**: Eliminated over-abstraction and reduced complexity by 36%
- **Generic Request Deduplication**: Unified system replacing 4 specialized queues
- **Factory Pattern**: DataManager factory method eliminating 44+ lines of boilerplate
- **Direct Model Integration**: Champion class mapping moved to model layer for better cohesion
- **UIState Pattern**: Standardized loading, error, and empty states across all views
- **Structured Logging**: Comprehensive logging with ClaimbLogger
- **Performance Optimizations**: Static JSON loading over database queries
- **Secure API Management**: Server-side API key management with JWT authentication
- **Rank System Integration**: Solo/Duo and Flex rank tracking with League-V4 API integration

## 🏗️ **Current Implementation Status**

### **✅ Architecture (Fully Implemented)**
- **SwiftData Models**: 6 models with proper relationships and computed properties
- **Supabase Integration**: Complete proxy service with secure API key management
- **DataManager**: 879 lines with extracted components (MatchParser, ChampionDataLoader, BaselineDataLoader)
- **UIState Pattern**: Standardized state management across all views
- **Design System**: Complete with colors, typography, spacing, and reusable components
- **Request Deduplication**: Generic system preventing duplicate API calls
- **Error Handling**: Comprehensive error handling with user-friendly messages

### **✅ Core Features (Fully Implemented)**
- **3-Tab Interface**: Champion, Performance, Coaching with role-based filtering
- **Dual-Focused Coaching**: Post-game analysis + Performance summary with auto-triggers
- **Champion Pool Management**: Performance tracking, filtering, and win rate analysis
- **KPI Dashboard**: Role-specific metrics with baseline comparisons
- **Rank Display**: Solo/Duo and Flex rank badges with LP tracking in Performance view
- **Persistent Sessions**: Login state and role selection persist across app restarts
- **Offline-First**: Full functionality without internet after initial sync

### **✅ Technical Implementation (Fully Implemented)**
- **RiotProxyClient**: Secure API communication through Supabase edge functions
- **DataDragonService**: Static game data with caching and version management
- **OpenAIService**: AI coaching with GPT-4 Turbo optimization and response caching
- **KPICalculationService**: Performance analysis with role-specific metrics including Objective Participation
- **UserSession**: Session management with persistent login and role selection
- **Rank Integration**: League-V4 API integration for Solo/Duo and Flex rank tracking
- **Structured Logging**: Comprehensive logging with ClaimbLogger across all services

## 🏗️ **Recent Architecture Improvements**

### **Latest Supabase Integration (September 2025)**
We recently completed a major architecture modernization by integrating Supabase edge functions for secure API management:

#### **🔐 Secure API Architecture**
- **Supabase Edge Functions**: All external API calls now routed through secure server-side proxy
- **Server-Side API Keys**: Riot Games API, Data Dragon API, and OpenAI API keys managed server-side
- **JWT Authentication**: Secure authentication using Supabase anon key
- **App Token Security**: Additional security layer with custom app token
- **Zero Client Exposure**: No API keys ever exposed to the client application

#### **🚀 New Services Architecture**
- **ProxyService**: Centralized service for all API calls through Supabase edge functions
- **RiotProxyClient**: Riot API communication via secure proxy (replaces RiotHTTPClient)
- **OpenAIService**: AI coaching insights via secure proxy
- **AppConfig**: Centralized configuration management for Supabase credentials

#### **🤖 AI Coaching Redesign (Latest - October 2025)**
- **Dual-Focused Coaching**: Separate post-game analysis and performance summary
- **Timeline Data Integration**: Post-game analysis now includes detailed early game timeline data with specific timing insights
- **Post-Game Analysis**: Champion-focused insights for most recent game with lane matchup context and timing markers
- **Performance Summary**: Role-focused trends over last 10 games with diversity metrics
- **Champion Pool Integration**: Leverages existing "Best Performing Champions" logic
- **Smart Auto-Triggers**: Post-game analysis auto-generates on new matches
- **Optimistic Caching**: Shows cached responses immediately while refreshing in background
- **Simplified UI**: Two focused cards instead of complex multi-section layout
- **Performance Section Cleanup**: Removed role/champion diversity from display (moved to coaching)

#### **📊 Benefits Achieved**
- **Enhanced Security**: API keys never exposed to client
- **Simplified Configuration**: Single set of Supabase credentials needed
- **Centralized Management**: All API keys managed in one place
- **Rate Limiting**: Server-side rate limiting and caching
- **Cost Control**: Better monitoring and control of API usage
- **Focused Coaching**: Actionable insights instead of overwhelming stats
- **Smart Data Usage**: Leverages existing champion pool and KPI calculations
- **Timeline Insights**: Specific timing-based advice with minute marks (e.g., "At 6:30, you should have...")
- **Optimistic UX**: Instant cached responses with transparent background refresh

### **Latest Streak Analysis & Performance Indicators (October 2025)**
We recently implemented comprehensive streak analysis and performance indicators to help players understand their current form and make better decisions:

#### **🔥 Streak Analysis Features**
- **Losing Streak Detection**: Identifies consecutive losses with visual warnings (3+ losses)
- **Winning Streak Tracking**: Highlights positive momentum with streak indicators (3+ wins)
- **Recent Performance**: Shows last 10 games win/loss record with win rate percentage
- **Role-Specific Analysis**: Streak calculations based on player's primary role
- **Visual Indicators**: SF Symbols-based UI with DesignSystem color coding
- **Performance View Integration**: Streak indicators displayed below rank badges

#### **🎯 AI Coaching Integration**
- **Streak Context in Prompts**: Current streaks and recent performance included in AI coaching
- **Personalized Advice**: AI considers losing streaks to suggest breaks or normal games
- **Momentum Recognition**: AI encourages maintaining positive streaks
- **Role-Specific Guidance**: Streak analysis tailored to player's primary role
- **Enhanced Prompts**: 350 token limit with comprehensive streak and performance data

#### **🔧 Technical Implementation**
- **KPICalculationService Methods**: 
  - `calculateLosingStreak()` - Counts consecutive losses for specific role
  - `calculateWinningStreak()` - Counts consecutive wins for specific role
  - `calculateRecentWinRate()` - Recent performance over last 10 games
- **Performance View UI**: Streak indicators with SF Symbols and DesignSystem styling
- **OpenAIService Integration**: Enhanced prompts with streak context and performance data
- **Data-Driven Insights**: Uses existing match data for accurate streak calculations

#### **📈 Benefits**
- **Better Decision Making**: Visual warnings help players recognize when to take breaks
- **Momentum Awareness**: Players can capitalize on winning streaks
- **Personalized Coaching**: AI advice considers current form and recent performance
- **Visual Feedback**: Clear indicators help players understand their current state
- **Role-Specific Analysis**: Streak calculations tailored to player's main role

### **Latest Timeline Data Integration (October 2025)**
We recently enhanced the AI coaching system with detailed early game timeline data for more specific and actionable insights:

#### **⏱️ Timeline Data Features**
- **Early Game Focus**: Detailed timeline data for first 15 minutes of gameplay
- **Specific Timing**: AI provides advice with exact minute marks (e.g., "At 3:15, strong first blood showed good aggression")
- **Lane Matchup Context**: Analysis includes opponent champion and matchup-specific insights
- **Team Composition**: Full team context included in analysis for better strategic advice
- **Trading Patterns**: Identifies lane trading opportunities and mistakes with timing data
- **Wave Management**: Analyzes recall timings and wave state decisions
- **Objective Participation**: Early game objective involvement with timing context

#### **🔧 Technical Implementation**
- **RiotTimelineLite Endpoint**: Secure timeline data fetching through Supabase edge functions
- **Graceful Fallback**: Analysis proceeds without timeline if data unavailable (backward compatibility)
- **Enhanced Prompts**: AI prompts include comprehensive timeline data when available
- **Lane Opponent Detection**: Automatic identification of lane opponent for matchup analysis
- **Team Context Extraction**: Structured team composition data for strategic insights
- **Background Refresh**: Optimistic caching shows cached analysis while refreshing in background
- **Cache Management**: Timeline-enhanced analyses cached with proper expiration

#### **📈 Benefits**
- **Specific Feedback**: Instead of "Farm better", get "At 7:40, died overextended without vision"
- **Timing-Based Learning**: Understand exactly when mistakes happened for better recall and learning
- **Matchup Insights**: Champion-specific advice considering actual lane opponent
- **Power Spike Awareness**: AI can reference specific levels and timing windows
- **Actionable Improvement**: Concrete examples from actual gameplay to learn from
- **Faster Coaching**: Instant cached responses with transparent background refresh indicator

### **Latest Rank System Integration (October 2025)**
We recently completed the integration of League of Legends rank tracking to provide players with comprehensive rank information:

#### **🏅 Rank System Features**
- **Dual Rank Display**: Solo/Duo and Flex rank badges with LP tracking
- **League-V4 API Integration**: Secure rank data fetching through Supabase edge functions
- **Performance View Integration**: Rank badges displayed below role selector
- **Win/Loss Tracking**: Complete match history for both ranked queues
- **Unranked Handling**: Graceful display of "Unranked" status when no rank data available
- **Real-time Updates**: Rank data refreshed on summoner login/update

#### **🔧 Technical Implementation**
- **New API Endpoint**: `/riot/league-entries` for fetching rank data
- **Enhanced Summoner Model**: Added rank properties (soloDuoRank, flexRank, LP, wins/losses)
- **DataManager Integration**: Automatic rank fetching during summoner creation/update
- **UI Components**: RankBadge component with tier-based color coding
- **Debug Logging**: Comprehensive logging for rank data fetching and display
- **Model Updates**: Fixed LeagueEntry models to match actual edge function response format

#### **📈 Benefits**
- **Complete Player Profile**: Full rank information alongside performance metrics
- **Coaching Context**: Rank information included in AI coaching prompts for better insights
- **Visual Feedback**: Clear rank display helps players understand their current standing
- **Data Completeness**: Comprehensive player data for better analysis and recommendations

### **Latest Simplification Achievements (September 2025)**
We recently completed a comprehensive architecture cleanup that reduced codebase complexity by **36%** while maintaining all functionality:

#### **🔥 DataManager Simplification**
- **Split DataManager** from 1,371 → 879 lines (36% reduction)
- **Extracted focused components**: MatchParser (292 lines), ChampionDataLoader (~90 lines), BaselineDataLoader (~110 lines)
- **Removed 51 lines of unused methods**: clearChampionData, clearBaselineData, unused delegation methods
- **Eliminated dead code** while preserving valuable patterns

#### **🎯 Role Persistence Fix**
- **Fixed role selector persistence issue** - selections now persist across app restarts
- **Updated 4 binding locations** to use proper persistence method
- **Replaced direct assignment** with `userSession.updatePrimaryRole()`
- **Zero functional impact** - seamless user experience improvement

#### **🚀 Preserved Valuable Patterns**
- **Kept DataManager.create() factory** - eliminates boilerplate, centralizes dependencies
- **Maintained request deduplication** - prevents race conditions, used in 4 critical places
- **Preserved UIState pattern** - consistent state management across all views
- **Retained extracted components** - good separation of concerns

#### **📊 Current Impact Summary**
- **~500+ lines of code eliminated** across all improvements
- **DataManager reduced** from 1,371 → 879 lines (36% reduction)
- **Zero breaking changes** - all existing functionality preserved
- **Improved maintainability** through focused, single-responsibility components
- **Enhanced user experience** with persistent role selection
- **Complete rank system** with Solo/Duo and Flex rank tracking
- **Enhanced coaching context** with rank information in AI prompts

### **Performance Optimizations (September 2025)**
- **One‑time Team DMG fix**: gated cache clear with `UserDefaults` flag; no longer runs on every launch
- **SwiftData safety**: all `ModelContext` operations are MainActor‑isolated (loaders/parsers/dedup tasks)
- **Secure logging**: Riot API key masked (only last 4 characters retained)
- **KPI caching**: 
  - In‑memory cache keyed by `summonerPUUID|role|matchCount|latestMatchId`
  - Persisted lightweight cache in `UserDefaults` for instant warm starts
  - Cached‑first rendering with background refresh on view entry or role change
- **Role mapping logs throttled**: duplicate `NONE` role mappings logged once per unique `(role,lane,result)`

Result: faster warm starts, less redundant work and noise, and safer logs with minimal added complexity.

### **🧠 Coaching System Redesign (Planned)**

We're implementing a comprehensive redesign of the coaching system to provide more focused, actionable insights:

#### **🎯 Post-Game Analysis (Champion-Focused)**
- **Auto-Trigger**: Automatically generates analysis for most recent game when new matches are loaded
- **Champion-Specific**: Focuses on the actual champion played in that game
- **Champion Pool Integration**: Leverages existing "Best Performing Champions" logic from Champion section
- **Actionable Advice**: 2-3 specific things to improve for next game
- **Champion Pool Nudging**: Suggests avoiding low win-rate champions in ranked

#### **📊 Performance Summary (Role-Focused)**
- **Scope**: Exactly 10 games, auto-updates every 5 games
- **Role Analysis**: Focuses on roles actually played in last 10 games (regardless of primary role)
- **Diversity Context**: Includes role/champion diversity metrics in analysis
- **Trend Focus**: Improvements made and areas of concern over time
- **Complementary**: Avoids overlap with existing Performance section

#### **🔧 Technical Implementation**
- **Data Reuse**: Leverages existing KPICalculationService and champion pool logic
- **Smart Updates**: Only analyzes when there's new data, avoids redundant analysis
- **Simplified UI**: Two focused cards instead of complex multi-section layout
- **Performance Section Cleanup**: Removes role/champion diversity from display (moved to coaching)

#### **📈 Benefits**
- **More Actionable**: Focused advice instead of overwhelming statistics
- **Champion-Aware**: Integrates champion pool insights for better recommendations
- **Efficient**: Reuses existing data and calculations
- **User-Friendly**: Simplified interface with clear, focused insights

### **🔄 In Development**
- **Coaching Redesign Implementation**: Dual-focused coaching system
- **Testing Infrastructure**: Unit tests for critical components
- **Advanced Performance Metrics**: Trend analysis and improvement suggestions
- **Champion Pool Optimization**: Meta-based recommendations
- **Premium Features**: Advanced coaching and unlimited analysis
- **iPad Support**: NavigationSplitView for larger screens

## 🚀 **Getting Started**

### **Prerequisites**
- macOS 15+ with Xcode 16+
- iOS 18+ device or simulator
- Supabase edge function access (API keys managed server-side)

### **Installation**
1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/claimb.git
   cd claimb
   ```

2. Open the project in Xcode:
   ```bash
   open Claimb.xcodeproj
   ```

3. Configure your Supabase credentials in build settings:
   - Add `CLAIMB_FUNCTION_BASE_URL` to your build settings
   - Add `SUPABASE_ANON_KEY` to your build settings  
   - Add `APP_SHARED_TOKEN` to your build settings
   - Never commit API keys to version control

4. Build and run on your device or simulator

### **First Launch**
1. Enter your Riot ID (Summoner Name + Tag)
2. Select your region (EUW, NA, or EUNE)
3. Tap "Login" to sync your match data and rank information
4. Wait for champion data to load (one-time setup)
5. Explore your performance analytics, champion pool, and rank information

## 📊 **Data Models**

### **Core Entities**
- **Summoner**: Player identity, account information, and rank data (Solo/Duo, Flex)
- **Match**: Game metadata and team composition
- **Participant**: Individual player performance data
- **Champion**: Static champion data with integrated class mapping
- **Baseline**: Performance benchmarks for coaching analysis
- **CoachingResponseCache**: Cached AI coaching responses with expiration

### **Key Metrics Tracked**
- **Combat**: KDA, Damage Dealt/Taken, Kill Participation
- **Economy**: Gold per Minute, CS per Minute, Gold Share
- **Vision**: Vision Score, Ward Placement, Control Wards
- **Objectives**: Dragon/Baron participation, Tower damage, Objective Participation KPI
- **Challenges**: Riot's performance challenge data
- **Rank Data**: Solo/Duo and Flex rank, LP, wins/losses

## 🔧 **Development**

### **Project Structure**
```
Claimb/
├── Core/                    # Core application components
│   ├── DesignSystem/        # Centralized design system
│   ├── Utilities/           # Shared utilities and helpers
│   ├── ViewModels/          # Shared view models
│   └── Views/               # Core UI components
├── Features/                # Feature-specific modules
│   ├── Champions/           # Champion pool analysis
│   ├── Coaching/            # AI coaching features
│   ├── KPIs/                # Performance analytics
│   └── Onboarding/          # Login and role selection
├── Models/                  # SwiftData models (6 models)
├── Services/                # External service integrations
│   ├── Riot/                # Riot API client (via proxy)
│   ├── DataDragon/          # Data Dragon service
│   ├── Proxy/               # Supabase edge function proxy
│   ├── Storage/             # Data management
│   └── Coaching/            # Baseline and analysis
├── ClaimbTests/             # Test suites
└── Assets.xcassets/         # App icons and images
```

### **Key Services**
- **DataManager**: Core data coordination and caching (879 lines, 36% reduced)
- **MatchParser**: Focused match and participant data parsing (292 lines)
- **ChampionDataLoader**: Champion data management and loading (~90 lines)
- **BaselineDataLoader**: Baseline data management (~110 lines)
- **ProxyService**: Secure API calls through Supabase edge functions
- **RiotProxyClient**: Riot API communication via proxy service (replaces RiotHTTPClient)
- **DataDragonService**: Manages static game data and champion information
- **KPICalculationService**: Performance analysis and coaching insights
- **OpenAIService**: AI coaching insights via proxy service (GPT-4 Turbo optimized)
- **UserSession**: Session management and persistent login with role persistence

### **Architecture Principles**
- **Simplicity First**: Eliminated over-abstraction, reduced complexity by 36%
- **DRY Principle**: Generic request deduplication, factory patterns eliminate boilerplate
- **Single Responsibility**: Extracted focused components (MatchParser, ChampionDataLoader, BaselineDataLoader)
- **Direct Integration**: Champion class mapping integrated into model layer
- **Performance Optimized**: Static JSON loading over database queries, request deduplication
- **Type Safety**: Generic systems with compile-time safety and UIState pattern
- **UIState Pattern**: Standardized loading, error, and empty states
- **Centralized Logging**: Structured logging with ClaimbLogger

### **Design System**
- **DesignSystem.Colors**: Centralized color palette with light/dark variants
- **DesignSystem.Typography**: Consistent text styling with Dynamic Type support
- **DesignSystem.Spacing**: Standardized spacing and layout constants
- **DesignSystem.CornerRadius**: Consistent border radius values
- **DesignSystem.Shadows**: Standardized shadow effects
- **ClaimbCard**: Reusable card component for consistent UI
- **ClaimbButton**: Standardized button styling with variants
- **UIState Components**: Standardized loading, error, and empty state views

### **Testing & Debugging**
The app includes comprehensive test views for development:
- **BaselineTestView**: Test baseline data loading and performance analysis
- **CacheManagementView**: Manage cached data and clear storage
- **Interactive API Testing**: Built-in tools for testing Riot API integration

### **Code Quality**
- **Structured Logging**: Centralized logging with ClaimbLogger
- **Error Handling**: Comprehensive error handling with user-friendly messages
- **Rate Limiting**: Token-bucket algorithm with exponential backoff
- **Memory Management**: Proper async/await patterns and task cancellation
- **Code Organization**: Clean separation of concerns with feature-based modules

## 🌐 **API Integration**

### **Supabase Edge Functions**
- **Secure Proxy**: All API calls routed through Supabase edge functions
- **Server-Side API Keys**: Riot Games API, Data Dragon API, and OpenAI API keys managed server-side
- **JWT Authentication**: Secure authentication using Supabase anon key
- **App Token**: Additional security layer with custom app token

### **Supported APIs**
- **Riot Games API**: Account lookup, summoner data, match history and details
- **Riot League-V4 API**: Rank data for Solo/Duo and Flex queues
- **Riot Timeline API**: Early game timeline data for detailed analysis (via `riotTimelineLite` endpoint)
- **Data Dragon API**: Champion data, icons, and version management
- **OpenAI API**: AI coaching insights and analysis via GPT-4 Turbo (optimized)

### **Rate Limiting & Caching**
- **Server-Side Rate Limiting**: Handled by Supabase edge functions
- **Client-Side Caching**: URLCache for static data, SwiftData for dynamic content
- **Request Deduplication**: Prevents duplicate API calls

## 🔒 **Privacy & Security**

### **Data Handling**
- **Local Storage**: All data stored on device using SwiftData
- **Secure API Calls**: All external API calls routed through Supabase edge functions
- **API Keys**: Managed server-side, never exposed to client
- **Offline Mode**: Full functionality without internet after initial sync

### **Permissions**
- **Network**: Required for API calls and data sync
- **Background App Refresh**: Optional for automatic updates

## 📈 **Roadmap**

### **Phase 2: Coaching Redesign (Completed)**
- [x] Implement dual-focused coaching system (post-game + performance summary)
- [x] Update OpenAIService for champion-focused post-game analysis
- [x] Update OpenAIService for role-focused performance summary
- [x] Integrate champion pool logic from Champion section
- [x] Simplify CoachingView UI to two focused cards
- [x] Remove role/champion diversity from Performance section display
- [x] Add smart auto-trigger logic for post-game analysis
- [x] Integrate timeline data for specific timing-based insights
- [x] Implement optimistic caching with background refresh
- [x] Add lane matchup and team composition context

### **Phase 2.5: Rank System Integration (Completed)**
- [x] Implement League-V4 API integration for rank data
- [x] Add rank properties to Summoner model
- [x] Create rank badge UI components with tier-based styling
- [x] Integrate rank fetching into DataManager
- [x] Display rank badges in Performance view
- [x] Include rank information in AI coaching prompts
- [x] Add comprehensive debug logging for rank system
- [x] Fix LeagueEntry model to match actual edge function response format

### **Phase 2.6: Streak Analysis & Performance Indicators (Completed)**
- [x] Implement losing streak detection and visual warnings
- [x] Add winning streak tracking and momentum indicators
- [x] Create recent performance display (last 10 games)
- [x] Integrate streak analysis into Performance view UI
- [x] Add streak context to AI coaching prompts
- [x] Implement role-specific streak calculations
- [x] Use SF Symbols for visual indicators with DesignSystem styling
- [x] Add comprehensive streak analysis methods to KPICalculationService

### **Phase 3: Testing Infrastructure (Next)**
- [ ] Unit tests for DataManager and critical components
- [ ] View model testing with mock services
- [ ] UI snapshot testing for design system components
- [ ] Integration tests for API services

### **Phase 4: Advanced Analytics**
- [ ] Performance trend analysis
- [ ] Goal setting and tracking
- [ ] Comparison with peer performance
- [ ] Detailed match breakdowns

### **Phase 5: Champion Pool Optimization**
- [ ] Meta-based champion recommendations
- [ ] Pool synergy analysis
- [ ] Counter-pick suggestions
- [ ] Role-specific guidance

### **Phase 6: Premium Features**
- [ ] StoreKit 2 integration
- [ ] Unlimited analysis quota
- [ ] Advanced coaching features
- [ ] Export and sharing capabilities

### **Phase 7: Platform Expansion**
- [ ] iPad support with NavigationSplitView
- [ ] macOS Catalyst support
- [ ] Apple Watch companion app

## 🤝 **Contributing**

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### **Development Setup**
1. Fork the repository
2. Create a feature branch
3. Make your changes following the Cursor rules
4. Add tests for new functionality
5. Submit a pull request

### **Code Style**
- Follow Swift API Design Guidelines
- Use SwiftUI best practices with iOS 18+ APIs
- Maintain 100-300 LOC per service file
- Include comprehensive error handling
- Use structured logging with ClaimbLogger
- Follow dependency injection patterns
- Use @Observable for view models (Swift 6)
- Implement proper async/await patterns

## 📄 **License**

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 **Acknowledgments**

- **Riot Games** for providing the League of Legends API
- **Data Dragon** for static game data
- **Apple** for SwiftUI and SwiftData frameworks
- **Community** for feedback and suggestions

## 📞 **Support**

- **Issues**: [GitHub Issues](https://github.com/yourusername/claimb/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/claimb/discussions)
- **Email**: support@claimb.app

---

<div align="center">
  <p>Made with ❤️ for the League of Legends community</p>
  <p>© 2024 Claimb. All rights reserved.</p>
</div>