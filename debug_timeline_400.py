#!/usr/bin/env python3
"""
Debug the 400 error from timeline-lite endpoint
"""

import requests
import json

def debug_timeline_400():
    """Debug why we're getting 400 from timeline-lite"""
    
    print("🔍 Debugging Timeline-Lite 400 Error")
    print("=" * 50)
    
    # Use the same URL and payload as the app
    url = "https://vqwgvfqrkoqgbwimiagi.supabase.co/functions/v1/claimb-function/riot/timeline-lite"
    
    # Test with the actual match ID from the logs
    payload = {
        "matchId": "EUW1_7549576032",  # From the logs
        "puuid": "test-puuid",  # We don't have the real PUUID
        "region": "europe"
    }
    
    headers = {
        "Content-Type": "application/json",
        "User-Agent": "Claimb-Test/1.0"
    }
    
    print(f"URL: {url}")
    print(f"Payload: {json.dumps(payload, indent=2)}")
    print()
    
    try:
        response = requests.post(url, json=payload, headers=headers, timeout=10)
        print(f"Status: {response.status_code}")
        print(f"Headers: {dict(response.headers)}")
        print(f"Response: {response.text}")
        
        if response.status_code == 400:
            print("\n💡 400 Error Analysis:")
            print("  - Bad Request - likely the endpoint doesn't exist yet")
            print("  - The edge function needs to be updated with timeline-lite route")
            print("  - Check if the route is properly deployed")
            
    except Exception as e:
        print(f"Error: {e}")

def test_existing_endpoints():
    """Test what endpoints are available"""
    
    print("\n" + "=" * 50)
    print("🧪 Testing Available Endpoints")
    print("=" * 50)
    
    base_url = "https://vqwgvfqrkoqgbwimiagi.supabase.co/functions/v1/claimb-function"
    
    endpoints = [
        "/riot/matches",
        "/riot/match", 
        "/riot/summoner",
        "/riot/account",
        "/ai/coach",
        "/riot/timeline-lite"  # This should be new
    ]
    
    for endpoint in endpoints:
        url = base_url + endpoint
        try:
            # Test with a simple GET request first
            response = requests.get(url, timeout=5)
            print(f"GET {endpoint}: {response.status_code}")
            
            # Test with POST if GET fails
            if response.status_code == 405:  # Method not allowed
                response = requests.post(url, json={}, timeout=5)
                print(f"POST {endpoint}: {response.status_code}")
                
        except Exception as e:
            print(f"{endpoint}: Error - {e}")

if __name__ == "__main__":
    debug_timeline_400()
    test_existing_endpoints()
