#!/usr/bin/env python3
"""
Test timeline endpoint after changes
"""

import requests
import json

def test_timeline_endpoint():
    """Test the timeline endpoint with different approaches"""
    
    print("🧪 Testing Timeline Endpoint After Changes")
    print("=" * 50)
    
    url = "https://vqwgvfqrkoqgbwimiagi.supabase.co/functions/v1/claimb-function/riot/timeline-lite"
    
    # Test 1: Without auth (should get 401)
    print("1️⃣ Testing without auth...")
    try:
        response = requests.post(url, json={"matchId": "test", "puuid": "test", "region": "europe"})
        print(f"   Status: {response.status_code}")
        print(f"   Response: {response.json()}")
    except Exception as e:
        print(f"   Error: {e}")
    
    # Test 2: With fake auth (should get 401)
    print("\n2️⃣ Testing with fake auth...")
    try:
        headers = {
            "Content-Type": "application/json",
            "Authorization": "Bearer fake-token",
            "X-Claimb-App-Token": "fake-token",
            "X-Claimb-Device": "test-device"
        }
        response = requests.post(url, json={"matchId": "test", "puuid": "test", "region": "europe"}, headers=headers)
        print(f"   Status: {response.status_code}")
        print(f"   Response: {response.json()}")
    except Exception as e:
        print(f"   Error: {e}")
    
    # Test 3: Check if endpoint exists (should not get 404)
    print("\n3️⃣ Testing endpoint existence...")
    try:
        response = requests.get(url)
        print(f"   GET Status: {response.status_code}")
        if response.status_code == 404:
            print("   ❌ Endpoint doesn't exist")
        else:
            print("   ✅ Endpoint exists")
    except Exception as e:
        print(f"   Error: {e}")
    
    # Test 4: Test with real match ID from logs
    print("\n4️⃣ Testing with real match ID...")
    try:
        headers = {
            "Content-Type": "application/json",
            "Authorization": "Bearer fake-token",
            "X-Claimb-App-Token": "fake-token", 
            "X-Claimb-Device": "test-device"
        }
        payload = {
            "matchId": "EUW1_7549576032",  # From your logs
            "puuid": "test-puuid",
            "region": "europe"
        }
        response = requests.post(url, json=payload, headers=headers)
        print(f"   Status: {response.status_code}")
        print(f"   Response: {response.json()}")
        
        if response.status_code == 400:
            print("   💡 400 = Bad request, but endpoint exists")
        elif response.status_code == 401:
            print("   💡 401 = Auth issue, but endpoint exists")
        elif response.status_code == 200:
            print("   🎉 SUCCESS! Timeline data received!")
        elif response.status_code == 404:
            print("   ❌ 404 = Endpoint not found")
            
    except Exception as e:
        print(f"   Error: {e}")

def test_other_endpoints():
    """Test other endpoints to see if they work"""
    
    print("\n" + "=" * 50)
    print("🔍 Testing Other Endpoints")
    print("=" * 50)
    
    base_url = "https://vqwgvfqrkoqgbwimiagi.supabase.co/functions/v1/claimb-function"
    
    # Test AI coach endpoint (should work)
    print("Testing AI coach endpoint...")
    try:
        ai_url = f"{base_url}/ai/coach"
        response = requests.post(ai_url, json={"prompt": "test"}, headers={"Content-Type": "application/json"})
        print(f"   AI Coach Status: {response.status_code}")
        if response.status_code == 401:
            print("   ✅ AI Coach endpoint exists (401 = auth required)")
        elif response.status_code == 200:
            print("   🎉 AI Coach working!")
        else:
            print(f"   Response: {response.text[:100]}")
    except Exception as e:
        print(f"   Error: {e}")

if __name__ == "__main__":
    test_timeline_endpoint()
    test_other_endpoints()
    
    print("\n" + "=" * 50)
    print("📋 Summary")
    print("=" * 50)
    print("If you're still getting 401 'Invalid JWT':")
    print("1. The endpoint exists but needs proper authentication")
    print("2. The app should work with real tokens")
    print("3. Try running the app to see if timeline integration works")
    print("\nIf you're getting 200:")
    print("🎉 Timeline integration is working!")
