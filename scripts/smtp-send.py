#!/usr/bin/env python3
"""Sends one raw email (stdin, RFC 822 / .eml) through the SMTP server named by MAIL_SMTP_HOST:MAIL_SMTP_PORT.
Adds To, Message-ID and Date when the file lacks them, so the POP3 adapter can track the message.
Runs inside the IRIS container (scripts/send.sh), where python3 is available and the mail server is reachable."""
import email
import email.utils
import os
import smtplib
import sys
from email import policy

raw = sys.stdin.buffer.read()
msg = email.message_from_bytes(raw, policy=policy.default)
to = os.environ.get("MAIL_TO") or msg["To"] or "triage@triage.local"
if not msg["To"]:
    msg["To"] = to
if not msg["Message-ID"]:
    msg["Message-ID"] = email.utils.make_msgid(domain="triage.local")
if not msg["Date"]:
    msg["Date"] = email.utils.formatdate(localtime=True)

host = os.environ.get("MAIL_SMTP_HOST", "mail")
port = int(os.environ.get("MAIL_SMTP_PORT", "3025"))
with smtplib.SMTP(host, port) as smtp:
    smtp.send_message(msg, to_addrs=[email.utils.parseaddr(to)[1]])
print(f"sent {msg['Subject']!r} from {email.utils.parseaddr(msg['From'])[1]} to {email.utils.parseaddr(to)[1]}")
