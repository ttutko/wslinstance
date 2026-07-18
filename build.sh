#!/usr/bin/env bash
# =============================================================================
# build.sh — one-shot builder for the airgapped WSL instance.
#
# Run this on a NETWORK-CONNECTED machine with Docker. It:
#   1. builds the Debian 12 image (Ansible installs everything, offline-primed)
#   2. runs the offline self-test inside a `--network none` container (gate)
#   3. exports a flattened rootfs tarball (the form `wsl --import` needs)
#   4. bundles the tarball + import helper + docs + tests + checksums
#
# Copy the resulting bundle/ directory to the airgapped machine and follow
# bundle/README-IMPORT.md.
#
# Usage: ./build.sh [--skip-test] [--no-cache]
#
# Container runtime: auto-detected (nerdctl, then docker, then podman).
# Override with CONTAINER_CLI=nerdctl ./build.sh
# =============================================================================
set -euo pipefail

# ---- configuration ---------------------------------------------------------
IMAGE_NAME="debian-wsl-airgap"
DISTRO_NAME="DebianAirgap"           # default WSL distro name in the import helper
HERE="$(cd "$(dirname "$0")" && pwd)"
BUNDLE_DIR="$HERE/bundle"
TARBALL="$BUNDLE_DIR/${IMAGE_NAME}.tar.gz"

SKIP_TEST=0
BUILD_ARGS=()
for arg in "$@"; do
  case "$arg" in
    --skip-test) SKIP_TEST=1 ;;
    --no-cache)  BUILD_ARGS+=("--no-cache") ;;
    -h|--help)   grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

# ---- container runtime detection -------------------------------------------
CLI="${CONTAINER_CLI:-}"
if [ -z "$CLI" ]; then
  for c in nerdctl docker podman; do
    if command -v "$c" >/dev/null 2>&1 && "$c" info >/dev/null 2>&1; then
      CLI="$c"; break
    fi
  done
fi
[ -n "$CLI" ] || die "No working container runtime found (tried nerdctl, docker, podman). Is the daemon running?"
command -v "$CLI" >/dev/null || die "$CLI not found on PATH."
"$CLI" info >/dev/null 2>&1 || die "$CLI is installed but its daemon is not reachable."
log "Using container runtime: $CLI"

mkdir -p "$BUNDLE_DIR"

# ---- 1. build --------------------------------------------------------------
log "Building image '$IMAGE_NAME' (this fetches everything; needs network)..."
"$CLI" build "${BUILD_ARGS[@]}" -t "$IMAGE_NAME" "$HERE"

# ---- 2. offline test gate --------------------------------------------------
if [ "$SKIP_TEST" -eq 0 ]; then
  log "Verifying the image is self-contained ($CLI run --network none)..."
  if ! "$CLI" run --rm --network none "$IMAGE_NAME" /usr/local/bin/wsl-selftest; then
    die "Offline self-test FAILED — the image is not fully self-contained. Fix before shipping (or re-run with --skip-test to override)."
  fi
  log "Offline self-test passed."
else
  log "Skipping offline self-test (--skip-test)."
fi

# ---- 3. export flattened rootfs -------------------------------------------
log "Exporting rootfs tarball..."
cid="$("$CLI" create "$IMAGE_NAME")"
trap '"$CLI" rm -f "$cid" >/dev/null 2>&1 || true' EXIT
"$CLI" export "$cid" | gzip -9 > "$TARBALL"
"$CLI" rm -f "$cid" >/dev/null 2>&1 || true
trap - EXIT

# ---- 4. bundle helpers, docs, tests, checksums -----------------------------
log "Assembling bundle..."
cp "$HERE/bundle-assets/import.ps1"        "$BUNDLE_DIR/" 2>/dev/null || true
cp "$HERE/bundle-assets/README-IMPORT.md"  "$BUNDLE_DIR/" 2>/dev/null || true
mkdir -p "$BUNDLE_DIR/docs" "$BUNDLE_DIR/tests"
cp "$HERE/docs/tools.tsv" "$BUNDLE_DIR/docs/"
cp "$HERE/tests/test-offline.sh" "$HERE/tests/expected-tools.txt" "$BUNDLE_DIR/tests/"

# Personalise the import helper with the tarball name + default distro name.
if [ -f "$BUNDLE_DIR/import.ps1" ]; then
  sed -i \
    -e "s|@@TARBALL@@|$(basename "$TARBALL")|g" \
    -e "s|@@DISTRO@@|$DISTRO_NAME|g" \
    "$BUNDLE_DIR/import.ps1"
fi

log "Computing checksums..."
( cd "$BUNDLE_DIR" && sha256sum "$(basename "$TARBALL")" > SHA256SUMS )

# ---- done ------------------------------------------------------------------
size="$(du -h "$TARBALL" | cut -f1)"
cat <<EOF

$(printf '\033[1;32m')Build complete.$(printf '\033[0m')
  Image:   $IMAGE_NAME
  Tarball: $TARBALL  ($size)
  Bundle:  $BUNDLE_DIR

Copy the entire '$BUNDLE_DIR' directory to the airgapped machine, then on Windows:

  wsl --import $DISTRO_NAME C:\\WSL\\$DISTRO_NAME $(basename "$TARBALL") --version 2
  wsl -d $DISTRO_NAME

(or run bundle\\import.ps1). See bundle/README-IMPORT.md for details.
EOF
