#!/bin/sh
# Sends .eml files to the triage mailbox through the test SMTP server; python3 inside the IRIS container does the work,
# so nothing but Docker is needed on the host.
# Usage: scripts/send.sh data/samples/*.eml
set -e
for f in "$@"; do
  docker exec -i iris-inbox-triage python3 /opt/triage/scripts/smtp-send.py < "$f"
done
