#!/bin/sh
# Runs after IRIS starts inside the container (iris-main -a): mailbox credentials and server settings from the environment.
iris session IRIS < /opt/triage/configure.script
