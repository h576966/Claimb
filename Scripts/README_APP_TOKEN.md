# App Shared Token Setup for Claimb

This guide helps you set up your App Shared Token for secure API access through Supabase edge functions.

## 🔑 What is the App Shared Token?

The App Shared Token is a secure authentication token that allows Claimb to access your Supabase edge function, which acts as a proxy for Riot API and OpenAI API calls. This approach provides several benefits:

- **Security**: API keys are stored server-side, never exposed in the client app
- **Centralized Management**: All API keys managed in one place
- **Rate Limiting**: Server-side rate limiting and caching
- **Cost Control**: Better monitoring and control of API usage

## 🚀 Quick Setup (Recommended)

Run the setup script:

```bash
./Scripts/setup_app_token.sh
```

This script will:
- Guide you through entering your App Shared Token
- Set the environment variable for your current session
- Add it to your shell profile for persistence
- Validate the token format
- Provide verification steps

## 🔧 Manual Setup

### Option 1: Environment Variable (Recommended)

Add to your shell profile (`~/.zshrc`, `~/.bash_profile`, or `~/.bashrc`):

```bash
export APP_SHARED_TOKEN="your_app_shared_token_here"
```

Then restart your terminal or run:
```bash
source ~/.zshrc  # or ~/.bash_profile
```

### Option 2: Xcode Scheme Environment Variables

1. In Xcode, go to **Product > Scheme > Edit Scheme...**
2. Select **Run** in the left sidebar
3. Go to **Arguments** tab
4. Add environment variable:
   - **Name**: `APP_SHARED_TOKEN`
   - **Value**: `your_app_shared_token_here`

### Option 3: Build Settings (Info.plist)

Add to your `Info.plist`:

```xml
<key>APP_SHARED_TOKEN</key>
<string>your_app_shared_token_here</string>
```

## 🔍 Verification

To verify your setup:

```bash
echo $APP_SHARED_TOKEN
```

You should see your token (first 10 characters will be displayed in logs).

## 🏗️ Architecture Overview

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Claimb App    │    │  Supabase Edge   │    │  External APIs  │
│                 │    │     Function     │    │                 │
│ ┌─────────────┐ │    │ ┌──────────────┐ │    │ ┌─────────────┐ │
│ │ProxyService │ │───▶│ │Riot API Key  │ │───▶│ │Riot Games   │ │
│ └─────────────┘ │    │ └──────────────┘ │    │ │API          │ │
│                 │    │ ┌──────────────┐ │    │ └─────────────┘ │
│ ┌─────────────┐ │    │ │OpenAI API Key│ │───▶│ ┌─────────────┐ │
│ │OpenAIService│ │───▶│ └──────────────┘ │    │ │OpenAI API   │ │
│ └─────────────┘ │    └──────────────────┘    │ └─────────────┘ │
└─────────────────┘                           └─────────────────┘
```

## 📡 Available Endpoints

Your Supabase edge function should support these endpoints:

### Riot API Endpoints
- `GET /riot/matches?puuid={puuid}&region={region}&count={count}&start={start}`
- `GET /riot/match?matchId={matchId}&region={region}`
- `GET /riot/summoner?puuid={puuid}&region={region}`

### AI Coaching Endpoint
- `POST /ai/coach` with JSON body: `{"prompt": "your prompt here"}`

## 🔒 Security Notes

- The App Shared Token should be kept confidential
- Never commit the token to version control
- Use environment variables or secure key management
- The token provides access to your API quota and costs

## 🆘 Troubleshooting

### "Invalid API key" Error
- Verify your APP_SHARED_TOKEN is set correctly
- Check that the token is valid and not expired
- Ensure your Supabase edge function is deployed and accessible

### Network Errors
- Check your internet connection
- Verify the Supabase edge function URL is correct
- Check Supabase function logs for errors

### Authentication Errors
- Verify the App Shared Token is correct
- Check that your device header is being sent properly
- Ensure your Supabase edge function is configured correctly

## 📞 Support

If you encounter issues:
1. Check the console logs for detailed error messages
2. Verify your setup using the verification steps above
3. Contact your administrator for token issues
4. Check Supabase function logs for server-side errors

**Note**: The Coaching section and all API calls now require a valid App Shared Token to function. Without it, you'll see authentication errors when trying to use these features.
