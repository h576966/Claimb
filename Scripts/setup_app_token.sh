#!/bin/bash

# App Shared Token Setup Script for Claimb
# This script helps you set up your APP_SHARED_TOKEN for Supabase edge function authentication

echo "🔑 App Shared Token Setup for Claimb"
echo "====================================="
echo ""

# Check if APP_SHARED_TOKEN is already set
if [ ! -z "$APP_SHARED_TOKEN" ]; then
    echo "✅ APP_SHARED_TOKEN is already set in your environment"
    echo "Current token: ${APP_SHARED_TOKEN:0:10}..."
    echo ""
    read -p "Do you want to update it? (y/n): " update_token
    if [ "$update_token" != "y" ]; then
        echo "Keeping existing token."
        exit 0
    fi
fi

echo "To get your App Shared Token:"
echo "1. Contact your administrator for the APP_SHARED_TOKEN"
echo "2. This token is used to authenticate with your Supabase edge function"
echo "3. The token should be a secure string provided by your backend team"
echo ""

read -p "Enter your App Shared Token: " app_token

if [ -z "$app_token" ]; then
    echo "❌ No token provided. Exiting."
    exit 1
fi

# Validate token format (basic check)
if [ ${#app_token} -lt 10 ]; then
    echo "⚠️  Warning: Token seems too short. Please verify it's correct."
fi

echo ""
echo "Setting up APP_SHARED_TOKEN..."

# Set for current session
export APP_SHARED_TOKEN="$app_token"
echo "✅ APP_SHARED_TOKEN set for current session"

# Determine shell profile
if [ -f ~/.zshrc ]; then
    PROFILE_FILE="~/.zshrc"
    SHELL_NAME="zsh"
elif [ -f ~/.bash_profile ]; then
    PROFILE_FILE="~/.bash_profile"
    SHELL_NAME="bash"
elif [ -f ~/.bashrc ]; then
    PROFILE_FILE="~/.bashrc"
    SHELL_NAME="bash"
else
    echo "⚠️  Could not find shell profile file. Please add manually:"
    echo "export APP_SHARED_TOKEN=\"$app_token\""
    exit 0
fi

# Add to shell profile
echo "" >> ~/.zshrc 2>/dev/null || echo "" >> ~/.bash_profile 2>/dev/null || echo "" >> ~/.bashrc 2>/dev/null
echo "# Claimb App Shared Token" >> ~/.zshrc 2>/dev/null || echo "# Claimb App Shared Token" >> ~/.bash_profile 2>/dev/null || echo "# Claimb App Shared Token" >> ~/.bashrc 2>/dev/null
echo "export APP_SHARED_TOKEN=\"$app_token\"" >> ~/.zshrc 2>/dev/null || echo "export APP_SHARED_TOKEN=\"$app_token\"" >> ~/.bash_profile 2>/dev/null || echo "export APP_SHARED_TOKEN=\"$app_token\"" >> ~/.bashrc 2>/dev/null

echo "✅ APP_SHARED_TOKEN added to $PROFILE_FILE"
echo ""
echo "🚀 Setup complete! Your App Shared Token is now configured."
echo ""
echo "To use in Xcode:"
echo "1. Restart Xcode to pick up the new environment variable"
echo "2. Or add it to your Xcode scheme's environment variables"
echo ""
echo "To verify setup:"
echo "Run: echo \$APP_SHARED_TOKEN"
echo ""

# Verify the setup
echo "Verifying setup..."
if [ "$APP_SHARED_TOKEN" = "$app_token" ]; then
    echo "✅ Verification successful!"
else
    echo "❌ Verification failed. Please restart your terminal."
fi
