#!/bin/bash

# Bedrock Usage Report
# Generates a summary of Bedrock API usage by caller (IAM role/user),
# including daily invocation counts and token consumption trends.
#
# Usage: aws-vault exec <profile> -- ./bedrock_usage_report.sh [days]
#   days: number of days to look back (default: 30)

set -euo pipefail

DAYS="${1:-30}"
start_time="$(date -u -d "${DAYS} days ago" '+%Y-%m-%dT%H:%M:%SZ')"
end_time="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

echo "=============================================="
echo "  Bedrock Usage Report"
echo "  Period: last ${DAYS} days"
echo "  From:   ${start_time}"
echo "  To:     ${end_time}"
echo "=============================================="
echo ""

# ── Section 1: Models in use ──────────────────────────────────────────────
echo "── Models in use ──"
echo ""
aws cloudwatch list-metrics --namespace AWS/Bedrock --metric-name Invocations \
    --query 'Metrics[?Dimensions[0].Name==`ModelId`].Dimensions[0].Value' \
    --output text | tr '\t' '\n' | sort -u | while read -r model; do
    [ -z "$model" ] && continue
    total=$(aws cloudwatch get-metric-statistics --namespace AWS/Bedrock \
        --metric-name Invocations \
        --dimensions Name=ModelId,Value="$model" \
        --start-time "$start_time" --end-time "$end_time" \
        --period $((DAYS * 86400)) --statistics Sum \
        --query 'Datapoints[0].Sum' --output text 2>/dev/null)
    [ "$total" = "None" ] && total=0
    printf "  %-55s %s invocations\n" "$model" "$total"
done
echo ""

# ── Section 2: Callers by CloudTrail (who is calling Bedrock) ─────────────
echo "── Top callers (via CloudTrail) ──"
echo ""

callers_json=$(aws cloudtrail lookup-events \
    --lookup-attributes AttributeKey=EventSource,AttributeValue=bedrock.amazonaws.com \
    --start-time "$start_time" --end-time "$end_time" \
    --max-results 200 \
    --query 'Events[*].{username: Username, event: CloudTrailEvent}' \
    --output json 2>/dev/null)

# Summarise by caller
echo "$callers_json" | python3 -c "
import json, sys, collections

events = json.load(sys.stdin)
caller_stats = collections.defaultdict(lambda: {'count': 0, 'input_tokens': 0, 'output_tokens': 0, 'apis': set(), 'source_arns': set()})

for e in events:
    username = e['username']
    detail = json.loads(e['event'])
    event_name = detail.get('eventName', 'Unknown')
    additional = detail.get('additionalEventData', {})
    in_scope = detail.get('userIdentity', {}).get('inScopeOf', {})

    stats = caller_stats[username]
    stats['count'] += 1
    stats['input_tokens'] += additional.get('inputTokens', 0)
    stats['output_tokens'] += additional.get('outputTokens', 0)
    stats['apis'].add(event_name)
    if in_scope.get('credentialsIssuedTo'):
        stats['source_arns'].add(in_scope['credentialsIssuedTo'])

# Sort by count descending
for user, stats in sorted(caller_stats.items(), key=lambda x: -x[1]['count']):
    apis = ', '.join(sorted(stats['apis']))
    print(f'  Caller:        {user}')
    print(f'  Events:        {stats[\"count\"]}')
    print(f'  Input tokens:  {stats[\"input_tokens\"]:,}')
    print(f'  Output tokens: {stats[\"output_tokens\"]:,}')
    print(f'  APIs used:     {apis}')
    for arn in sorted(stats['source_arns']):
        print(f'  Source:        {arn}')
    print()
"

# ── Section 3: Daily invocation trend ─────────────────────────────────────
echo "── Daily invocation trend ──"
echo ""
printf "  %-12s %10s %15s %15s\n" "Date" "Invocations" "Input Tokens" "Output Tokens"
printf "  %-12s %10s %15s %15s\n" "----" "-----------" "------------" "-------------"

inv_json=$(aws cloudwatch get-metric-statistics --namespace AWS/Bedrock \
    --metric-name Invocations \
    --start-time "$start_time" --end-time "$end_time" \
    --period 86400 --statistics Sum \
    --query 'sort_by(Datapoints,&Timestamp)' --output json 2>/dev/null)

input_json=$(aws cloudwatch get-metric-statistics --namespace AWS/Bedrock \
    --metric-name InputTokenCount \
    --start-time "$start_time" --end-time "$end_time" \
    --period 86400 --statistics Sum \
    --query 'sort_by(Datapoints,&Timestamp)' --output json 2>/dev/null)

output_json=$(aws cloudwatch get-metric-statistics --namespace AWS/Bedrock \
    --metric-name OutputTokenCount \
    --start-time "$start_time" --end-time "$end_time" \
    --period 86400 --statistics Sum \
    --query 'sort_by(Datapoints,&Timestamp)' --output json 2>/dev/null)

python3 -c "
import json, sys
from collections import defaultdict

inv = json.loads('''${inv_json}''')
inp = json.loads('''${input_json}''')
out = json.loads('''${output_json}''')

data = defaultdict(lambda: [0, 0, 0])
for d in inv:
    date = d['Timestamp'][:10]
    data[date][0] = int(d['Sum'])
for d in inp:
    date = d['Timestamp'][:10]
    data[date][1] = int(d['Sum'])
for d in out:
    date = d['Timestamp'][:10]
    data[date][2] = int(d['Sum'])

total_inv = total_in = total_out = 0
for date in sorted(data):
    i, it, ot = data[date]
    total_inv += i
    total_in += it
    total_out += ot
    print(f'  {date}   {i:>10,}   {it:>13,}   {ot:>13,}')

print()
print(f'  {\"TOTAL\":<12} {total_inv:>10,}   {total_in:>13,}   {total_out:>13,}')
"

echo ""

# ── Section 4: Week-over-week comparison ──────────────────────────────────
echo "── Week-over-week comparison ──"
echo ""

python3 -c "
import json
from collections import defaultdict
from datetime import datetime

inv = json.loads('''${inv_json}''')

weeks = defaultdict(int)
for d in inv:
    dt = datetime.fromisoformat(d['Timestamp'].replace('+00:00', ''))
    year, week, _ = dt.isocalendar()
    weeks[f'{year}-W{week:02d}'] += int(d['Sum'])

sorted_weeks = sorted(weeks.items())
prev = None
for week, count in sorted_weeks:
    if prev is not None:
        change = count - prev
        pct = (change / prev * 100) if prev > 0 else 0
        arrow = '▲' if change > 0 else '▼' if change < 0 else '─'
        print(f'  {week}:  {count:>8,} invocations  {arrow} {abs(change):,} ({pct:+.0f}%)')
    else:
        print(f'  {week}:  {count:>8,} invocations')
    prev = count
"

echo ""
echo "Report complete."
