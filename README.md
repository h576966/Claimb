# Claimb - Ranked Performance & AI Coaching

<div align="center">
  <img src="Claimb/Claimb/Assets.xcassets/AppIcon.appiconset/1024.png" alt="Claimb Logo" width="120" height="120">
  
  **Your personal performance analytics coach**
  
  [![iOS](https://img.shields.io/badge/iOS-18.0+-blue.svg)](https://developer.apple.com/ios/)
  [![Swift](https://img.shields.io/badge/Swift-6.1+-orange.svg)](https://swift.org/)
  [![SwiftUI](https://img.shields.io/badge/SwiftUI-6.0-green.svg)](https://developer.apple.com/xcode/swiftui/)
  [![SwiftData](https://img.shields.io/badge/SwiftData-1.0-purple.svg)](https://developer.apple.com/documentation/swiftdata/)
</div>

## 🎯 **What is Claimb?**

Claimb is a **local-first** performance analytics app designed for competitive gamers who want to improve their gameplay through data-driven insights and personalized AI coaching. Unlike other apps that require constant internet connectivity, Claimb works offline and respects your privacy by keeping all data on your device.

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

### **✅ Recently Completed (December 2024)**
- **Smart Match Fetching**: 90-day initial window with 180-day fallback for infrequent players
- **Enhanced Loading UX**: Smooth progress animation with 3-phase system (Account Setup → Data Loading → Finalization)
- **Improved Coaching States**: Proper loading indicators for post-game analysis and performance summary
- **Better Error Handling**: Contextual loading messages instead of misleading "Play more games" text
- **Match Repository Optimization**: Separate strategies for initial bulk fetch vs recent matches refresh

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
- **OpenAIService**: AI coaching with gpt-5-mini (Responses API) and response caching
- **KPICalculationService**: Performance analysis with role-specific metrics including Objective Participation
- **UserSession**: Session management with persistent login and role selection
- **Rank Integration**: League-V4 API integration for Solo/Duo and Flex rank tracking
- **Structured Logging**: Comprehensive logging with ClaimbLogger across all services

## 🚀 **Production Readiness (October 2025)**

We recently completed a comprehensive production-readiness initiative to ensure the app meets App Store requirements and professional quality standards:

### **✅ Code Cleanup & Quality**
- **Removed 1,700+ lines of dead code**: Deleted 11 Python test scripts, debug utilities, and 327 lines of unused models
- **Conditional compilation**: Debug views (BaselineTestView, TestResultView) and debug UI wrapped in `#if DEBUG`
- **Proper logging**: Replaced all `print()` and `NSLog()` statements with `ClaimbLogger`
- **Resolved TODOs**: Re-enabled age filtering for matches (1 year limit)
- **Zero production bloat**: Debug code excluded from Release builds
- **Models cleanup (October 2025)**: Removed 4 unused model structs, 2 orphaned UI components, and 1 unintegrated timeline feature

### **✅ App Store Compliance**
- **Export compliance**: Added `ITSAppUsesNonExemptEncryption=false` declaration
- **App Transport Security**: Verified secure HTTPS configuration for all APIs
- **Network permissions**: User-friendly network usage description
- **Ready for submission**: All required Info.plist keys present

### **✅ Security Hardening**
- **No hardcoded keys**: Verified no API keys in source code
- **Secure configuration**: All keys loaded from secure build settings via `AppConfig`
- **Debug-only logging**: Configuration logging wrapped in `#if DEBUG` conditionals
- **Clean git history**: No accidentally committed secrets
- **Server-side security**: Supabase anon key intentionally public (RLS protected)

### **✅ Build Optimization**
- **Dead code stripping**: `DEAD_CODE_STRIPPING = YES` verified
- **Whole module optimization**: `SWIFT_COMPILATION_MODE = wholemodule` for Release
- **Optimal performance**: Release builds fully optimized for speed and size
- **Debug support**: Development builds retain full debugging capability

### **✅ Error Resilience**
- **Comprehensive error handling**: All error types now have user-friendly messages
- **Enhanced ErrorHandler**: Added OpenAIError, ProxyError, DataDragonError, UserSessionError handling
- **Actionable guidance**: Users get clear next steps instead of technical errors
- **Smart error messages**: Rate limit, server error, and network error differentiation
- **Leveraged existing patterns**: UIState + throws/Result already handle errors well

### **✅ Accessibility (VoiceOver Support)**
- **Tab bar navigation**: All 3 tabs (Champion, Performance, Coaching) have descriptive labels and hints
- **Critical action buttons**: Login, Logout, Refresh buttons fully accessible
- **Form fields**: Login form with clear labels for summoner name, tag line, and region
- **Loading states**: Dynamic labels for button states ("Login" vs "Logging in")
- **80/20 approach**: 20 lines of code for 80% of accessibility value

### **📈 Impact**
- **Smaller binary**: 1,700+ lines removed, debug code excluded from production
- **App Store ready**: All compliance requirements met
- **Secure**: No exposed secrets, proper key management
- **Professional**: Clean codebase, proper logging, optimized builds
- **Accessible**: VoiceOver users can navigate entire app and complete core workflows
- **User-friendly errors**: Clear guidance when things go wrong
- **Maintainable**: Well-documented, consistent patterns, focused components
- **Leaner models**: 327 lines of unused code removed from Models/ directory

---


## 🏗️ **Architecture Overview**

### **🔐 Secure API Architecture**
- **Supabase Edge Functions**: All external API calls routed through secure server-side proxy
- **Server-Side API Keys**: Riot Games API, Data Dragon API, and OpenAI API keys managed server-side
- **Zero Client Exposure**: No API keys ever exposed to the client application

### **🔄 Loading & Progress System**
- **3-Phase Loading**: Account Setup (0-25%), Data Loading (25-75%), Finalization (75-100%)
- **Smart Progress Animation**: Smooth progress bar that advances to 80% over 2.5 seconds
- **Contextual Messaging**: Appropriate loading messages for each phase
- **Optimized Match Fetching**: Progressive time windows ensure sufficient data for all player types

### **🤖 AI Coaching System**
- **Dual-Focused Coaching**: Post-game analysis and performance summary
- **OpenAI Responses API**: Full integration with gpt-5-mini and proper JSON enforcement
- **Optimistic Caching**: Instant cached responses with transparent background refresh
- **Baseline-Aware**: AI considers performance baselines for targeted advice

### **📊 Performance Features**
- **Streak Analysis**: Losing/winning streak detection with visual indicators
- **Rank Tracking**: Solo/Duo and Flex rank display with LP tracking
- **KPI Dashboard**: Role-specific metrics with baseline comparisons
- **Champion Pool**: Performance tracking and optimization insights

### **🔄 In Development**
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
- **OpenAIService**: AI coaching insights via proxy service (gpt-5-mini with Responses API)
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
The app includes comprehensive test views for development (DEBUG builds only):
- **BaselineTestView**: Test baseline data loading and performance analysis (conditionally compiled)
- **TestResultView**: Display test results and network diagnostics (conditionally compiled)
- **Debug UI Controls**: "Clear Cache" and "Test Baselines" buttons (conditionally compiled)
- **Interactive API Testing**: Built-in tools for testing Riot API integration
- **ClaimbLogger**: Structured logging for development and production (debug messages stripped from Release)

### **Code Quality**
- **Structured Logging**: Centralized logging with ClaimbLogger (debug logs stripped from Release builds)
- **Error Handling**: Comprehensive error handling with user-friendly messages
- **Rate Limiting**: Token-bucket algorithm with exponential backoff
- **Memory Management**: Proper async/await patterns and task cancellation
- **Code Organization**: Clean separation of concerns with feature-based modules
- **Production Ready**: Debug code conditionally compiled, optimized Release builds
- **Security**: No hardcoded secrets, secure key management, debug-only configuration logging
- **App Store Compliant**: All required privacy descriptions and export compliance declarations

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
- **OpenAI API**: AI coaching insights via gpt-5-mini (Responses API with reasoning)

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
- **Network**: Required for API calls and data sync (with user-friendly description)
- **Background App Refresh**: Optional for automatic updates
- **User Tracking**: Required by iOS 14+ but not used (with transparent description)
- **Export Compliance**: Standard HTTPS encryption only (no special export requirements)

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

We welcome contributions! Please follow these guidelines:

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

This project is licensed under the MIT License.

## 📊 **Recent Improvements (December 2024)**

### **Key Updates**
- **Match Fetching Optimization**: Implemented smart 90-180 day time windows ensuring infrequent players get sufficient match data
- **Loading Progress Enhancement**: Fixed stuck progress bar with smooth 3-phase animation system (Account Setup → Data Loading → Finalization)
- **Coaching UX Improvements**: Added proper loading states for post-game analysis and performance summary with contextual messages
- **Enhanced Error Handling**: Replaced misleading "Play more games" messages with appropriate loading indicators
- **Performance Optimizations**: Optimized match loading with progressive time windows and improved caching strategies
- **User Experience**: Smooth progress animation that advances to 80% over 2.5 seconds for consistent loading feel

---

## 🙏 **Acknowledgments**

- **Riot Games** for providing the official gaming APIs
- **Data Dragon** for static game data
- **Apple** for SwiftUI and SwiftData frameworks
- **Community** for feedback and suggestions

## 📞 **Support**

- **Issues**: [GitHub Issues](https://github.com/yourusername/claimb/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/claimb/discussions)
- **Email**: support@claimb.app

---

<div align="center">
  <p>Made with ❤️ for the competitive gaming community</p>
  <p>© 2024 Claimb. All rights reserved.</p>
</div>
