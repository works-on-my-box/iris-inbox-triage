# Inbox triage with an IRIS AI Hub agent

<img src="docs/logo.png" alt="inbox triage" width="120" align="right">

An InterSystems IRIS Interoperability production that reads a mailbox, asks an AI Hub agent what each message needs, and acts on the answer: an alert for urgent mail, a review queue for a person, a draft reply for a quick question, or the archive. Every decision, every tool call the agent made and every draft is a row in IRIS, and every step is a message in the production's trace.

It is modeled on the inbox monitor I run for my own freelance work, where pitches to editors, client threads, hosting notices and newsletters land in one mailbox and the urgent ones must not wait. Built for the InterSystems "AI Agents in Interoperability Workflows" contest on the AI Hub Early Access build.

## How it works

```
 mailbox (IMAP) ──► Triage.Inbox.IMAP ────► Triage.ProcessBPL ─┐
                                                                │   sync    ┌─────────────────────────────┐
 .eml files ────► Triage.Inbox.Folder ───► Triage.Process ─────┼──────────► Triage.Agent                  │
                                              (ObjectScript)    │           │ %AI.Agent "Classifier"      │
                                                                │  Verdict  │  LookupContact   (SQL tool) │
                   Triage_Data.Decision ◄───────────────────────┘           │  SenderHistory   (SQL tool) │
                              │                                             │  RecordDecision             │
            ┌─────────────────┼──────────────────┬─────────────────┐        │ policies: one decision,     │
            ▼                 ▼                  ▼                 ▼        │           audit every call  │
      Triage.Alert      Triage.Review      Triage.Draft      Triage.Archive └─────────────────────────────┘
      Triage_Data.Alert   status=review    %AI.Agent "Writer"  status=archived
      + webhook                            Triage_Data.Draft
                                           + mail to the owner
```

1. **Three ways in.** `Triage.Inbox.IMAP` is a Business Service on `Triage.Adapter.IMAPInbound`, a custom inbound adapter written in Embedded Python, because IRIS ships a POP3 adapter only. Python's `imaplib` fetches unseen messages without flagging them, and `python/triage_mail.py` decodes each one with the `email` package: nested multiparts, quoted-printable and base64 bodies, charsets, encoded-word headers. Each email becomes a `Triage.Msg.Email` with the sender, the subject, the plain text of the body (an HTML-only message is reduced to text) and the number of attachments. A message is flagged `\Seen` only after the service accepted it; one that was accepted but not flagged (the connection dropped) is remembered by UID, so it is not triaged twice. `Triage.Inbox.Mail` is the POP3 alternative on `EnsLib.EMail.InboundAdapter` (`MAIL_PROTOCOL=pop3`), with `Triage.Util.Mail` turning each `%Net.MailMessage` into the same request. `Triage.Inbox.Folder` does the same for `.eml` files dropped into `/data/inbox/`, for offline runs and tests.
2. **Two equivalent processes.** `Triage.Process.TriageBPL` is the workflow in BPL, so the diagram in the Management Portal is the documentation: call the agent, record the decision, branch. `Triage.Process.Triage` is the same workflow in ObjectScript. The mail service targets the BPL process, the folder service the ObjectScript one; both can be re-pointed in the portal.

   <img src="docs/bpl.png" alt="The triage workflow in the BPL editor" width="520">
3. **The agent is a Business Operation.** `Triage.Agent` (`Triage.Operation.Agent`) hosts `Triage.Agent.Classifier`, a declarative `%AI.Agent`: provider `gemini`, model `gemini-3.5-flash-lite`, key from the `GEMINI_API_KEY` environment variable, instructions in the class. Its toolset `Triage.Agent.Tools` gives it two read-only SQL tools, `LookupContact` (known clients, editors, platforms) and `SenderHistory` (earlier decisions for the same domain), and `RecordDecision`, which validates the category, urgency and action. The operation returns a `Triage.Msg.Verdict` with the decision, the reason, the confidence and the session statistics (tool calls, tokens, LLM time), so each agent run is a request and a response in the message trace.
4. **Two policies travel with the toolset.** `Triage.Policy.OneDecision` (`%AI.Policy.Authorization`) lets `RecordDecision` run once per email even if the model tries again. `Triage.Policy.Audit` (`%AI.Policy.Audit`) writes every tool call, with its arguments, result, duration and outcome, to `Triage_Data.ToolCall`, tagged with the email it was made for.
5. **Failures are the operation's job.** A rate limit, a timeout or a server error from the LLM provider is retried by the operation itself (`RetryInterval` 20 s, `FailureTimeout` 180 s). If the agent still fails, or records nothing, the process falls back to a `review` verdict: the email reaches a person instead of being dropped. In BPL this is a fault handler around the call.
6. **Four operations act on the decision.** `Triage.Alert` stores urgent mail in `Triage_Data.Alert` and can post it to a webhook. `Triage.Review` leaves the decision open for a person. `Triage.Draft` runs a second agent, `Triage.Agent.Writer`, that writes a short reply, stores it in `Triage_Data.Draft` and mails it to the owner's mailbox through `EnsLib.EMail.OutboundAdapter`, ready to edit and send. `Triage.Archive` closes the decision.

