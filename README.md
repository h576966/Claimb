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
- 🧠 **AI Coaching**: Post-game analysis with personalized insights and actionable drills
- 🔄 **Offline-First**: Works without internet after initial data sync
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

### **✅ Implemented**
- **Account Management**: Login with Riot ID (Summoner Name + Tag)
- **Match History**: View recent matches with detailed statistics
- **Champion Data**: Complete champion database (171 champions) with Data Dragon integration
- **Performance Analytics**: KPI-focused dashboard with role-specific metrics
- **Champion Pool Analysis**: Track champion performance and win rates
- **AI Coaching**: Post-game analysis with personalized insights
- **Offline Caching**: 50 matches cached per summoner with background refresh
- **Region Support**: EUW, NA, EUNE with proper API routing
- **Role-Based Analysis**: Track performance by role (Top, Jungle, Mid, ADC, Support)
- **Baseline Comparisons**: Compare performance against role-specific baselines

### **✅ Recently Completed (Architecture Modernization)**
- **Supabase Edge Function Integration**: Secure API calls through server-side proxy
- **Simplified Architecture**: Eliminated over-abstraction and reduced complexity by 25%
- **Generic Request Deduplication**: Unified system replacing 4 specialized queues
- **Factory Pattern**: DataManager factory method eliminating 44+ lines of boilerplate
- **Direct Model Integration**: Champion class mapping moved to model layer for better cohesion
- **UIState Pattern**: Standardized loading, error, and empty states across all views
- **Structured Logging**: Comprehensive logging with ClaimbLogger
- **Performance Optimizations**: Static JSON loading over database queries
- **Secure API Management**: Server-side API key management with JWT authentication

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
- **RiotProxyClient**: Riot API communication via secure proxy
- **OpenAIService**: AI coaching insights via secure proxy
- **AppConfig**: Centralized configuration management for Supabase credentials

#### **🤖 AI Coaching Optimization (Latest)**
- **GPT-5 Mini Integration**: Optimized for reasoning models with low effort settings
- **Structured Responses**: JSON-formatted coaching tips with word count constraints
- **Efficient Token Usage**: 2000 max tokens with reasoning optimization
- **Fast Response Times**: ~13 second response times for coaching insights
- **Concise System Prompts**: "Be concise and practical" for focused advice

#### **📊 Benefits Achieved**
- **Enhanced Security**: API keys never exposed to client
- **Simplified Configuration**: Single set of Supabase credentials needed
- **Centralized Management**: All API keys managed in one place
- **Rate Limiting**: Server-side rate limiting and caching
- **Cost Control**: Better monitoring and control of API usage
- **AI Coaching**: Working GPT-5 Mini integration with optimized parameters

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
3. Tap "Login" to sync your match data
4. Wait for champion data to load (one-time setup)
5. Explore your performance analytics and champion pool

## 📊 **Data Models**

### **Core Entities**
- **Summoner**: Player identity and account information
- **Match**: Game metadata and team composition
- **Participant**: Individual player performance data
- **Champion**: Static champion data with integrated class mapping
- **Baseline**: Performance benchmarks for coaching analysis

### **Key Metrics Tracked**
- **Combat**: KDA, Damage Dealt/Taken, Kill Participation
- **Economy**: Gold per Minute, CS per Minute, Gold Share
- **Vision**: Vision Score, Ward Placement, Control Wards
- **Objectives**: Dragon/Baron participation, Tower damage
- **Challenges**: Riot's performance challenge data

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
├── Models/                  # SwiftData models
├── Services/                # External service integrations
│   ├── Riot/                # Riot API client (via proxy)
│   ├── DataDragon/          # Data Dragon service
│   ├── Proxy/               # Supabase edge function proxy
│   ├── Storage/             # Data management
│   └── Coaching/            # Baseline and analysis
├── Tests/                   # Test suites
│   ├── Unit/                # Unit tests
│   └── Snapshot/            # UI snapshot tests
└── Assets.xcassets/         # App icons and images
```

### **Key Services**
- **DataManager**: Core data coordination and caching (879 lines, 36% reduced)
- **MatchParser**: Focused match and participant data parsing (292 lines)
- **ChampionDataLoader**: Champion data management and loading (~90 lines)
- **BaselineDataLoader**: Baseline data management (~110 lines)
- **ProxyService**: Secure API calls through Supabase edge functions
- **RiotProxyClient**: Riot API communication via proxy service
- **DataDragonService**: Manages static game data and champion information
- **KPICalculationService**: Performance analysis and coaching insights
- **OpenAIService**: AI coaching insights via proxy service (GPT-5 Mini optimized)
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
- **Data Dragon API**: Champion data, icons, and version management
- **OpenAI API**: AI coaching insights and analysis via GPT-5 Mini (optimized)

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

### **Phase 2: Testing Infrastructure (Current)**
- [ ] Unit tests for DataManager and critical components
- [ ] View model testing with mock services
- [ ] UI snapshot testing for design system components
- [ ] Integration tests for API services

### **Phase 3: Advanced Analytics (Next)**
- [ ] Performance trend analysis
- [ ] Goal setting and tracking
- [ ] Comparison with peer performance
- [ ] Detailed match breakdowns

### **Phase 4: Champion Pool Optimization**
- [ ] Meta-based champion recommendations
- [ ] Pool synergy analysis
- [ ] Counter-pick suggestions
- [ ] Role-specific guidance

### **Phase 5: Premium Features**
- [ ] StoreKit 2 integration
- [ ] Unlimited analysis quota
- [ ] Advanced coaching features
- [ ] Export and sharing capabilities

### **Phase 6: Platform Expansion**
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