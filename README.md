# Inbox Triage with an IRIS AI Hub agent

An InterSystems IRIS Interoperability production that reads incoming email, asks an AI Hub agent to decide what each message needs, and routes the decision: an alert for urgent mail, a review queue for a person, or the archive.

It is modeled on the inbox monitor I run for my own freelance work, where pitches to editors, client threads, hosting notices and newsletters land in one mailbox and the urgent ones must not wait.

## How it works

```
data/inbox/*.eml ──► Triage.Inbox (file service)
                         │ Triage.Msg.Email
                         ▼
                   Triage.Process ── Triage.Agent.Classifier (%AI.Agent, Gemini)
                         │              tools: LookupContact (SQL)
                         │                     SenderHistory (SQL)
                         │                     RecordDecision
                         │ stores Triage.Data.Decision
          ┌──────────────┼───────────────┐
          ▼              ▼               ▼
    Triage.Alert   Triage.Review   Triage.Archive
```

1. **Triage.Inbox** (`EnsLib.File.InboundAdapter`) picks up `.eml` files from `/data/inbox/`, keeps the From and Subject headers and the body, and sends a `Triage.Msg.Email`.
2. **Triage.Process** runs the agent `Triage.Agent.Classifier`, a declarative `%AI.Agent` (provider `gemini`, model `gemini-3.5-flash-lite`, key from the `GEMINI_API_KEY` environment variable). Its toolset `Triage.Agent.Tools` has two read-only SQL tools, `LookupContact` (known clients, editors, platforms) and `SenderHistory` (earlier decisions for the same domain), and `RecordDecision`, which validates the category, urgency and action and hands the decision back to the process.
3. The process stores every decision in `Triage_Data.Decision` with the agent's reason and confidence, then routes it: urgent mail or `alert` to **Triage.Alert** (stored in `Triage_Data.Alert`, optionally posted to a webhook), `review`, `draft_reply` or low confidence to **Triage.Review**, and `archive` to **Triage.Archive**.
4. If the agent fails or records nothing, the email goes to review instead of being dropped.

## Run it

Requirements: Docker, the IRIS Community image with AI Hub from the [Early Access Program portal](https://evaluation.intersystems.com/Eval/early-access/AIHub) (file `iris-community-2026.3.0AI.154.0-docker.tar.gz`), and a Gemini API key from [Google AI Studio](https://aistudio.google.com/apikey); the free tier is enough.

```sh
docker load -i iris-community-2026.3.0AI.154.0-docker.tar.gz
git clone https://github.com/works-on-my-box/iris-inbox-triage.git
cd iris-inbox-triage
cp .env.example .env              # put your GEMINI_API_KEY here
docker compose up -d --build      # the production starts with IRIS
scripts/send.sh data/samples/*.eml
```

Then open the Management Portal at http://localhost:52773/csp/sys/UtilHome.csp (user `_SYSTEM`, password `SYS`): **Interoperability → View → Messages** shows each email's trace, and **System Explorer → SQL** shows the results:

```sql
SELECT Sender, Category, Urgency, Action, Confidence, Status, Reason FROM Triage_Data.Decision
```

To use another provider, change `PROVIDER`, `MODEL` and `APIKEY` in `Triage.Agent.Classifier`; AI Hub also supports OpenAI, Anthropic, Vertex AI, Bedrock, OpenRouter and OpenAI-compatible local servers.

## Sample run

The six sample emails and the four known contacts are made up. One run on October 15, 2026:

| Email | Category | Urgency | Action |
| --- | --- | --- | --- |
| An editor commissions a pitched article and asks for a date | editorial | hot | alert |
| A known client asks to extend a scraper before Black Friday | client | hot | alert |
| The hosting provider says a payment failed | platform | hot | alert |
| A stranger asks whether I build Telegram bots | client | hot | alert |
| A weekly JavaScript newsletter | newsletter | low | archive |
| An SEO spam offer | spam | low | archive |

Model output varies between runs; the reason stored with each decision shows what the agent relied on.

## Status

Work in progress for the InterSystems "AI Agents in Interoperability Workflows" contest. Planned: a mail-server inbound adapter instead of the folder, draft replies for `draft_reply`, an audit policy for every tool call, a BPL version of the process, and an IPM package.

## License

MIT, see [LICENSE](LICENSE).
