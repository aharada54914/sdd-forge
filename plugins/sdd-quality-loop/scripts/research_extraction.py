"""Deterministic extraction shared by acquisition and original verification."""

from html.parser import HTMLParser
from research_evidence import Invalid, require

MAX_EXTRACTED = 2 * 1024 * 1024


class TextHTML(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.skip = 0
        self.parts = []
        self.login = False

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag in ("script", "style", "noscript"):
            self.skip += 1
        if tag == "input" and attrs.get("type", "").lower() == "password":
            self.login = True
        if tag in ("p", "div", "br", "h1", "h2", "h3", "li"):
            self.parts.append("\n")

    def handle_endtag(self, tag):
        if tag in ("script", "style", "noscript") and self.skip:
            self.skip -= 1

    def handle_data(self, data):
        if not self.skip:
            self.parts.append(data)


def extract(body, content_type):
    require(bool(body), "empty-response")
    media = content_type.split(";", 1)[0].strip().lower()
    if media == "application/pdf" or body.startswith(b"%PDF"):
        require(
            media == "application/pdf" and body.startswith(b"%PDF-"), "media-mismatch"
        )
        raise Invalid("pdf-extractor-unavailable")
    require(
        media
        in (
            "text/plain",
            "text/html",
            "application/xhtml+xml",
            "application/xml",
            "text/xml",
            "application/rss+xml",
            "application/atom+xml",
        ),
        "media-unsupported",
    )
    charset = "utf-8"
    for item in content_type.split(";")[1:]:
        if item.strip().lower().startswith("charset="):
            charset = item.split("=", 1)[1].strip(' "').lower()
    require(
        charset
        in (
            "utf-8",
            "utf8",
            "us-ascii",
            "iso-8859-1",
            "windows-1252",
            "shift_jis",
            "cp932",
        ),
        "encoding-unsupported",
    )
    try:
        text = body.decode("utf-8-sig" if charset in ("utf-8", "utf8") else charset)
    except (UnicodeError, LookupError):
        raise Invalid("encoding-invalid") from None
    if media in ("text/html", "application/xhtml+xml"):
        parser = TextHTML()
        parser.feed(text)
        require(
            not parser.login
            and not any(
                term in text.lower()
                for term in (
                    "cf-chl-",
                    "verify you are human",
                    "checking your browser",
                    "captcha",
                )
            ),
            "access-wall",
        )
        text = "".join(parser.parts)
        method = "html-text/v1"
    else:
        require(
            not text.lstrip().lower().startswith(("<!doctype html", "<html")),
            "media-mismatch",
        )
        method = "plain/v1"
    raw = text.encode("utf-8")
    require(len(raw) <= MAX_EXTRACTED, "extraction-too-large")
    return raw, method, content_type
