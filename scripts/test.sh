#!/bin/sh
# Runs the unit tests (tests/Triage/Test) inside the running container through IPM.
# Usage: scripts/test.sh
docker exec -i iris-inbox-triage iris session IRIS <<'IRIS'
zn "USER"
zpm "iris-inbox-triage test -only -verbose":1:1
IRIS
