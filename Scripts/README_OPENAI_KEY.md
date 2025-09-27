# OpenAI API Key Setup for Claimb

This guide helps you set up your OpenAI API key for the Coaching section of Claimb.

## 🔑 Getting Your OpenAI API Key

1. **Visit OpenAI Platform**: Go to [https://platform.openai.com/api-keys](https://platform.openai.com/api-keys)
2. **Sign In**: Use your OpenAI account credentials
3. **Create New Key**: Click "Create new secret key"
4. **Copy Key**: The key will start with `sk-` - copy it immediately as it won't be shown again

## 🚀 Quick Setup (Recommended)

Run the setup script:

```bash
./Scripts/setup_openai_key.sh
```

This script will:
- Guide you through entering your API key
- Set the environment variable for your current session
- Add it to your shell profile for persistence
- Validate the key format

## 🔧 Manual Setup

### Option 1: Environment Variable (Recommended)

Add to your shell profile (`~/.zshrc`, `~/.bash_profile`, or `~/.bashrc`):

```bash
export OPENAI_API_KEY="sk-your-key-here"
```

Then restart your terminal or run:
```bashy
source ~/.zshrc  # or ~/.bash_profile
```

### Option 2: Build Settings (Xcode)

1. Open your project in Xcode
2. Select your target
3. Go to Build Settings
4. Add `OPENAI_API_KEY` as a User-Defined setting
5. Set the value to your API key

### Option 3: UserDefaults (Development Only)

For testing purposes, you can set it programmatically:

```swift
UserDefaults.standard.set("sk-your-key-here", forKey: "OPENAI_API_KEY")
```

## 🧪 Testing the Integration

1. **Build and Run**: Launch the Claimb app
2. **Navigate to Coaching**: Go to the Coaching tab
3. **Generate Insights**: Tap "Analyze" to get AI-powered coaching
4. **Check Logs**: Look for OpenAI API calls in the console

## 💰 Cost Considerations

- **Model Used**: `gpt-4o-mini` (cost-effective)
- **Token Limit**: 1000 tokens per request
- **Typical Cost**: ~$0.01-0.05 per analysis
- **Rate Limits**: 3 requests per minute (free tier)

## 🔒 Security Notes

- **Never commit API keys** to version control
- **Use environment variables** for production
- **Rotate keys regularly** for security
- **Monitor usage** in OpenAI dashboard

## 🐛 Troubleshooting

### "Invalid API Key" Error
- Verify the key starts with `sk-`
- Check for extra spaces or characters
- Ensure the key is active in OpenAI dashboard

### "Rate Limit Exceeded" Error
- Wait a few minutes before retrying
- Consider upgrading your OpenAI plan
- Check your usage in OpenAI dashboard

### "Network Error" Issues
- Check your internet connection
- Verify OpenAI API is accessible
- Check firewall settings

## 📊 Usage Monitoring

Monitor your API usage at:
- [OpenAI Usage Dashboard](https://platform.openai.com/usage)
- Set up billing alerts
- Track monthly costs

## 🆘 Support

If you encounter issues:
1. Check the console logs for detailed error messages
2. Verify your API key is correctly set
3. Test with a simple API call outside the app
4. Check OpenAI service status

---

**Note**: The Coaching section requires a valid OpenAI API key to function. Without it, you'll see an error message when trying to generate insights.
