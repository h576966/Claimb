#!/usr/bin/env python3
"""
Test script for the timeline-lite endpoint
"""

import requests
import json
import sys
from datetime import datetime

# Configuration
BASE_URL = "https://vqwgvfqrkoqgbwimiagi.supabase.co/functions/v1/claimb-function"
ENDPOINT = f"{BASE_URL}/riot/timeline-lite"

# Test data - using a real match ID from your logs
TEST_MATCH_ID = "EUW1_1234567890"  # Replace with actual match ID
TEST_PUUID = "test-puuid"  # Replace with actual PUUID
TEST_REGION = "europe"

def test_timeline_endpoint():
    """Test the timeline-lite endpoint"""
    
    print(f"🧪 Testing Timeline-Lite Endpoint")
    print(f"📍 URL: {ENDPOINT}")
    print(f"📅 Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 60)
    
    # Prepare request data
    payload = {
        "matchId": TEST_MATCH_ID,
        "puuid": TEST_PUUID,
        "region": TEST_REGION
    }
    
    headers = {
        "Content-Type": "application/json",
        "Authorization": "Bearer YOUR_ANON_KEY",  # Replace with actual key
        "X-Claimb-App-Token": "YOUR_APP_TOKEN",   # Replace with actual token
        "X-Claimb-Device": "test-device",
        "User-Agent": "Claimb-Test/1.0"
    }
    
    print(f"📤 Request Payload:")
    print(json.dumps(payload, indent=2))
    print()
    
    try:
        # Make the request
        print("🚀 Sending request...")
        response = requests.post(
            ENDPOINT,
            json=payload,
            headers=headers,
            timeout=30
        )
        
        print(f"📊 Response Status: {response.status_code}")
        print(f"📏 Response Length: {len(response.text)} characters")
        print()
        
        # Print response headers
        print("📋 Response Headers:")
        for key, value in response.headers.items():
            if key.lower().startswith('x-'):
                print(f"  {key}: {value}")
        print()
        
        # Parse and display response
        if response.status_code == 200:
            try:
                data = response.json()
                print("✅ Success! Response Data:")
                print(json.dumps(data, indent=2))
                
                # Analyze the response structure
                print("\n🔍 Response Analysis:")
                if "checkpoints" in data:
                    print(f"  • 10min CS: {data['checkpoints'].get('10min', {}).get('cs', 'N/A')}")
                    print(f"  • 15min CS: {data['checkpoints'].get('15min', {}).get('cs', 'N/A')}")
                if "timings" in data:
                    print(f"  • First Back: {data['timings'].get('firstBackMin', 'N/A')} min")
                    print(f"  • First Item: {data['timings'].get('firstFullItemMin', 'N/A')} min")
                if "visionPre15" in data:
                    print(f"  • Wards Placed: {data['visionPre15'].get('wardsPlaced', 'N/A')}")
                    print(f"  • Control Wards: {data['visionPre15'].get('controlWards', 'N/A')}")
                print(f"  • Tower Plates: {data.get('platesPre14', 'N/A')}")
                
            except json.JSONDecodeError as e:
                print(f"❌ Failed to parse JSON response: {e}")
                print(f"Raw response: {response.text[:500]}...")
        else:
            print(f"❌ Error Response:")
            print(f"Status: {response.status_code}")
            print(f"Text: {response.text}")
            
    except requests.exceptions.RequestException as e:
        print(f"❌ Request failed: {e}")
        return False
    
    return response.status_code == 200

def test_with_real_data():
    """Test with real match data if available"""
    print("\n" + "=" * 60)
    print("🔍 Testing with Real Match Data")
    print("=" * 60)
    
    # You can replace these with actual values from your app logs
    real_match_id = input("Enter a real match ID (or press Enter to skip): ").strip()
    real_puuid = input("Enter a real PUUID (or press Enter to skip): ").strip()
    
    if real_match_id and real_puuid:
        global TEST_MATCH_ID, TEST_PUUID
        TEST_MATCH_ID = real_match_id
        TEST_PUUID = real_puuid
        return test_timeline_endpoint()
    else:
        print("⏭️  Skipping real data test")
        return True

if __name__ == "__main__":
    print("🎮 Claimb Timeline-Lite Endpoint Tester")
    print("=" * 60)
    
    # Test with dummy data first
    success = test_timeline_endpoint()
    
    if success:
        print("\n✅ Basic test completed successfully!")
        
        # Ask if user wants to test with real data
        test_real = input("\nTest with real match data? (y/N): ").strip().lower()
        if test_real == 'y':
            test_with_real_data()
    else:
        print("\n❌ Basic test failed!")
        sys.exit(1)
    
    print("\n🏁 Testing complete!")
