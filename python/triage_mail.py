"""Decodes raw RFC 822 messages for the triage production (Triage.Adapter.IMAPInbound).

The email package handles what hand-written MIME parsing gets wrong: nested multiparts, quoted-printable and base64
bodies, charsets and encoded-word headers. Installed by IPM into the IRIS python directory (module.xml, FileCopy).
"""
import email
import email.utils
from email import policy


def _content(part):
    try:
        return part.get_content()
    except Exception:  # unknown charset or broken encoding: keep what can be read
        payload = part.get_payload(decode=True) or b""
        return payload.decode("utf-8", "replace")


def parse(raw: bytes) -> dict:
    """Headers, the first text/plain and text/html parts (truncated) and the number of attachments."""
    msg = email.message_from_bytes(raw, policy=policy.default)
    text = html = ""
    attachments = 0
    for part in msg.walk():
        if part.is_multipart():
            continue
        if part.get_filename() or part.get_content_disposition() == "attachment" or part.get_content_maintype() != "text":
            attachments += 1
        elif part.get_content_type() == "text/html":
            html = html or _content(part)
        elif not text:
            text = _content(part)
    name, address = email.utils.parseaddr(str(msg.get("From", "")))
    to = email.utils.getaddresses([str(v) for v in msg.get_all("To", [])])
    return {
        "fromName": name,
        "fromAddr": address.lower(),
        "to": to[0][1].lower() if to else "",
        "subject": str(msg.get("Subject", "")),
        # As received: str() of the parsed header would rewrite the date (and fix a wrong weekday).
        "date": " ".join(next((v for k, v in msg.raw_items() if k.lower() == "date"), "").split()),
        "messageId": str(msg.get("Message-ID", "")),
        "text": text[:20000],
        "html": html[:100000],
        "attachments": attachments,
    }
