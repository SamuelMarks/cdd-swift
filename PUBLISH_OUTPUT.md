# Publishing Generated Client SDK

This guide explains how to automatically publish a generated Swift SDK (client-library) to GitHub and update it.

## Automating Updates

Since the CDD model maintains a `target_directory` containing an installable Swift package, we can setup a GitHub Action to keep this client up-to-date.

1. Create a repository for the generated SDK.
2. In the SDK repo, set up a GitHub Action (`.github/workflows/update.yml`) that runs on a cron schedule or via webhook.
3. The action runs `cdd-swift from_openapi to_sdk -i remote_openapi.json -o .`.
4. It then automatically commits the new output and releases it with semantic versioning.

### Example GitHub Action

```yaml
name: Update SDK

on:
  schedule:
    - cron: '0 0 * * *'
  workflow_dispatch:

jobs:
  update-sdk:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup Swift
        uses: swift-actions/setup-swift@v1
      - name: Install cdd-swift
        run: |
          wget https://github.com/offscale/cdd-swift/releases/latest/download/cdd-swift
          chmod +x cdd-swift
      - name: Fetch OpenAPI and Generate SDK
        run: |
          ./cdd-swift from_openapi to_sdk -i https://api.example.com/openapi.json -o .
      - name: Commit and Push
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
          git add .
          git commit -m "chore: update SDK from latest OpenAPI spec" || exit 0
          git push
```
