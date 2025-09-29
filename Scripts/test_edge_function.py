#!/usr/bin/env python3
"""
Test script for Claimb edge function endpoints
Tests all Riot API endpoints to verify they work correctly
"""

import requests
import json
import sys
import time
from typing import Dict, Any, Optional

# Configuration
BASE_URL = "https://vqwgvfqrkoqgbwimiagi.supabase.co/functions/v1/claimb-function"
APP_TOKEN = "aVerySecretToken"
DEVICE_ID = "test-device-123"

# Test data
TEST_GAME_NAME = "PastMyBedTime"
TEST_TAG_LINE = "EUW"
TEST_REGION = "europe"
TEST_PLATFORM = "euw1"

class EdgeFunctionTester:
    def __init__(self, base_url: str, app_token: str, device_id: str):
        self.base_url = base_url
        self.headers = {
            "Authorization": f"Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZxd2d2ZnFya29xZ2J3aW1pYWdpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIwOTYwNTIsImV4cCI6MjA2NzY3MjA1Mn0.vBkevqMe1kfzdZCgrqjsFRRY46_N-NoiPS9EMKU3EjA",
            "X-Claimb-App-Token": app_token,
            "X-Claimb-Device": device_id,
            "Content-Type": "application/json"
        }
    
    def test_endpoint(self, endpoint: str, method: str = "GET", params: Optional[Dict] = None, data: Optional[Dict] = None) -> Dict[str, Any]:
        """Test a single endpoint"""
        url = f"{self.base_url}/{endpoint}"
        
        print(f"\n🔍 Testing {method} {endpoint}")
        print(f"   URL: {url}")
        if params:
            print(f"   Params: {params}")
        if data:
            print(f"   Data: {data}")
        
        try:
            if method == "GET":
                response = requests.get(url, headers=self.headers, params=params, timeout=30)
            elif method == "POST":
                response = requests.post(url, headers=self.headers, params=params, json=data, timeout=30)
            else:
                raise ValueError(f"Unsupported method: {method}")
            
            print(f"   Status: {response.status_code}")
            
            # Print response headers
            print("   Headers:")
            for key, value in response.headers.items():
                if key.lower().startswith(('x-', 'access-control')):
                    print(f"     {key}: {value}")
            
            # Parse response
            try:
                response_data = response.json()
                print(f"   Response: {json.dumps(response_data, indent=2)[:500]}...")
            except:
                print(f"   Response: {response.text[:200]}...")
            
            return {
                "status_code": response.status_code,
                "headers": dict(response.headers),
                "data": response_data if 'response_data' in locals() else response.text,
                "success": 200 <= response.status_code < 300
            }
            
        except requests.exceptions.Timeout:
            print("   ❌ Timeout")
            return {"error": "timeout", "success": False}
        except requests.exceptions.RequestException as e:
            print(f"   ❌ Request error: {e}")
            return {"error": str(e), "success": False}
        except Exception as e:
            print(f"   ❌ Unexpected error: {e}")
            return {"error": str(e), "success": False}
    
    def test_riot_account(self) -> Dict[str, Any]:
        """Test /riot/account endpoint"""
        params = {
            "gameName": TEST_GAME_NAME,
            "tagLine": TEST_TAG_LINE,
            "region": TEST_REGION
        }
        return self.test_endpoint("riot/account", params=params)
    
    def test_riot_summoner(self, puuid: str) -> Dict[str, Any]:
        """Test /riot/summoner endpoint"""
        params = {
            "puuid": puuid,
            "platform": TEST_PLATFORM
        }
        return self.test_endpoint("riot/summoner", params=params)
    
    def test_riot_matches(self, puuid: str) -> Dict[str, Any]:
        """Test /riot/matches endpoint"""
        params = {
            "puuid": puuid,
            "region": TEST_REGION,
            "count": 5
        }
        return self.test_endpoint("riot/matches", params=params)
    
    def test_riot_match(self, match_id: str) -> Dict[str, Any]:
        """Test /riot/match endpoint"""
        params = {
            "matchId": match_id,
            "region": TEST_REGION
        }
        return self.test_endpoint("riot/match", params=params)
    
    def test_ai_coach(self) -> Dict[str, Any]:
        """Test /ai/coach endpoint"""
        data = {
            "prompt": "Test coaching prompt",
            "model": "gpt-5-mini",
            "max_output_tokens": 100
        }
        return self.test_endpoint("ai/coach", method="POST", data=data)
    
    def test_root(self) -> Dict[str, Any]:
        """Test root endpoint"""
        return self.test_endpoint("")

