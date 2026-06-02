#!/bin/bash
# SessionStart hook: make the Flutter SDK available and restore dependencies so
# `flutter analyze` / `flutter test` work in Claude Code on the web.
set -euo pipefail

# Only provision in the remote (web) environment; local dev machines are
# assumed to already have Flutter installed.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

FLUTTER_DIR="${FLUTTER_HOME:-$HOME/flutter}"
FLUTTER_CHANNEL="stable"

# Install Flutter once; the container image is cached after the hook completes,
# so subsequent sessions reuse this clone.
if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  echo "Installing Flutter ($FLUTTER_CHANNEL) into $FLUTTER_DIR ..."
  git clone --depth 1 -b "$FLUTTER_CHANNEL" \
    https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi

export PATH="$FLUTTER_DIR/bin:$PATH"
# Avoid git "dubious ownership" warnings on the SDK checkout.
git config --global --add safe.directory "$FLUTTER_DIR" || true

# Persist PATH for the rest of the session.
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export PATH=\"$FLUTTER_DIR/bin:\$PATH\"" >> "$CLAUDE_ENV_FILE"
fi

# Warm up the tool and fetch package dependencies.
flutter --version
( cd "${CLAUDE_PROJECT_DIR:-.}" && flutter pub get )

echo "Flutter environment ready."
