#!/bin/bash
# Test Dual Prompt Structure with Supabase Edge Function
# This tests if the edge function correctly handles system + user prompts

set -e

echo "🧪 Testing Dual Prompt Structure"
echo "================================"
echo ""

# Configuration
EDGE_FUNCTION_URL="https://vqwgvfqrkoqgbwimiagi.supabase.co/functions/v1/claimb-function/ai/coach"
APP_TOKEN="your-app-token-here"  # Replace with actual token from AppConfig

# Test 1: Single Prompt (Current Behavior)
echo "Test 1: Single Prompt (Baseline)"
echo "---------------------------------"

SINGLE_PROMPT_PAYLOAD='{
  "prompt": "You are a League of Legends coach.\n\n**GAME CONTEXT:**\nPlayer: TestPlayer | Champion: Aatrox | Role: TOP\nResult: Victory | KDA: 10/3/5 | Duration: 25min\n\n**PERFORMANCE METRICS:**\n- CS: 6.5/min (Good)\n- Deaths: 3 (Needs Improvement)\n\n**OUTPUT (JSON):**\n{\n  \"keyTakeaways\": [\"insight1\", \"insight2\", \"insight3\"],\n  \"championSpecificAdvice\": \"advice here\",\n  \"nextGameFocus\": [\"goal\", \"target\"]\n}\n\nRespond with ONLY valid JSON.",
  "model": "gpt-5-mini",
  "max_output_tokens": 800,
  "reasoning_effort": "low",
  "text_format": "json"
}'

echo "Request:"
echo "$SINGLE_PROMPT_PAYLOAD" | jq '.'
echo ""

RESPONSE_SINGLE=$(curl -s -X POST "$EDGE_FUNCTION_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $APP_TOKEN" \
  -d "$SINGLE_PROMPT_PAYLOAD")

echo "Response:"
echo "$RESPONSE_SINGLE" | jq '.'
echo ""
echo "Response Quality Check:"
echo "$RESPONSE_SINGLE" | jq -r '.text' | jq '.' 2>&1 && echo "✅ Valid JSON" || echo "❌ Invalid JSON"
echo ""
echo ""

# Test 2: Dual Prompt (New Behavior)
echo "Test 2: Dual Prompt (System + User)"
echo "------------------------------------"

DUAL_PROMPT_PAYLOAD='{
  "system": "You are an expert League of Legends coach specializing in ranked performance improvement.\n\n**YOUR ROLE:**\n- Analyze game performance data and provide actionable coaching advice\n- Help players identify their biggest improvement opportunities\n- Maintain a supportive but direct coaching style\n\n**OUTPUT REQUIREMENTS:**\n- Format: ONLY valid JSON (no markdown, no extra text)\n- Length: Maximum 110 words total\n- Structure: Must include keyTakeaways (3), championSpecificAdvice (2 sentences), nextGameFocus (2)\n\n**METRIC INTERPRETATION:**\n- \"Good\" = above average → acknowledge briefly\n- \"Needs Improvement\" = below average → suggest specific practice focus\n\n**FOCUS PRIORITY:**\n1. Metrics marked \"Needs Improvement\" - highest priority\n2. NEVER suggest improving metrics marked \"Good\"",
  "prompt": "**GAME CONTEXT:**\nPlayer: TestPlayer | Champion: Aatrox | Role: TOP\nResult: Victory | KDA: 10/3/5 | Duration: 25min\n\n**PERFORMANCE METRICS:**\n- CS: 6.5/min (Good)\n- Deaths: 3 (Needs Improvement)\n\n**OUTPUT (JSON):**\n{\n  \"keyTakeaways\": [\"insight1\", \"insight2\", \"insight3\"],\n  \"championSpecificAdvice\": \"advice here\",\n  \"nextGameFocus\": [\"goal\", \"target\"]\n}",
  "model": "gpt-5-mini",
  "max_output_tokens": 800,
  "reasoning_effort": "low",
  "text_format": "json"
}'

echo "Request (System):"
echo "$DUAL_PROMPT_PAYLOAD" | jq '.system'
echo ""
echo "Request (Prompt):"
echo "$DUAL_PROMPT_PAYLOAD" | jq '.prompt'
echo ""

RESPONSE_DUAL=$(curl -s -X POST "$EDGE_FUNCTION_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $APP_TOKEN" \
  -d "$DUAL_PROMPT_PAYLOAD")

echo "Response:"
echo "$RESPONSE_DUAL" | jq '.'
echo ""
echo "Response Quality Check:"
echo "$RESPONSE_DUAL" | jq -r '.text' | jq '.' 2>&1 && echo "✅ Valid JSON" || echo "❌ Invalid JSON"
echo ""
echo ""

# Comparison
echo "📊 Comparison"
echo "============="
echo ""
echo "Single Prompt Response:"
echo "$RESPONSE_SINGLE" | jq -r '.text' | jq '.'
echo ""
echo "Dual Prompt Response:"
echo "$RESPONSE_DUAL" | jq -r '.text' | jq '.'
echo ""

# Check for improvements
echo "Quality Analysis:"
echo "-----------------"

SINGLE_LENGTH=$(echo "$RESPONSE_SINGLE" | jq -r '.text' | wc -c)
DUAL_LENGTH=$(echo "$RESPONSE_DUAL" | jq -r '.text' | wc -c)

echo "Single prompt response length: $SINGLE_LENGTH chars"
echo "Dual prompt response length: $DUAL_LENGTH chars"
echo ""

# Check if dual prompt focuses on "Needs Improvement" metric
if echo "$RESPONSE_DUAL" | jq -r '.text' | grep -i "death" > /dev/null; then
  echo "✅ Dual prompt addresses 'Needs Improvement' metric (Deaths)"
else
  echo "⚠️  Dual prompt may not address 'Needs Improvement' metric"
fi

echo ""
echo "🎯 Test Complete!"
echo "================="
echo ""
echo "Next Steps:"
echo "1. Review both responses above"
echo "2. Compare tone, focus, and actionability"
echo "3. Verify dual prompt addresses 'Deaths' metric (Needs Improvement)"
echo "4. If dual prompt is superior, proceed with implementation"

