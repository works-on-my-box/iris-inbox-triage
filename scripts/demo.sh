#!/bin/sh
# One-command demo: sends the sample emails, waits for the agent, prints the decisions, the drafts and the tool-call log.
# Usage: scripts/demo.sh            (after `docker compose up -d --build`; can be run again on the same container)
set -e
count() {
  printf 'zn "USER"\nset rs=##class(%%SQL.Statement).%%ExecDirect(,"SELECT COUNT(*) AS N FROM Triage_Data.Decision") do rs.%%Next() write "N=",rs.N,!\nhalt\n' | docker exec -i iris-inbox-triage iris session IRIS 2>/dev/null | grep -o 'N=[0-9]*' | cut -d= -f2
}
before=$(count); before=${before:-0}
scripts/send.sh data/samples/*.eml
echo
echo "Waiting for the agent (the free Gemini tier may rate-limit; the operation retries)..."
for i in $(seq 1 60); do
  n=$(count)
  [ "${n:-0}" -ge $((before + 8)) ] && break
  sleep 5
done
sleep 10
printf 'zn "USER"\nwrite !,"=== Decisions",!\nset rs=##class(%%SQL.Statement).%%ExecDirect(,"SELECT Sender, Category, Urgency, Action, Confidence, Status, DecidedBy FROM Triage_Data.Decision ORDER BY ID") do rs.%%Display()\nwrite !,"=== Drafts",!\nset rs=##class(%%SQL.Statement).%%ExecDirect(,"SELECT Recipient, Subject, Status, $EXTRACT(Body,1,80) AS Opening FROM Triage_Data.Draft ORDER BY ID") do rs.%%Display()\nwrite !,"=== Tool calls per tool",!\nset rs=##class(%%SQL.Statement).%%ExecDirect(,"SELECT ToolName, COUNT(*) AS Calls, SUM(CASE WHEN Success=1 THEN 1 ELSE 0 END) AS Ok FROM Triage_Data.ToolCall GROUP BY ToolName") do rs.%%Display()\nhalt\n' | docker exec -i iris-inbox-triage iris session IRIS 2>/dev/null | grep -v '^USER>$'
echo
echo "Expected for the eight samples: three alerts, three archived, two draft replies (the stranger's inquiry varies between alert and draft_reply)."
echo "Drafts were also mailed to owner@triage.local (POP3 localhost:3110, password owner)."
echo "Traces: http://localhost:52773/csp/sys/UtilHome.csp -> Interoperability -> View -> Messages"
