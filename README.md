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
- **APIs**: Riot Games API, Data Dragon API

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

### **🔄 In Development**
- **Advanced Performance Metrics**: Trend analysis and improvement suggestions
- **Champion Pool Optimization**: Meta-based recommendations
- **Premium Features**: Advanced coaching and unlimited analysis
- **iPad Support**: NavigationSplitView for larger screens

## 🚀 **Getting Started**

### **Prerequisites**
- macOS 15+ with Xcode 16+
- iOS 18+ device or simulator
- Riot Games API key (for development)

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

3. Configure your Riot API key in build settings:
   - Add `RIOT_API_KEY` to your build settings
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
- **Champion**: Static champion data from Data Dragon
- **Baseline**: Performance benchmarks for coaching analysis
- **ChampionClassMapping**: Champion archetype classification

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
├── Models/           # SwiftData models
├── Services/         # API clients and business logic
├── Views/            # SwiftUI views
├── Utils/            # Utilities and design system
└── Assets.xcassets/  # App icons and images
```

### **Key Services**
- **RiotHTTPClient**: Handles all Riot API communication with proper rate limiting
- **DataDragonService**: Manages static game data and champion information
- **DataManager**: Central data orchestration and caching
- **BaselineService**: Performance analysis and coaching insights
- **UserSession**: Session management and persistent login

### **Design System**
- **DesignSystem.Colors**: Centralized color palette with light/dark variants
- **DesignSystem.Typography**: Consistent text styling with Dynamic Type support
- **DesignSystem.Spacing**: Standardized spacing and layout constants
- **ClaimbCard**: Reusable card component for consistent UI
- **ClaimbButton**: Standardized button styling

### **Testing & Debugging**
The app includes comprehensive test views for development:
- **BaselineTestView**: Test baseline data loading and performance analysis
- **CacheManagementView**: Manage cached data and clear storage
- **Interactive API Testing**: Built-in tools for testing Riot API integration

## 🌐 **API Integration**

### **Riot Games API**
- **Account-v1**: Player account lookup with proper regional routing
- **Summoner-v4**: Summoner profile data
- **Match-v5**: Match history and details
- **Rate Limiting**: Token-bucket algorithm with exponential backoff

### **Data Dragon API**
- **Champion Data**: Names, titles, and metadata
- **Champion Icons**: High-resolution champion images
- **Version Management**: Patch-specific data locking

### **Rate Limiting**
- **Dual-Window Limiter**: Respects Riot's rate limits per region
- **Exponential Backoff**: Handles 429 responses gracefully
- **Caching Strategy**: URLCache for static data, SwiftData for dynamic content

## 🔒 **Privacy & Security**

### **Data Handling**
- **Local Storage**: All data stored on device using SwiftData
- **No Backend**: No data sent to external servers
- **API Keys**: Stored securely in iOS Keychain
- **Offline Mode**: Full functionality without internet

### **Permissions**
- **Network**: Required for API calls and data sync
- **Background App Refresh**: Optional for automatic updates

## 📈 **Roadmap**

### **Phase 4: Advanced Analytics (Next)**
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
- Use structured logging with swift-log

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