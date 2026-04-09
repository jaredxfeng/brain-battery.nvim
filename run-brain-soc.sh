#!/bin/bash
cd "$(dirname "$0")" || exit 1
# Run with your environment variables
npx tsx brainSoc.ts >> brain-soc.log 2>&1
