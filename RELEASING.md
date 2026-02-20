# Releasing MoePeek

## Prerequisites

### GitHub Secrets

The following secrets must be configured in the repository's **Prod** environment (`Settings > Environments > Prod`):

| Secret | Description |
|--------|-------------|
| `SPARKLE_ED_PUBLIC_KEY` | Ed25519 public key for Sparkle update verification |
| `SPARKLE_ED_PRIVATE_KEY` | Ed25519 private key for signing appcast entries |

Generate a key pair using Sparkle's `generate_keys` tool:

```bash
# From the Sparkle release archive
./bin/generate_keys
```

## Release via Git Tag (Recommended)

This is the standard release flow. Pushing a semver tag triggers CI to build, sign, and publish.

```bash
# 1. Ensure you're on main with the latest changes
git checkout main && git pull

# 2. Create and push the tag
git tag v0.2.0
git push origin v0.2.0
```

CI will automatically:
1. Build the Release archive
2. Create a ZIP and DMG
3. Download Sparkle CLI tools (version matched from `Package.resolved`)
4. Generate `appcast.xml` (preserving history from the previous release)
5. Create a **published** GitHub Release with assets: ZIP, DMG, and `appcast.xml`

## Manual Trigger (Testing)

Use `workflow_dispatch` from the Actions tab for test builds:

1. Go to **Actions > Release > Run workflow**
2. Optionally set a version number (defaults to `0.0.0-dev`)
3. Click **Run workflow**

This creates a **draft** release. Draft releases do not affect the `releases/latest` URL, so existing users will not see test builds via Sparkle auto-update.

## How Sparkle Auto-Update Works

1. The app's `Info.plist` contains `SUFeedURL` pointing to:
   ```
   https://github.com/yusixian/MoePeek/releases/latest/download/appcast.xml
   ```
2. GitHub's `releases/latest/download/{asset}` redirects to the latest **non-draft** release's asset
3. Sparkle fetches `appcast.xml`, compares versions, and prompts the user to update if a newer version is available
4. The user downloads the ZIP directly from GitHub Releases

## Troubleshooting

### Gatekeeper blocks the app

Since the app is not notarized, macOS Gatekeeper may block it on first launch. Users need to:

1. Right-click the app > **Open** (bypasses Gatekeeper for that specific app)
2. Or: `System Settings > Privacy & Security` > click **Open Anyway**

### appcast.xml missing from release

- Verify `SPARKLE_ED_PRIVATE_KEY` is set in the Prod environment
- Check the "Generate appcast" step in the Actions log for errors

### Sparkle not detecting updates

- Confirm the release is **not** a draft (draft releases are excluded from `latest`)
- Check that `SUFeedURL` in `Project.swift` points to the correct URL
- Verify the `appcast.xml` asset is present on the latest release
