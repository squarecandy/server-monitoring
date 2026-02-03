# Getting Your Grafana Cloud Credentials

## Step-by-Step Guide

### 1. Sign Up / Log In
Go to [grafana.com/products/cloud](https://grafana.com/products/cloud/) and sign up for a free account or log in.

### 2. Navigate to Your Stack
- Click on your stack name (or create a new one)
- Click **"Details"** or **"Stack Details"**

### 3. Get Prometheus Credentials
- In the left sidebar, find **Prometheus** section
- Click **"Send Metrics"** or **"Details"**

You'll see a page with connection details:

```
Remote Write Endpoint:
https://prometheus-prod-XX-prod-XX-region.grafana.net/api/prom/push

Username / Instance ID:
123456

Password / API Key:
[Generate now button]
```

### 4. Collect the Three Values

**Value 1: GRAFANA_CLOUD_URL**
- This is the "Remote Write Endpoint"
- Example: `https://prometheus-prod-01-eu-west-0.grafana.net/api/prom/push`

**Value 2: GRAFANA_CLOUD_USER**  
- This is the "Username" or "Instance ID"
- It's usually just a number like `123456` or `987654`

**Value 3: GRAFANA_CLOUD_API_KEY**
- Click the **"Generate now"** button to create an API token
- It will look like: `glc_eyJrIjoiABC...` (starts with `glc_`)
- **Save this immediately** - you won't be able to see it again!

### 5. Set Environment Variables

On your server (or locally before running the installer):

```bash
export GRAFANA_CLOUD_URL="https://prometheus-prod-XX-prod-XX-region.grafana.net/api/prom/push"
export GRAFANA_CLOUD_USER="123456"
export GRAFANA_CLOUD_API_KEY="glc_eyJrIjoiABC..."
```

### 6. Verify

You can test the credentials with curl:

```bash
curl -u "${GRAFANA_CLOUD_USER}:${GRAFANA_CLOUD_API_KEY}" \
  -X POST "${GRAFANA_CLOUD_URL}" \
  -H "Content-Type: application/x-protobuf" \
  --data-binary @/dev/null

# Should return: 400 Bad Request (which is OK - means auth worked!)
# Should NOT return: 401 Unauthorized (would mean wrong credentials)
```

## Common Issues

### "I don't see the Prometheus section"
- Make sure you've selected a stack (not the org-level view)
- You might need to activate Prometheus in your stack first
- Free tier includes Prometheus metrics

### "I lost my API token"
- You can't retrieve it, but you can generate a new one
- Go back to Prometheus → Send Metrics → Generate now
- Update your `/etc/grafana-agent.yaml` with the new token
- Restart grafana-agent service

### "My username/instance ID has letters"
- Some newer Grafana Cloud instances use alphanumeric IDs
- That's fine! Use the exact value shown
- Example: `grafanacloud-myorg-prom` or just `123456`

## Alternative: Using API Keys (Legacy Method)

If your Grafana Cloud instance uses the older API key method:

1. Go to **Configuration** → **API Keys**
2. Click **"Add API Key"**
3. Name: `monitoring` 
4. Role: **MetricsPublisher**
5. Click **Add**
6. Copy the key (starts with `eyJ...`)

Then use:
```bash
export GRAFANA_CLOUD_URL="https://prometheus-xxx.grafana.net/api/prom/push"
export GRAFANA_CLOUD_USER="api"  # or your instance ID
export GRAFANA_CLOUD_API_KEY="eyJ..."  # the API key
```

## Security Notes

- Never commit these credentials to git
- Store them securely (password manager, environment variables)
- Rotate API tokens periodically
- Each token is scoped to only push metrics (can't read data or modify dashboards)

## Next Steps

Once you have all three values, proceed with [INSTALLATION.md](INSTALLATION.md)
