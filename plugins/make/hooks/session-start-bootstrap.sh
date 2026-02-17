#!/usr/bin/env bash
# Bootstrap .env from plugin template if missing
PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [ ! -f .env ]; then
  cp "$PLUGIN_ROOT/env.template" .env
  echo "Created .env from template — edit to match your project"
fi
