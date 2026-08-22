#!/usr/bin/env bash
# Mint a stable Android upload key and store it as GitHub Actions secrets.
#
# The Actions workflow cannot do this with GITHUB_TOKEN (HTTP 403). This script
# uses your logged-in `gh` account instead.
#
# Usage:
#   ./scripts/mint-signing-key.sh
#
# Requires: gh, keytool, openssl
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Homebrew's gh / Java are often missing from a non-login PATH.
export PATH="/opt/homebrew/opt/openjdk@17/bin:/opt/homebrew/opt/openjdk/bin:/opt/homebrew/bin:/usr/local/bin:${PATH}"

if [ -z "${JAVA_HOME:-}" ]; then
  for home in \
    /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home \
    /opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home
  do
    if [ -x "${home}/bin/keytool" ]; then
      export JAVA_HOME="$home"
      break
    fi
  done
fi

if ! command -v keytool >/dev/null; then
  echo "Java is not installed. On this Mac: brew install openjdk@17"
  exit 1
fi

if ! command -v gh >/dev/null; then
  echo "gh is not installed. On this Mac: brew install gh"
  echo "Then: gh auth login"
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "Run: gh auth login"
  exit 1
fi

REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
echo "Writing signing secrets to ${REPO}"

STORE_PASS="$(openssl rand -base64 24 | tr -d '/+=' | head -c 28)"
KEYSTORE="$(mktemp /tmp/islamic-app-XXXXXX.jks)"
# keytool refuses an existing empty file that mktemp just created.
rm -f "$KEYSTORE"
cleanup() { rm -f "$KEYSTORE"; }
trap cleanup EXIT

keytool -genkeypair -v \
  -keystore "$KEYSTORE" \
  -storetype JKS \
  -storepass "$STORE_PASS" \
  -keypass "$STORE_PASS" \
  -alias islamic-app \
  -keyalg RSA -keysize 2048 \
  -validity 10950 \
  -dname "CN=Islamic App, OU=Releases, O=if12is, L=Cairo, C=EG"

gh secret set ANDROID_KEYSTORE_BASE64 --repo "$REPO" < <(base64 < "$KEYSTORE" | tr -d '\n')
gh secret set ANDROID_KEYSTORE_PASSWORD --repo "$REPO" --body "$STORE_PASS"
gh secret set ANDROID_KEY_PASSWORD --repo "$REPO" --body "$STORE_PASS"
gh secret set ANDROID_KEY_ALIAS --repo "$REPO" --body "islamic-app"

echo "Stored. The next Android APK workflow run will sign with this key."
