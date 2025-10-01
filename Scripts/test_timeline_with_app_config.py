#!/usr/bin/env python3
"""
Test timeline endpoint using the same configuration as the app
"""

import requests
import json
import sys
import os

def test_timeline_endpoint():
    """Test the timeline-lite endpoint with proper authentication"""
    
    # Use the same base URL as the app
    base_url = "https://vqwgvfqrkoqgbwimiagi.supabase.co/functions/v1/claimb-function"
    endpoint = f"{base_url}/riot/timeline-lite"
    
    print("🧪 Testing Timeline-Lite Endpoint")
    print(f"📍 URL: {endpoint}")
    print("=" * 60)
    
    # Test payload - using a dummy match ID for now
    payload = {
        "matchId": "EUW1_1234567890",
        "puuid": "test-puuid-123",
        "region": "europe"
    }
    
    # Headers similar to what the app would send
    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Accept-Encoding": "gzip, deflate, br",
        "Connection": "keep-alive",
        "User-Agent": "Claimb/1.0 (iOS)",
        "X-Claimb-Device": "test-device-123",
        # Note: We need real tokens here
        "Authorization": "Bearer YOUR_ANON_KEY",  # Replace with actual anon key
        "X-Claimb-App-Token": "YOUR_APP_TOKEN"    # Replace with actual app token
    }
    
    print("📤 Request Details:")
    print(f"  Method: POST")
    print(f"  URL: {endpoint}")
    print(f"  Headers: {len(headers)} headers")
    print(f"  Payload: {json.dumps(payload, indent=2)}")
    print()
    
    try:
        print("🚀 Sending request...")
        response = requests.post(
            endpoint,
            json=payload,
            headers=headers,
            timeout=30
        )
        
        print(f"📊 Response Status: {response.status_code}")
        print(f"📏 Response Length: {len(response.text)} characters")
        print()
        
        # Print important headers
        print("📋 Response Headers:")
        important_headers = [
            'content-type', 'x-claimb-shape', 'x-ratelimit-remaining',
            'x-served-by', 'cf-ray', 'access-control-allow-origin'
        ]
        for header in important_headers:
            if header in response.headers:
                print(f"  {header}: {response.headers[header]}")
        print()
        
        # Parse response
        if response.status_code == 200:
            try:
                data = response.json()
                print("✅ Success! Timeline Data Received:")
                print(json.dumps(data, indent=2))
                
                # Analyze the structure
                print("\n🔍 Data Structure Analysis:")
                if isinstance(data, dict):
                    print(f"  • Top-level keys: {list(data.keys())}")
                    
                    if "checkpoints" in data:
                        checkpoints = data["checkpoints"]
                        print(f"  • Checkpoints available: {list(checkpoints.keys())}")
                        
                        if "10min" in checkpoints:
                            ten_min = checkpoints["10min"]
                            print(f"    - 10min data: {list(ten_min.keys())}")
                            print(f"    - 10min CS: {ten_min.get('cs', 'N/A')}")
                            print(f"    - 10min Gold: {ten_min.get('gold', 'N/A')}")
                            print(f"    - 10min KDA: {ten_min.get('kda', 'N/A')}")
                        
                        if "15min" in checkpoints:
                            fifteen_min = checkpoints["15min"]
                            print(f"    - 15min data: {list(fifteen_min.keys())}")
                            print(f"    - 15min CS: {fifteen_min.get('cs', 'N/A')}")
                            print(f"    - 15min Gold: {fifteen_min.get('gold', 'N/A')}")
                            print(f"    - 15min KDA: {fifteen_min.get('kda', 'N/A')}")
                    
                    if "timings" in data:
                        timings = data["timings"]
                        print(f"  • Timings: {list(timings.keys())}")
                        for key, value in timings.items():
                            print(f"    - {key}: {value}")
                    
                    if "visionPre15" in data:
                        vision = data["visionPre15"]
                        print(f"  • Vision data: {list(vision.keys())}")
                        for key, value in vision.items():
                            print(f"    - {key}: {value}")
                    
                    if "platesPre14" in data:
                        print(f"  • Tower plates: {data['platesPre14']}")
                
            except json.JSONDecodeError as e:
                print(f"❌ Failed to parse JSON: {e}")
                print(f"Raw response: {response.text[:500]}...")
        else:
            print(f"❌ Error Response ({response.status_code}):")
            try:
                error_data = response.json()
                print(json.dumps(error_data, indent=2))
            except:
                print(response.text)
            
            if response.status_code == 401:
                print("\n💡 Authentication Error - Need valid tokens:")
                print("  - SupabaseAnonKey (Authorization header)")
                print("  - AppSharedToken (X-Claimb-App-Token header)")
            elif response.status_code == 404:
                print("\n💡 Endpoint not found - Check if timeline-lite is deployed")
            elif response.status_code == 500:
                print("\n💡 Server error - Check edge function logs")
                
    except requests.exceptions.RequestException as e:
        print(f"❌ Request failed: {e}")
        return False
    
    return response.status_code == 200

def show_expected_format():
    """Show the expected response format based on the edge function code"""
    print("\n" + "=" * 60)
    print("📋 Expected Response Format (from edge function code)")
    print("=" * 60)
    
    expected = {
        "matchId": "EUW1_1234567890",
        "region": "europe", 
        "puuid": "test-puuid-123",
        "participantId": 1,
        "checkpoints": {
            "10min": {
                "cs": 85,
                "gold": 3200,
                "xp": 5000,
                "kda": "2/1/0"
            },
            "15min": {
                "cs": 120,
                "gold": 4800,
                "xp": 7500,
                "kda": "3/2/1"
            }
        },
        "timings": {
            "firstBackMin": 6,
            "firstFullItemMin": 12,
            "firstKillMin": 4,
            "firstDeathMin": 8
        },
        "visionPre15": {
            "wardsPlaced": 3,
            "wardsKilled": 1,
            "controlWards": 1
        },
        "platesPre14": 2
    }
    
    print("Expected JSON structure:")
    print(json.dumps(expected, indent=2))
    
    print("\n📝 Notes:")
    print("  • This is the format the edge function should return")
    print("  • All timing values are in minutes")
    print("  • CS includes both minions and jungle minions")
    print("  • KDA is formatted as 'kills/deaths/assists'")
    print("  • Vision data is pre-15 minutes only")
    print("  • Tower plates are pre-14 minutes only")

if __name__ == "__main__":
    print("🎮 Claimb Timeline-Lite Endpoint Tester")
    print("=" * 60)
    
    # Show expected format first
    show_expected_format()
    
    print("\n" + "=" * 60)
    print("🧪 Running Test")
    print("=" * 60)
    
    # Run the test
    success = test_timeline_endpoint()
    
    if success:
        print("\n✅ Test completed successfully!")
    else:
        print("\n❌ Test failed - check authentication tokens")
        print("\nTo get real tokens:")
        print("1. Check your Supabase project settings for anon key")
        print("2. Check your app's build settings for AppSharedToken")
        print("3. Update the headers in this script")
    
    print("\n🏁 Testing complete!")
