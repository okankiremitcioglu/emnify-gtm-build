# Clay Companies table

Columns after Find Companies + Enrich company, in order. AI columns use Claude Sonnet 5.5 on our own Anthropic key.

| Column | Type | What it does |
|---|---|---|
| Device check | Use AI, web research | Does the company ship cellular devices, which vertical, is it a connectivity provider |
| IoT Device Profile | Use AI, web research | Installed base, volume band, countries, US, 2G/3G, eSIM, provider, launches, IoT roles, signals, sources |
| ICP Score | Formula | Rubric v1 (see `../icp-weights.json`) |
| ICP Tier | Formula | `{{ICP Score}} >= 60 ? "A" : {{ICP Score}} >= 40 ? "B" : "C"` |
| Why Now Note | Use AI, content only | 2 sentences for the SDR from the signals list, or "No clear trigger." |
| SF Payload | Formula | JSON body for the n8n webhook |
| Push to Salesforce | HTTP API | POST SF Payload to n8n `clay-account`; header `x-api-key` stored as a Clay account |

## Run conditions

The run condition has two boxes. The top one is a natural-language prompt; the formula box under it is what Clay evaluates. If the formula box is empty, the condition does nothing.

Push to Salesforce: `{{ICP Score}} >= 40`

## SF Payload formula

```js
JSON.stringify({company_name: {{Name}} || "", domain: {{Domain}} || "", country: {{Country}} || "",
  employees: Number({{Employee Count}}) || null, vertical: {{Use AI Vertical}} || "Other",
  icp_score: Number({{ICP Score}}) || 0, icp_tier: {{ICP Tier}} || "", rubric_version: "v1",
  device_volume_band: {{Use AI Volume Band}} || "Unknown",
  connectivity_tech: ({{Device check}} || {}).connectivityTech || ({{Device check}} || {}).connectivity_tech || "",
  current_provider: ["none found", "unknown", "no named"].some(v => String({{Use AI Current Provider}} || "").toLowerCase().includes(v)) ? "" : ({{Use AI Current Provider}} || ""),
  why_now: {{Why Now Note}}?.response || "",
  signals: ({{IoT Device Profile}} || {}).signals || [],
  source_urls: ({{IoT Device Profile}} || {}).sourceUrls || ({{IoT Device Profile}} || {}).source_urls || []})
```

AI columns return an object (`response`, token counts, cost), so read `.response` for the text.

## Results, 2026-10-24

40 companies, 9 pushed (6 A, 3 B), 31 stopped by the run condition. Re-running Netradyne returned `created: false` with the same Account Id and no second task.