## Run it

Requirements: Docker, the IRIS Community image with AI Hub from the [Early Access Program portal](https://evaluation.intersystems.com/Eval/early-access/AIHub) (file `iris-community-2026.3.0AI.154.0-docker.tar.gz`), and a Gemini API key from [Google AI Studio](https://aistudio.google.com/apikey); the free tier is enough.

```sh
docker load -i iris-community-2026.3.0AI.154.0-docker.tar.gz
git clone https://github.com/works-on-my-box/iris-inbox-triage.git
cd iris-inbox-triage
cp .env.example .env                # put your GEMINI_API_KEY here
docker compose up -d --build        # IRIS with the production, plus a test mail server (GreenMail)
scripts/demo.sh                     # sends the eight samples over SMTP, waits for the agent, prints the results
```

`scripts/send.sh data/samples/*.eml` only submits the samples; the production picks them up over IMAP within seconds.

The build installs IPM and loads the module with `zpm "load"`; the production starts with IRIS. A minute or two after sending, the samples are decided. Where to look, in the Management Portal at http://localhost:52773/csp/sys/UtilHome.csp (user `_SYSTEM`, password `SYS`):

- **Interoperability → View → Messages**: open any `Triage.Msg.Email` and its trace: the agent's request, its verdict with the reason and statistics, and the operation that acted on it.

  <img src="docs/trace.png" alt="Visual Trace of one email: service, BPL process, agent operation, alert" width="760">
- **Interoperability → Build → Business Processes → Triage.Process.TriageBPL**: the workflow diagram.
- **Interoperability → Configure → Production**: the running production; the IMAP service shows the server and the mailbox it polls.
- **System Explorer → SQL**:

```sql
SELECT Sender, Category, Urgency, Action, Confidence, Status, Reason FROM Triage_Data.Decision
SELECT MessageId, ToolName, Arguments, DurationMs, Success FROM Triage_Data.ToolCall
SELECT Recipient, Subject, Status, Body FROM Triage_Data.Draft
```

The drafts also arrive in the owner's mailbox on the test server: `owner@triage.local`, password `owner`, POP3 on `localhost:3110` or IMAP on `localhost:3143`.

Unit tests (mail parsing in ObjectScript and in Embedded Python, tool validation, policies, the decision record, retry rule) run inside the container:

```sh
scripts/test.sh
```

Without the mail server, `scripts/drop.sh data/samples/*.eml` feeds the folder service instead.

## Configuration

A real mailbox instead of the test server: set these in `.env` and restart with `docker compose up -d`. Gmail works over IMAP with an app password (`MAIL_HOST=imap.gmail.com`, `MAIL_TLS=1`); triaged messages are marked as read.

| Variable | Meaning |
| --- | --- |
| `MAIL_PROTOCOL` | `imap` (default) or `pop3`: which service reads the mailbox; POP3 deletes each message after reading it |
| `MAIL_HOST`, `MAIL_TLS=1` | Mail server the production polls; with TLS the ports default to 993 (IMAP) and 995 (POP3) |
| `MAIL_IMAP_PORT`, `MAIL_POP3_PORT` | Other ports, if needed |
| `MAIL_USER`, `MAIL_PASSWORD` | Mailbox credentials (stored as the `TriageMail` credentials in IRIS) |
| `MAIL_SMTP_HOST`, `MAIL_SMTP_PORT` | SMTP server for the drafts, same credentials |
| `DRAFTS_TO` | Mailbox that receives the drafts (default: `MAIL_USER`) |

`Triage.Setup.Configure` runs when the container starts (`after-start.sh`) and applies the values as system default settings of the production, including which inbox service is enabled, so the production definition in the repository stays unchanged. The test server has mailboxes `triage@triage.local` (the one the production reads) and `owner@triage.local`, password = login.

To use another provider, change `PROVIDER`, `MODEL` and `APIKEY` in `Triage.Agent.Classifier` and `Triage.Agent.Writer`; AI Hub also supports OpenAI, Anthropic, Vertex AI, Bedrock, OpenRouter, xAI and OpenAI-compatible local servers.

## Project layout

```
src/cls/Triage/
  Production.cls            the production: 3 services, 2 processes, 5 operations
  Adapter/IMAPInbound.cls   custom inbound adapter: IMAP in Embedded Python (imaplib), flag after processing
  Service/IMAPInbox.cls     IMAP mailbox -> Triage.Msg.Email
  Service/MailInbox.cls     POP3 mailbox -> Triage.Msg.Email (MAIL_PROTOCOL=pop3)
  Service/FileInbox.cls     .eml folder  -> Triage.Msg.Email
  Util/Mail.cls             %Net.MailMessage or decoded IMAP mail to Triage.Msg.Email: parts, HTML, attachments
  Process/TriageBPL.cls     the workflow in BPL (fault handler, switch on the action)
  Process/Triage.cls        the same workflow in ObjectScript
  Operation/Agent.cls       hosts the classifier agent; retries transient provider errors
  Operation/Draft.cls       writer agent + SMTP adapter; Triage_Data.Draft
  Operation/Alert.cls       Triage_Data.Alert, optional webhook
  Operation/Review.cls      marks the decision for a person
  Operation/Archive.cls     closes the decision
  Agent/Classifier.cls      %AI.Agent: instructions, provider, model, toolset
  Agent/Tools.cls           %AI.ToolSet: two SQL queries, RecordDecision, the policies
  Agent/Writer.cls          %AI.Agent that writes the draft reply
  Policy/OneDecision.cls    %AI.Policy.Authorization: RecordDecision once per email
  Policy/Audit.cls          %AI.Policy.Audit: every tool call -> Triage_Data.ToolCall
  Msg/                      Email (request), Verdict (agent response), Decision (to the operations)
  Data/                     Decision, Contact, Alert, Draft, ToolCall tables
  Setup.cls                 demo contacts; runtime configuration from the environment
python/triage_mail.py       MIME decoding with Python's email package; IPM copies it to the IRIS python directory
tests/Triage/Test/          %UnitTest cases, run by scripts/test.sh
data/samples/               eight made-up emails, including HTML-only mail and a PDF attachment
module.xml                  IPM module; Dockerfile, iris.script, after-start.sh, docker-compose.yml
```

## Sample run

The eight sample emails and the four known contacts are made up. One run on October 28, 2026, all eight decided by the agent with three tool calls each:

| Email | Category | Urgency | Action |
| --- | --- | --- | --- |
| An editor commissions a pitched article and asks for a date | editorial | hot | alert |
| A known client asks to extend a scraper before Black Friday | client | hot | alert |
| The hosting provider says a payment failed | platform | hot | alert |
| A weekly JavaScript newsletter | newsletter | low | archive |
| An SEO spam offer | spam | low | archive |
| A stranger asks whether I build Telegram bots | client | normal | draft_reply |
| A known client asks a quick question (HTML-only mail) | client | normal | draft_reply |
| The hosting provider sends an invoice as a PDF attachment | platform | low | archive |

Model output varies between runs: the stranger's inquiry has also come back as `alert`. The reason stored with each decision shows what the agent relied on, and `Triage_Data.ToolCall` shows what it looked up. The two drafts were mailed to `owner@triage.local`; the one for the quick question says the schedule has to be checked on the server rather than inventing an answer.

## Notes from building it on the Early Access build (2026.3.0AI.154.0)

- A ToolSet with `<Query>` tools does not compile in the same load as the tables it queries unless the ToolSet class declares `DependsOn` on them: the SQL is validated at compile time, and the table exists only after its class is compiled. `Triage.Agent.Tools` has `DependsOn = (Triage.Data.Contact, Triage.Data.Decision, ...)`.
- Policies declared in the toolset's `<Policies>` block must not carry child elements: the compiler copies a child element of one policy (for example `<PreviewChars>` under `<Audit>`) into the generated code of every policy, and the agent then fails at start with `<PROPERTY DOES NOT EXIST>`. Defaults live in the policy classes instead.
- `%AI.Policy.Audit.%LogExecution` has to be declared `As %Status`, although the guide shows it without a return type.
- Free-tier Gemini returns HTTP 429 after about twenty calls in a minute; with three tool calls per email that is a handful of emails. Letting the Business Operation retry (`Retry` plus `RetryInterval` and `FailureTimeout`) handles it without any code in the agent, and the retries are visible in the event log.
- IRIS has a POP3 adapter but no IMAP one (and no `%Net.IMAP` class), so the IMAP adapter is written in Embedded Python. The raw message, attachments included, is decoded in Python and only the fields cross into ObjectScript: a large message passed as one string would hit the 3.6 MB string limit. IPM installs `python/triage_mail.py` into `mgr/python` with a `FileCopy` resource; that directory is on Embedded Python's `sys.path`.
- `EnsLib.EMail.InboundAdapter` skips a message on later polls once the service returned an error for it. The mail service therefore never returns an error: a message it cannot parse still goes to the process with what could be read, and ends up in review.

## Author

Oleg Naryzhnykh ([Developer Community profile](https://community.intersystems.com/user/oleg-naryzhnykh), [GitHub](https://github.com/works-on-my-box)). MIT license, see [LICENSE](LICENSE).
