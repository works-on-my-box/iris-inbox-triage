#!/bin/sh
# Drops .eml files into the inbox folder inside the container (the offline path, Triage.Inbox.Folder).
# Usage: scripts/drop.sh data/samples/*.eml
set -e
for f in "$@"; do
  docker cp "$f" iris-inbox-triage:/data/inbox/"$(date +%s%N)-$(basename "$f")"
  echo "dropped $f"
done
