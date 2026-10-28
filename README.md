# Inbox triage with an IRIS AI Hub agent

An InterSystems IRIS Interoperability production that reads a mailbox, asks an AI Hub agent to decide what each message needs, and routes the decision: an alert for urgent mail, a review queue for a person, a draft reply, or the archive.

It is modeled on the inbox monitor I run for my own freelance work, where pitches to editors, client threads, hosting notices and newsletters land in one mailbox and the urgent ones must not wait.

## How it works

```
mailbox (POP3) ──► Triage.Inbox.Mail ─┐
                                      │ Triage.Msg.Email
.eml files ──► Triage.Inbox.Folder ───┘
                         ▼
                   Triage.Process ──sync──► Triage.Agent (%AI.Agent, Gemini)
                         │                     tools: LookupContact (SQL)
                         │ Triage.Msg.Verdict         SenderHistory (SQL)
                         │ stores Triage.Data.Decision RecordDecision
          ┌──────────────┼───────────────┐
          ▼              ▼               ▼
    Triage.Alert   Triage.Review   Triage.Archive
```

1. **Triage.Inbox.Mail** (`EnsLib.EMail.InboundAdapter`) polls a POP3 mailbox; `Triage.Util.Mail` turns each `%Net.MailMessage` into a `Triage.Msg.Email`: sender, subject, the plain text of the body (HTML-only mail is reduced to text) and the attachment count. **Triage.Inbox.Folder** does the same for `.eml` files dropped into `/data/inbox/`, for offline runs and tests.
2. **Triage.Process** sends the email to **Triage.Agent**, a Business Operation that hosts `Triage.Agent.Classifier`, a declarative `%AI.Agent` (provider `gemini`, model `gemini-3.5-flash-lite`, key from the `GEMINI_API_KEY` environment variable). Its toolset `Triage.Agent.Tools` has two read-only SQL tools, `LookupContact` (known clients, editors, platforms) and `SenderHistory` (earlier decisions for the same domain), and `RecordDecision`, which validates the category, urgency and action. The operation returns a `Triage.Msg.Verdict` with the decision and the session statistics (tool calls, tokens, LLM time), so every agent run is visible in the message trace.
3. Rate limits, timeouts and server errors of the LLM provider are retried by the operation itself (`RetryInterval` 20 s, `FailureTimeout` 180 s). If the agent still fails or records nothing, the email goes to review instead of being dropped.
4. The process stores every decision in `Triage_Data.Decision` with the agent's reason and confidence, then routes it: urgent mail or `alert` to **Triage.Alert** (stored in `Triage_Data.Alert`, optionally posted to a webhook), `review`, `draft_reply` or low confidence to **Triage.Review**, and `archive` to **Triage.Archive**.

## Run it

Requirements: Docker, the IRIS Community image with AI Hub from the [Early Access Program portal](https://evaluation.intersystems.com/Eval/early-access/AIHub) (file `iris-community-2026.3.0AI.154.0-docker.tar.gz`), and a Gemini API key from [Google AI Studio](https://aistudio.google.com/apikey); the free tier is enough.

```sh
docker load -i iris-community-2026.3.0AI.154.0-docker.tar.gz
git clone https://github.com/works-on-my-box/iris-inbox-triage.git
cd iris-inbox-triage
cp .env.example .env                # put your GEMINI_API_KEY here
docker compose up -d --build        # IRIS with the production, plus a test mail server (GreenMail)
scripts/send.sh data/samples/*.eml  # submits the samples over SMTP; the production picks them up over POP3
```

Then open the Management Portal at http://localhost:52773/csp/sys/UtilHome.csp (user `_SYSTEM`, password `SYS`): **Interoperability → View → Messages** shows each email's trace, including the agent's request and verdict, and **System Explorer → SQL** shows the results:

```sql
SELECT Sender, Category, Urgency, Action, Confidence, Status, Reason FROM Triage_Data.Decision
```

To read a real mailbox instead of the test server, set `MAIL_HOST`, `MAIL_POP3_PORT`, `MAIL_TLS`, `MAIL_USER` and `MAIL_PASSWORD` in `.env` (see `.env.example`; Gmail works with POP enabled and an app password) and restart with `docker compose up -d`. The values are applied at container start as system default settings of the production, so the production definition itself stays unchanged.

To use another provider, change `PROVIDER`, `MODEL` and `APIKEY` in `Triage.Agent.Classifier`; AI Hub also supports OpenAI, Anthropic, Vertex AI, Bedrock, OpenRouter and OpenAI-compatible local servers.

## Sample run

The eight sample emails and the four known contacts are made up. One run on October 28, 2026, all eight decided by the agent:

| Email | Category | Urgency | Action |
| --- | --- | --- | --- |
| An editor commissions a pitched article and asks for a date | editorial | hot | alert |
| A known client asks to extend a scraper before Black Friday | client | hot | alert |
| The hosting provider says a payment failed | platform | hot | alert |
| A weekly JavaScript newsletter | newsletter | low | archive |
| An SEO spam offer | spam | low | archive |
| A stranger asks whether I build Telegram bots | client | normal | alert |
| A known client asks a quick question (HTML-only mail) | client | normal | draft_reply |
| The hosting provider sends an invoice as a PDF attachment | platform | low | archive |

Model output varies between runs; the reason stored with each decision shows what the agent relied on.

## Status

Work in progress for the InterSystems "AI Agents in Interoperability Workflows" contest. Planned: draft replies for `draft_reply`, an audit policy for every tool call, a BPL version of the process, an IPM package, tests.

## License

MIT, see [LICENSE](LICENSE).
