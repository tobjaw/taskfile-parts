# Cache Clearing Instructions

The standalone test passes, which means the YAML parser logic is correct.
The error is caused by Nix using a cached/old version from the store.

## Quick Fix

Run these commands to force Nix to use the updated parser:

```bash
# 1. Clear Nix evaluation cache
rm -rf ~/.cache/nix

# 2. Update the flake lock to get a fresh store path
nix flake update

# 3. Try showing the flake with fresh evaluation
nix flake show --refresh
```

## If that doesn't work, try:

```bash
# Force a complete refresh
nix flake metadata --refresh
nix eval .#checks --refresh
```

## Alternative: Test locally without cache

```bash
# Run flake show using the local path directly
nix flake show --override-input taskfile-parts path:$(pwd)
```

## Verify it works

Once cleared, you should be able to run:
```bash
nix flake show
```

And it should parse the Taskfile correctly without the error about
"expected a list but found a set: { "PROJECT_NAME: taskfile-parts" = ... }"

## Why this happened

The error showed Nix was using:
`/nix/store/av30d3pziclhbk5hyd3wnvbz9d9lp2jn-source/`

This is a cached store path from before the indexOf fix was committed.
After clearing the cache, Nix will re-fetch and use the updated code.
