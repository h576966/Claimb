#!/bin/bash

# Claimb Simulator Network Debugging Script
# This script sets up environment variables to improve network reliability in the iOS Simulator

echo "🔧 Setting up Claimb simulator network debugging..."

# Set network debugging environment variables
export CFNETWORK_DIAGNOSTICS=1
export NSURLSessionDebug=1
export NSURLCacheDebug=1

# QUIC-specific debugging
export CFNETWORK_QUIC_DEBUG=1
export CFNETWORK_HTTP3_DEBUG=1

# Network timeout debugging
export CFNETWORK_TIMEOUT_DEBUG=1

# DNS debugging
export CFNETWORK_DNS_DEBUG=1

echo "✅ Network debugging environment variables set"
echo ""
echo "📱 To use these settings:"
echo "1. Run this script before launching Xcode"
echo "2. Or add these to your Xcode scheme's Environment Variables"
echo "3. Or set them in Xcode: Product > Scheme > Edit Scheme > Run > Arguments > Environment Variables"
echo ""
echo "🔍 Available debugging flags:"
echo "- CFNETWORK_DIAGNOSTICS=1     # General network diagnostics"
echo "- NSURLSessionDebug=1         # URLSession debugging"
echo "- NSURLCacheDebug=1           # Cache debugging"
echo "- CFNETWORK_QUIC_DEBUG=1      # QUIC protocol debugging"
echo "- CFNETWORK_HTTP3_DEBUG=1     # HTTP/3 debugging"
echo "- CFNETWORK_TIMEOUT_DEBUG=1   # Timeout debugging"
echo "- CFNETWORK_DNS_DEBUG=1       # DNS resolution debugging"
echo ""
echo "💡 Tip: Check Console.app for detailed network logs when debugging"
