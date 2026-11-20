#!/usr/bin/env bash
# ODIN Suite: move secrets out of odin.env into systemd encrypted credentials.
#
# Each API key, secret, password and alert token is encrypted with `systemd-creds`, sealed to this
# machine's TPM2 chip plus the host key when a TPM is present (host key alone otherwise). The encrypted
# blobs live in /etc/odin-suite/credentials; nothing secret stays in plain text on disk. At service start
# systemd decrypts them into a private in-memory directory only odin.service can read, and ODIN loads
# them from there ($CREDENTIALS_DIRECTORY).
#
# Usage:  sudo ./odin-seal-secrets.sh [--dry-run] [--restart]
# Needs:  systemd 250+ (Ubuntu 22.04+, Debian 12+). Re-run any time you change a key: put the new value
#         back in odin.env as plain text and run this again.
set -euo pipefail

ETC="${ODIN_ETC:-/etc/odin-suite}"
ENV_FILE="${ODIN_ENV_FILE:-$ETC/odin.env}"
CRED_DIR="${ODIN_CRED_DIR:-$ETC/credentials}"
UNIT="${ODIN_UNIT:-odin.service}"
SYSTEMD_DIR="${ODIN_SYSTEMD_DIR:-/etc/systemd/system}"
DROPIN_DIR="$SYSTEMD_DIR/$UNIT.d"
DROPIN="$DROPIN_DIR/10-odin-credentials.conf"
DRY=0; RESTART=0
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    --restart) RESTART=1 ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    *) echo "unknown option: $a" >&2; exit 64 ;;
  esac
done

die() { echo "odin-seal-secrets: $*" >&2; exit 1; }
[ "$(id -u)" -eq 0 ] || die "run as root (sudo)"
command -v systemd-creds >/dev/null || die "systemd-creds not found: needs systemd 250+ (Ubuntu 22.04+, Debian 12+)"
[ -f "$ENV_FILE" ] || die "no settings file at $ENV_FILE"

# same rule ODIN uses to decide what is a secret
is_secret() {
  case "$1" in
    *_KEY|*_SECRET|*_TOKEN|*_PASSWORD|*_PASS|*_PWD|ODIN_NTFY_TOPIC|ODIN_WEBHOOK_URL|ODIN_HIVE_FARM_HASH|ODIN_HIVE_RIG_ID) return 0 ;;
    *) return 1 ;;
  esac
}

if systemd-creds has-tpm2 >/dev/null 2>&1; then
  SEAL="tpm2+host"; SEAL_TXT="this machine's TPM2 chip + host key"
else
  SEAL="host"; SEAL_TXT="this machine's host key (no TPM2 found)"
fi

names=(); values=()
while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in ''|\#*) continue ;; esac
  key="${line%%=*}"; val="${line#*=}"
  key="$(printf '%s' "$key" | tr -d '[:space:]')"
  val="${val#"${val%%[![:space:]]*}"}"; val="${val%"${val##*[![:space:]]}"}"
  val="${val%\"}"; val="${val#\"}"
  [[ "$key" =~ ^[A-Z0-9_]+$ ]] || continue
  if is_secret "$key" && [ -n "$val" ]; then
    case "$val" in dpapi:*) die "$key holds a Windows DPAPI value; paste the plain value in, then re-run" ;; esac
    names+=("$key"); values+=("$val")
  fi
done < "$ENV_FILE"

if [ "${#names[@]}" -eq 0 ]; then
  echo "No plain-text secrets in $ENV_FILE. Nothing to do."
  exit 0
fi

echo "Sealing ${#names[@]} secret(s) with $SEAL_TXT:"
printf '  %s\n' "${names[@]}"
[ "$DRY" -eq 1 ] && { echo "(dry run: nothing changed)"; exit 0; }

install -d -m 0700 -o root -g root "$CRED_DIR"
for i in "${!names[@]}"; do
  k="${names[$i]}"; out="$CRED_DIR/$k.cred"
  printf '%s' "${values[$i]}" | systemd-creds encrypt --with-key="$SEAL" --name="$k" - "$out.new"
  # prove it opens again before anything plain is removed
  if [ "$(systemd-creds decrypt --name="$k" "$out.new" -)" != "${values[$i]}" ]; then
    rm -f "$out.new"; die "$k did not decrypt back to the same value; nothing was changed"
  fi
  chmod 0600 "$out.new"; mv -f "$out.new" "$out"
done

# drop-in: hand every sealed credential to the service
install -d -m 0755 "$DROPIN_DIR"
{
  echo "# written by odin-seal-secrets.sh: secrets decrypted by systemd at start, for this service only"
  echo "[Service]"
  for f in "$CRED_DIR"/*.cred; do
    [ -e "$f" ] || continue
    n="$(basename "$f" .cred)"
    echo "LoadCredentialEncrypted=$n:$f"
  done
} > "$DROPIN.new"
chmod 0644 "$DROPIN.new"; mv -f "$DROPIN.new" "$DROPIN"

# rewrite odin.env without the plain secrets; scrub the old copy before replacing it
tmp="$(mktemp "$ENV_FILE.XXXXXX")"
chmod 0600 "$tmp"
while IFS= read -r line || [ -n "$line" ]; do
  key="$(printf '%s' "${line%%=*}" | tr -d '[:space:]')"
  sealed=0
  for n in "${names[@]}"; do [ "$key" = "$n" ] && sealed=1 && break; done
  if [ "$sealed" -eq 1 ]; then
    echo "# $key: sealed in $CRED_DIR/$key.cred ($SEAL)"
  else
    printf '%s\n' "$line"
  fi
done < "$ENV_FILE" > "$tmp"
command -v shred >/dev/null && shred -n 1 -z "$ENV_FILE" 2>/dev/null || true
mv -f "$tmp" "$ENV_FILE"

command -v systemctl >/dev/null && systemctl daemon-reload 2>/dev/null || true
echo "Done: ${#names[@]} secret(s) sealed. Plain values removed from $ENV_FILE."
echo "Note: on SSDs and journaling filesystems an overwrite can't guarantee old blocks are gone - keep /etc on an encrypted volume."
if [ "$RESTART" -eq 1 ]; then
  systemctl restart "$UNIT" && echo "$UNIT restarted. Check: journalctl -u $UNIT | grep 'systemd encrypted credentials'"
else
  echo "Restart to apply:  sudo systemctl restart $UNIT"
fi
