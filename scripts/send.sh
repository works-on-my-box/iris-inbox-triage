#!/bin/sh
# Drops one or more .eml files into the inbox folder inside the container.
# Usage: scripts/send.sh data/samples/*.eml
set -e
for f in "$@"; do
  docker cp "$f" iris-inbox-triage:/data/inbox/"$(date +%s%N)-$(basename "$f")"
  echo "sent $f"
done