def main():
    print("🚀 Claimb Edge Function Endpoint Tester")
    print("=" * 50)
    
    tester = EdgeFunctionTester(BASE_URL, APP_TOKEN, DEVICE_ID)
    
    results = {}
    
    # Test 1: Root endpoint
    print("\n📋 Test 1: Root endpoint")
    results["root"] = tester.test_root()
    
    # Test 2: Riot Account lookup
    print("\n👤 Test 2: Riot Account lookup")
    account_result = tester.test_riot_account()
    results["account"] = account_result
    
    if not account_result.get("success"):
        print("\n❌ Account lookup failed, cannot continue with dependent tests")
        print_results_summary(results)
        return
    
    # Extract PUUID from account response
    account_data = account_result.get("data", {})
    if isinstance(account_data, dict):
        puuid = account_data.get("puuid")
    else:
        print("❌ Could not extract PUUID from account response")
        print_results_summary(results)
        return
    
    if not puuid:
        print("❌ No PUUID found in account response")
        print_results_summary(results)
        return
    
    print(f"\n✅ Found PUUID: {puuid[:20]}...")
    
    # Test 3: Riot Summoner lookup
    print("\n🏆 Test 3: Riot Summoner lookup")
    results["summoner"] = tester.test_riot_summoner(puuid)
    
    # Test 4: Riot Matches lookup
    print("\n🎮 Test 4: Riot Matches lookup")
    matches_result = tester.test_riot_matches(puuid)
    results["matches"] = matches_result
    
    # Test 5: Riot Match detail (if we have match IDs)
    if matches_result.get("success") and isinstance(matches_result.get("data"), list):
        match_ids = matches_result["data"]
        if match_ids:
            match_id = match_ids[0]
            print(f"\n📊 Test 5: Riot Match detail (using {match_id})")
            results["match_detail"] = tester.test_riot_match(match_id)
        else:
            print("\n⚠️  No match IDs found, skipping match detail test")
            results["match_detail"] = {"skipped": "no_match_ids"}
    else:
        print("\n⚠️  Matches lookup failed, skipping match detail test")
        results["match_detail"] = {"skipped": "matches_failed"}
    
    # Test 6: AI Coach
    print("\n🤖 Test 6: AI Coach")
    results["ai_coach"] = tester.test_ai_coach()
    
    # Summary
    print_results_summary(results)

def print_results_summary(results: Dict[str, Any]):
    print("\n" + "=" * 50)
    print("📊 TEST RESULTS SUMMARY")
    print("=" * 50)
    
    total_tests = 0
    successful_tests = 0
    
    for test_name, result in results.items():
        total_tests += 1
        if result.get("success"):
            successful_tests += 1
            status = "✅ PASS"
        elif result.get("skipped"):
            status = f"⏭️  SKIP ({result['skipped']})"
            total_tests -= 1  # Don't count skipped tests
        else:
            status = "❌ FAIL"
        
        print(f"{status} {test_name.upper()}")
        
        if not result.get("success") and not result.get("skipped"):
            error = result.get("error", "Unknown error")
            print(f"     Error: {error}")
    
    print(f"\n🎯 Results: {successful_tests}/{total_tests} tests passed")
    
    if successful_tests == total_tests:
        print("🎉 All tests passed! Edge function is working correctly.")
    else:
        print("⚠️  Some tests failed. Check the logs above for details.")

if __name__ == "__main__":
    main()
