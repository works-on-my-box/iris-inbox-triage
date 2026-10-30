#!/bin/sh
# The review queue from the command line: lists the open Workflow tasks of the Triage Reviewers role in the inbox of
# _SYSTEM, or completes them the way the Workflow Inbox does (take ownership, then the action).
# Usage: scripts/review.sh            list the open tasks
#        scripts/review.sh Archive    complete every open task with Alert, Draft or Archive
set -e
case "${1:-}" in ""|Alert|Draft|Archive) ;; *) echo "action must be Alert, Draft or Archive" >&2; exit 2;; esac
printf 'zn "USER"\nset n = ##class(Triage.Process.ReviewBPL).CompleteOpen("%s")\nwrite "completed: ", n, !\nhalt\n' "${1:-}" \
  | docker exec -i iris-inbox-triage iris session IRIS 2>/dev/null | grep -v -e '^USER>$' -e '^$' -e '^Node:'
