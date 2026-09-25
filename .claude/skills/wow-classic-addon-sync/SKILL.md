---
name: wow-classic-addon-sync
description: Synchronize World of Warcraft Classic addons from a reachable Windows host to this macOS installation. Use when the user asks to sync, copy, migrate, or refresh WoW Classic or 怀旧服插件 from Windows. The workflow locates the classic product directories, replaces only Interface/AddOns with a rollback backup, transfers through tar over SSH, and verifies counts plus cross-platform SHA-256 content. Do not use this skill for retail addons, WTF/account settings, screenshots, or installing addons from the internet.
---

# WoW Classic addon synchronization

## Scope

This project skill handles the Windows to macOS addon path:

```text
Windows: E:\Program Files (x86)\World of Warcraft\<product>\Interface\AddOns
macOS:  /Applications/World of Warcraft/<product>/Interface/AddOns
```

Supported products:

- `era` maps to `_classic_era_`.
- `titan` maps to `_classic_titan_`.
- `all` synchronizes both directories when both source directories exist.

The operation touches `Interface/AddOns` only. It leaves `WTF`, account data, macros, logs, fonts, and game binaries unchanged.

## Preconditions

- The WoW client must be closed on both machines. Battle.net may remain open.
- The Windows host must be reachable through SSH. The default alias is `win`.
- The Windows SSH shell must provide `tar`, `find`, and `sha256sum`. Git Bash is the expected shell.
- The local macOS installation must be at `/Applications/World of Warcraft`, unless overridden.
- The source and target product versions must match. Do not copy `_classic_era_` addons into `_classic_titan_` or another product directory.

Check the client process and SSH environment before changing files:

```bash
pgrep -ifl 'World of Warcraft|WowClassic' || true
ssh -o BatchMode=yes -o ConnectTimeout=10 win \
  'hostname; command -v tar; command -v find; command -v sha256sum'
```

## Run the bundled workflow

Run from the repository root:

```bash
bash .claude/skills/wow-classic-addon-sync/scripts/sync-addons.sh --product all
```

Use a single product when the request names a specific classic version:

```bash
bash .claude/skills/wow-classic-addon-sync/scripts/sync-addons.sh --product era
bash .claude/skills/wow-classic-addon-sync/scripts/sync-addons.sh --product titan
```

Override the SSH alias or installation roots when the machine layout changes:

```bash
bash .claude/skills/wow-classic-addon-sync/scripts/sync-addons.sh \
  --host win \
  --remote-root '/e/Program Files (x86)/World of Warcraft' \
  --local-root '/Applications/World of Warcraft' \
  --product era
```

The script performs these actions for each selected product:

1. Checks the remote source directory.
2. Renames the existing local `AddOns` directory to a timestamped `.backup-*` directory.
3. Streams a tar archive over SSH into a new empty local `AddOns` directory.
4. Compares top-level directory count, total directory count, and file count.
5. Compares a sorted aggregate of per-file SHA-256 hashes. The verification uses only hash values so GNU `sha256sum` and macOS `shasum` filename formatting cannot create a false mismatch.
6. On transfer or verification failure, preserves the incomplete directory as `.failed-*` and restores the backup.

Backups remain available for manual rollback. Delete them only after the addon list works in game.

## Reporting

Report the exact product directories synchronized, source and destination roots, file counts, verification result, and backup paths. State clearly when `WTF` was left untouched.

If verification fails, do not claim completion. Report the failed product and retained rollback paths. Inspect the remote and local manifests before retrying.
