#!/usr/bin/env bash
set -Eeuo pipefail

SSH_HOST="win"
REMOTE_ROOT="/e/Program Files (x86)/World of Warcraft"
LOCAL_ROOT="/Applications/World of Warcraft"
PRODUCTS=()

usage() {
  cat <<'EOF'
Usage:
  sync-addons.sh [--host HOST] [--remote-root PATH] [--local-root PATH] --product era|titan|all

The script replaces the selected local Interface/AddOns directory after creating a
rollback backup. It transfers only addons, not WTF account configuration.
EOF
}

while (($# > 0)); do
  case "$1" in
    --host)
      [[ $# -ge 2 ]] || { echo "--host requires a value" >&2; exit 2; }
      SSH_HOST="$2"
      shift 2
      ;;
    --remote-root)
      [[ $# -ge 2 ]] || { echo "--remote-root requires a value" >&2; exit 2; }
      REMOTE_ROOT="$2"
      shift 2
      ;;
    --local-root)
      [[ $# -ge 2 ]] || { echo "--local-root requires a value" >&2; exit 2; }
      LOCAL_ROOT="$2"
      shift 2
      ;;
    --product)
      [[ $# -ge 2 ]] || { echo "--product requires a value" >&2; exit 2; }
      case "$2" in
        era) PRODUCTS+=("_classic_era_") ;;
        titan) PRODUCTS+=("_classic_titan_") ;;
        all) PRODUCTS=("_classic_era_" "_classic_titan_") ;;
        *) echo "Unsupported product: $2" >&2; usage >&2; exit 2 ;;
      esac
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if ((${#PRODUCTS[@]} == 0)); then
  echo "--product era|titan|all is required" >&2
  usage >&2
  exit 2
fi

command -v ssh >/dev/null
command -v tar >/dev/null
command -v find >/dev/null
command -v shasum >/dev/null
command -v awk >/dev/null

[[ -d "$LOCAL_ROOT" ]] || { echo "Local WoW root does not exist: $LOCAL_ROOT" >&2; exit 1; }

ssh -o BatchMode=yes -o ConnectTimeout=10 "$SSH_HOST" \
  'command -v tar >/dev/null && command -v find >/dev/null && command -v sha256sum >/dev/null'

timestamp() {
  date '+%Y%m%d-%H%M%S'
}

restore_after_failure() {
  local local_addons="$1"
  local backup_dir="$2"
  local failed_dir="${local_addons}.failed-$(timestamp)"

  if [[ -e "$local_addons" ]]; then
    mv "$local_addons" "$failed_dir"
    echo "Failed transfer preserved at: $failed_dir" >&2
  fi
  if [[ -n "$backup_dir" && -e "$backup_dir" ]]; then
    mv "$backup_dir" "$local_addons"
    echo "Restored backup: $local_addons" >&2
  fi
}

sync_product() {
  local product="$1"
  local remote_addons="$REMOTE_ROOT/$product/Interface/AddOns"
  local local_addons="$LOCAL_ROOT/$product/Interface/AddOns"
  local backup_dir=""
  local remote_top remote_dirs remote_files local_top local_dirs local_files
  local remote_hash local_hash

  echo "=== Syncing $product ==="
  ssh -o BatchMode=yes -o ConnectTimeout=10 "$SSH_HOST" \
    "test -d '$remote_addons'" || {
      echo "Remote addon directory does not exist: $remote_addons" >&2
      return 1
    }

  if [[ -e "$local_addons" ]]; then
    [[ -d "$local_addons" ]] || {
      echo "Local addon path is not a directory: $local_addons" >&2
      return 1
    }
    backup_dir="${local_addons}.backup-$(timestamp)"
    if ! mv "$local_addons" "$backup_dir"; then
      echo "Unable to create backup: $backup_dir" >&2
      return 1
    fi
    echo "Backup: $backup_dir"
  fi
  if ! mkdir -p "$local_addons"; then
    restore_after_failure "$local_addons" "$backup_dir"
    return 1
  fi

  if ! ssh -o BatchMode=yes -o ConnectTimeout=10 "$SSH_HOST" \
      "tar -C '$remote_addons' -czf - ." | tar -C "$local_addons" -xzf -; then
    restore_after_failure "$local_addons" "$backup_dir"
    return 1
  fi

  if ! remote_top="$(ssh "$SSH_HOST" "cd '$remote_addons' && find . -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' '")"; then
    restore_after_failure "$local_addons" "$backup_dir"
    return 1
  fi
  if ! remote_dirs="$(ssh "$SSH_HOST" "cd '$remote_addons' && find . -type d | wc -l | tr -d ' '")"; then
    restore_after_failure "$local_addons" "$backup_dir"
    return 1
  fi
  if ! remote_files="$(ssh "$SSH_HOST" "cd '$remote_addons' && find . -type f | wc -l | tr -d ' '")"; then
    restore_after_failure "$local_addons" "$backup_dir"
    return 1
  fi
  if ! local_top="$(find "$local_addons" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"; then
    restore_after_failure "$local_addons" "$backup_dir"
    return 1
  fi
  if ! local_dirs="$(find "$local_addons" -type d | wc -l | tr -d ' ')"; then
    restore_after_failure "$local_addons" "$backup_dir"
    return 1
  fi
  if ! local_files="$(find "$local_addons" -type f | wc -l | tr -d ' ')"; then
    restore_after_failure "$local_addons" "$backup_dir"
    return 1
  fi

  printf 'REMOTE_TOP_DIRS=%s LOCAL_TOP_DIRS=%s\n' "$remote_top" "$local_top"
  printf 'REMOTE_ALL_DIRS=%s LOCAL_ALL_DIRS=%s\n' "$remote_dirs" "$local_dirs"
  printf 'REMOTE_FILES=%s LOCAL_FILES=%s\n' "$remote_files" "$local_files"

  if [[ "$remote_top" != "$local_top" || "$remote_dirs" != "$local_dirs" || "$remote_files" != "$local_files" ]]; then
    echo "Directory or file counts differ" >&2
    restore_after_failure "$local_addons" "$backup_dir"
    return 1
  fi

  if ! remote_hash="$(
    ssh "$SSH_HOST" \
      "cd '$remote_addons' && find . -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum --zero" |
      tr '\0' '\n' |
      cut -c1-64 |
      shasum -a 256 |
      awk '{print $1}'
  )"; then
    restore_after_failure "$local_addons" "$backup_dir"
    return 1
  fi
  if ! local_hash="$(
    find "$local_addons" -type f -print0 |
      LC_ALL=C sort -z |
      xargs -0 shasum -a 256 |
      cut -c1-64 |
      shasum -a 256 |
      awk '{print $1}'
  )"; then
    restore_after_failure "$local_addons" "$backup_dir"
    return 1
  fi

  printf 'REMOTE_CONTENT_HASH=%s\nLOCAL_CONTENT_HASH=%s\n' "$remote_hash" "$local_hash"
  if [[ "$remote_hash" != "$local_hash" ]]; then
    echo "Content hashes differ" >&2
    restore_after_failure "$local_addons" "$backup_dir"
    return 1
  fi

  echo "Verified: $product"
  echo "Backup retained: ${backup_dir:-none}"
}

for product in "${PRODUCTS[@]}"; do
  sync_product "$product"
done

echo "Addon synchronization completed."
