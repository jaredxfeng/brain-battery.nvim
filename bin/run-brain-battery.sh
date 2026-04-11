#!/bin/bash
cd "$(dirname "$0")" || exit 1

# Make sure config dir exists
mkdir -p ~/.config/brain-soc

if [ ! -d "../node_modules" ]; then
  pnpm install --frozen-lockfile --silent
fi

npx --yes tsx ./brainBattery.ts >> ./brain-battery.log 2>&1
