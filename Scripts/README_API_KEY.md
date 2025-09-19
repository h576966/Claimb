# 🔑 API Key Setup Guide

This guide explains how to properly set up your Riot API key for the Claimb iOS app.

## 🚨 **Security First**

**NEVER commit your API key to version control!** This guide shows you how to set up your API key securely.

## 📋 **Prerequisites**

1. Get your Riot API key from [Riot Developer Portal](https://developer.riotgames.com/)
2. Make sure you have Xcode installed
3. Have your project open in Xcode

## 🛠️ **Setup Methods**

### Method 1: Using the Setup Script (Recommended)

1. **Run the setup script:**
   ```bash
   ./Scripts/setup_api_key.sh YOUR_RIOT_API_KEY
   ```

2. **Example:**
   ```bash
   ./Scripts/setup_api_key.sh RGAPI-12345678-1234-1234-1234-123456789012
   ```

### Method 2: Manual Setup

#### Option A: Info.plist (Recommended for Production)

1. Open `Claimb/Info.plist` in Xcode
2. Add a new key-value pair:
   - **Key**: `RIOT_API_KEY`
   - **Value**: Your actual Riot API key

#### Option B: Xcode Build Settings

1. Open your project in Xcode
2. Select your target
3. Go to "Build Settings"
4. Search for "User-Defined"
5. Add a new setting:
   - **Key**: `RIOT_API_KEY`
   - **Value**: Your actual Riot API key

#### Option C: Environment Variables

1. **For development:**
   ```bash
   export RIOT_API_KEY="YOUR_RIOT_API_KEY"
   ```

2. **For Xcode:**
   - Go to Product → Scheme → Edit Scheme
   - Select "Run" → "Arguments"
   - Add environment variable: `RIOT_API_KEY = YOUR_RIOT_API_KEY`

## 🧪 **Testing Your Setup**

1. **Build and run the app:**
   ```bash
   xcodebuild build -project Claimb.xcodeproj -scheme Claimb
   ```

2. **Check the logs:**
   - Look for API key validation messages
   - Verify no "PLACEHOLDER_API_KEY" errors

3. **Test API calls:**
   - Try logging in with a valid summoner name
   - Check that API calls are successful

## 🔍 **Troubleshooting**

### Issue: "PLACEHOLDER_API_KEY" error
**Solution:** Your API key is not being found. Check:
- Info.plist has the correct key
- Environment variables are set
- UserDefaults has the key (for development)

### Issue: 401 Unauthorized
**Solution:** Your API key is invalid or expired:
- Verify the key format: `RGAPI-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`
- Check if the key is active in Riot Developer Portal
- Regenerate the key if needed

### Issue: 403 Forbidden
**Solution:** Your API key doesn't have the required permissions:
- Check your API key permissions in Riot Developer Portal
- Ensure you have access to the required endpoints

## 🔒 **Security Best Practices**

1. **Never commit API keys to Git**
2. **Use different keys for development and production**
3. **Rotate your keys regularly**
4. **Use environment variables for CI/CD**
5. **Add API key files to .gitignore**

## 📚 **Additional Resources**

- [Riot Developer Portal](https://developer.riotgames.com/)
- [Riot API Documentation](https://developer.riotgames.com/docs)
- [iOS App Security Best Practices](https://developer.apple.com/security/)

## 🆘 **Need Help?**

If you're still having issues:
1. Check the console logs for specific error messages
2. Verify your API key format and permissions
3. Test your API key with a simple curl request
4. Check the Riot API status page for outages
