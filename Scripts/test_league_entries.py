#!/usr/bin/env python3
"""
Test script for the league entries endpoint
Tests the riot/league-entries endpoint to verify it works correctly
"""

import requests
import json
import sys

# Configuration
BASE_URL = "https://vqwgvfqrkoqgbwimiagi.supabase.co/functions/v1/claimb-function"
APP_TOKEN = "aVerySecretToken"
DEVICE_ID = "test-device-123"

# Test data - using a known summoner ID
TEST_SUMMONER_ID = "test-summoner-id"  # This will need to be replaced with a real summoner ID
# Note: You can get a real summoner ID by running the main test script first to get a PUUID,
# then using that PUUID to get the summoner ID from the summoner endpoint
TEST_PLATFORM = "euw1"

def test_league_entries():
    """Test the league entries endpoint"""
    url = f"{BASE_URL}/riot/league-entries"
    
    headers = {
        "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZxd2d2ZnFya29xZ2J3aW1pYWdpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIwOTYwNTIsImV4cCI6MjA2NzY3MjA1Mn0.vBkevqMe1kfzdZCgrqjsFRRY46_N-NoiPS9EMKU3EjA",
        "X-Claimb-App-Token": APP_TOKEN,
        "X-Claimb-Device": DEVICE_ID,
        "Content-Type": "application/json"
    }
    
    params = {
        "summonerId": TEST_SUMMONER_ID,
        "platform": TEST_PLATFORM
    }
    
    print(f"🔍 Testing league entries endpoint")
    print(f"   URL: {url}")
    print(f"   Params: {params}")
    
    try:
        response = requests.get(url, headers=headers, params=params, timeout=30)
        print(f"   Status: {response.status_code}")
        
        # Print response headers
        print("   Headers:")
        for key, value in response.headers.items():
            if key.lower().startswith(('x-', 'access-control')):
                print(f"     {key}: {value}")
        
        # Parse response
        try:
            response_data = response.json()
            print(f"   Response: {json.dumps(response_data, indent=2)}")
        except:
            print(f"   Response: {response.text}")
        
        if response.status_code == 200:
            print("   ✅ SUCCESS: League entries endpoint is working")
            return True
        else:
            print(f"   ❌ FAILED: Status {response.status_code}")
            return False
            
    except requests.exceptions.Timeout:
        print("   ❌ Timeout")
        return False
    except requests.exceptions.RequestException as e:
        print(f"   ❌ Request error: {e}")
        return False
    except Exception as e:
        print(f"   ❌ Unexpected error: {e}")
        return False

def main():
    print("🚀 League Entries Endpoint Tester")
    print("=" * 50)
    
    success = test_league_entries()
    
    if success:
        print("\n🎉 League entries endpoint is working correctly!")
    else:
        print("\n⚠️  League entries endpoint test failed.")
        print("   This could mean:")
        print("   1. The endpoint is not implemented in the edge function")
        print("   2. The endpoint is not registered in the router")
        print("   3. There's an authentication issue")
        print("   4. The summoner ID is invalid")

if __name__ == "__main__":
    main()
