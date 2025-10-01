#!/usr/bin/env python3
"""
Simple test for timeline-lite endpoint
"""

import requests
import json

# Test the endpoint with a simple request
url = "https://vqwgvfqrkoqgbwimiagi.supabase.co/functions/v1/claimb-function/riot/timeline-lite"

payload = {
    "matchId": "EUW1_1234567890",
    "puuid": "test-puuid-123",
    "region": "europe"
}

headers = {
    "Content-Type": "application/json",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZxd2d2ZnFya29xZ2J3aW1pYWdpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzU1NzQ0MDAsImV4cCI6MjA1MTE1MDQwMH0.placeholder",  # This is a placeholder
    "X-Claimb-App-Token": "test-token",
    "X-Claimb-Device": "test-device",
    "User-Agent": "Claimb-Test/1.0"
}

print("Testing timeline-lite endpoint...")
print(f"URL: {url}")
print(f"Payload: {json.dumps(payload, indent=2)}")

try:
    response = requests.post(url, json=payload, headers=headers, timeout=10)
    print(f"\nStatus Code: {response.status_code}")
    print(f"Response Headers: {dict(response.headers)}")
    print(f"\nResponse Body:")
    print(response.text)
except Exception as e:
    print(f"Error: {e}")
