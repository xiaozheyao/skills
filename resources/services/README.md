# Services

This directory contains skills for accessing internal APIs, microservices, and other networked services available within the infrastructure.

---

## Index

| File | Service | Type | Description |
|------|---------|------|-------------|
| _(none yet)_ | | | |

> Add a row here each time a new service skill is documented.

---

## How to Use

1. Find the service you need in the table above.
2. Open its skill document — it will cover:
   - **Endpoint(s)** — base URLs or hostnames
   - **Authentication** — API keys, tokens, OAuth, mTLS, etc.
   - **Common operations** — example requests and expected responses
   - **Rate limits & quotas** — any throttling policies to be aware of
   - **Gotchas** — known failure modes, versioning caveats, or maintenance windows

---

## Adding a New Service

1. Create a new file here named descriptively, e.g. `model-serving-api.md` or `experiment-tracker.md`.
2. Use the template below as a starting point.
3. Register the new service in the table above.

---

## Service Skill Template

```
# Service: <Service Name>

## Overview
One-sentence description of what this service does and who owns it.

| Property      | Value                        |
|---------------|------------------------------|
| Base URL      | `<https://service.example.com>` |
| Auth method   | `<API key / OAuth2 / mTLS>` |
| Owner / team  | `<team-name>`                |
| SLA / uptime  | `<e.g. 99.9%>`               |
| Docs / Swagger | `<URL to API docs if any>`  |

---

## Authentication

How to obtain and use credentials.

```bash
# Example: set the API key in your environment
export <SERVICE>_API_KEY="<your-api-key>"

# Example: bearer token header
curl -H "Authorization: Bearer $<SERVICE>_API_KEY" <BASE_URL>/health
```

> **NOTE:** Never commit credentials to this repository.
> Store secrets in a secrets manager or environment variables.

---

## Common Operations

### Health Check

```bash
curl <BASE_URL>/health
```

### <Operation Name>

Description of what this does.

```bash
curl -X POST <BASE_URL>/<endpoint> \
  -H "Authorization: Bearer $<SERVICE>_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"key": "value"}'
```

Expected response:
```json
{
  "status": "ok"
}
```

---

## Rate Limits

| Limit type | Value | Behaviour when exceeded |
|---|---|---|
| Requests/minute | `<N>` | HTTP 429, retry after `Retry-After` header |

---

## Gotchas

- `<NOTE: e.g. The /v1/ prefix is deprecated — always use /v2/.>`
- `<NOTE: e.g. Responses may be cached for up to 60 seconds.>`

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| HTTP 401 | Expired or missing token | Re-export `<SERVICE>_API_KEY` |
| HTTP 429 | Rate limit exceeded | Back off and retry with exponential delay |
| HTTP 503 | Service down | Check status page at `<STATUS_URL>` |
```

---

## Conventions

- Endpoint paths are shown relative to `<BASE_URL>` — substitute the actual base URL for the target environment.
- Use `<ANGLE_BRACKETS>` for any value that varies per user, environment, or deployment.
- When referencing credentials, always point to a secrets manager or environment variable — never hardcode values in skill documents.