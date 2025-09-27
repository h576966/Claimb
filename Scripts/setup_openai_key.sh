#!/bin/bash

# OpenAI API Key Setup Script for Claimb
# This script helps you set up your OpenAI API key for development

echo "🔑 OpenAI API Key Setup for Claimb"
echo "=================================="
echo ""

# Check if OPENAI_API_KEY is already set
if [ ! -z "$OPENAI_API_KEY" ]; then
    echo "✅ OPENAI_API_KEY is already set in your environment"
    echo "Current key: ${OPENAI_API_KEY:0:10}..."
    echo ""
    read -p "Do you want to update it? (y/n): " update_key
    if [ "$update_key" != "y" ]; then
        echo "Keeping existing key."
        exit 0
    fi
fi

echo "To get your OpenAI API key:"
echo "1. Go to https://platform.openai.com/api-keys"
echo "2. Sign in to your OpenAI account"
echo "3. Click 'Create new secret key'"
echo "4. Copy the key (it starts with 'sk-')"
echo ""

read -p "Enter your OpenAI API key: " openai_key

if [ -z "$openai_key" ]; then
    echo "❌ No API key provided. Exiting."
    exit 1
fi

# Validate the key format
if [[ ! $openai_key =~ ^sk- ]]; then
    echo "⚠️  Warning: OpenAI API keys usually start with 'sk-'. Are you sure this is correct?"
    read -p "Continue anyway? (y/n): " continue_anyway
    if [ "$continue_anyway" != "y" ]; then
        echo "Exiting."
        exit 1
    fi
fi

# Set the environment variable for current session
export OPENAI_API_KEY="$openai_key"

# Add to shell profile for persistence
shell_profile=""
if [ -f "$HOME/.zshrc" ]; then
    shell_profile="$HOME/.zshrc"
elif [ -f "$HOME/.bash_profile" ]; then
    shell_profile="$HOME/.bash_profile"
elif [ -f "$HOME/.bashrc" ]; then
    shell_profile="$HOME/.bashrc"
fi

if [ ! -z "$shell_profile" ]; then
    echo ""
    echo "Adding OPENAI_API_KEY to $shell_profile for persistence..."
    
    # Remove any existing OPENAI_API_KEY line
    sed -i.bak '/OPENAI_API_KEY/d' "$shell_profile"
    
    # Add the new key
    echo "" >> "$shell_profile"
    echo "# OpenAI API Key for Claimb" >> "$shell_profile"
    echo "export OPENAI_API_KEY=\"$openai_key\"" >> "$shell_profile"
    
    echo "✅ Added to $shell_profile"
    echo "Note: You may need to restart your terminal or run 'source $shell_profile'"
else
    echo "⚠️  Could not find shell profile file. You'll need to manually add:"
    echo "export OPENAI_API_KEY=\"$openai_key\""
    echo "to your shell configuration file."
fi

echo ""
echo "🎉 OpenAI API key setup complete!"
echo ""
echo "To test the integration:"
echo "1. Build and run the Claimb app"
echo "2. Go to the Coaching section"
echo "3. Tap 'Analyze' to generate AI insights"
echo ""
echo "💡 Tip: The API key is also stored in UserDefaults for development,"
echo "   but environment variables are preferred for security."
