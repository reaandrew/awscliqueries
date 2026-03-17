# awscliqueries

A collection of useful AWS CLI queries and reports.

## Queries

### Bedrock Usage Report

Generates a summary of Bedrock API usage including models in use, top callers (via CloudTrail), daily invocation/token trends, and week-over-week comparison.

```bash
aws-vault exec <profile> -- ./queries/bedrock/bedrock_usage_report.sh [days]
```

`days` defaults to 30 if not specified.

#### Example output

```
==============================================
  Bedrock Usage Report
  Period: last 30 days
  From:   2026-02-15T16:48:41Z
  To:     2026-03-17T16:48:41Z
==============================================

── Models in use ──

  eu.anthropic.claude-opus-4-6-v1                         9734.0 invocations

── Top callers (via CloudTrail) ──

  Caller:        smm-sfn-generate-content
  Events:        49
  Input tokens:  114,006
  Output tokens: 11,439
  APIs used:     Converse
  Source:        arn:aws:lambda:eu-west-2:134570442530:function:smm-sfn-generate-content

  Caller:        andy.rea
  Events:        1
  Input tokens:  0
  Output tokens: 0
  APIs used:     GetModelInvocationLoggingConfiguration

── Daily invocation trend ──

  Date         Invocations    Input Tokens   Output Tokens
  ----         -----------    ------------   -------------
  2026-02-16            3           2,185           1,431
  2026-02-17          675         939,590         238,780
  2026-02-18          127         244,168          40,749
  2026-02-19          103         189,338          25,562
  2026-02-20          263         532,774          66,209
  2026-02-21          150         293,300          46,793
  2026-02-22          359         733,856         116,696
  2026-02-23          183         378,113          51,488
  2026-02-24          158         344,772          42,584
  2026-02-25          160         324,796          40,973
  2026-02-26          412         849,111         121,145
  2026-02-27          193         394,743          47,521
  2026-02-28          176         357,420          42,005
  2026-03-01          180         380,358          42,608
  2026-03-02          176         404,370          42,422
  2026-03-03          100         145,315          23,604
  2026-03-04          472         724,183         115,190
  2026-03-05          487       1,012,031         124,280
  2026-03-06          514       1,218,822         126,293
  2026-03-07          529       1,206,429         125,589
  2026-03-08          483       1,131,836         109,315
  2026-03-09          482       1,153,671         111,774
  2026-03-10          585       1,470,403         157,585
  2026-03-11          434       1,060,824         102,028
  2026-03-12          460       1,087,240         107,366
  2026-03-13          529       1,240,650         127,489
  2026-03-14          514       1,214,427         120,253
  2026-03-15          488       1,196,506         114,084
  2026-03-16          480       1,119,857         111,520

  TOTAL             9,875      21,351,088       2,543,336

── Week-over-week comparison ──

  2026-W08:     1,680 invocations
  2026-W09:     1,462 invocations  ▼ 218 (-13%)
  2026-W10:     2,761 invocations  ▲ 1,299 (+89%)
  2026-W11:     3,492 invocations  ▲ 731 (+26%)
  2026-W12:       480 invocations  ▼ 3,012 (-86%)

Report complete.
```
