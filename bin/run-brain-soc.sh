#!/bin/bash
cd "$(dirname "$0")" || exit 1

echo "Brain SOC update started at $(date)"

# Make sure config dir exists
mkdir -p ~/.config/brain-soc

if [ ! -d "node_modules" ]; then
  echo "Installing dependencies for the first time (this only happens once)..."
  pnpm install --frozen-lockfile --silent
fi

npx --yes tsx ./brainSoc.ts >> ./brain-soc.log 2>&1

echo "Brain SOC update finished at $(date)"
