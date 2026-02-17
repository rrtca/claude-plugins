#!/usr/bin/env bash
# Bootstrap .env and .Makefile.claude from plugin templates if missing
PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [ ! -f .env ]; then
  cp "$PLUGIN_ROOT/env.template" .env
  echo "Created .env from template — edit to match your project"
fi

if [ ! -f .Makefile.claude ]; then
  cp "$PLUGIN_ROOT/Makefile.claude-template" .Makefile.claude
  echo "Created .Makefile.claude from template — edit to add project targets"
fi
