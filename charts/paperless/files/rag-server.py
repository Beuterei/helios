#!/usr/bin/env python3
"""Search Paperless and return passages. OpenAPI for Open WebUI tools."""

from __future__ import annotations

import json
import os
import re
import urllib.error
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PAPERLESS_URL = os.environ["PAPERLESS_URL"].rstrip("/")
PUBLIC_URL = os.environ.get("PUBLIC_URL", PAPERLESS_URL).rstrip("/")
TOKEN = os.environ["PAPERLESS_TOKEN"]
LISTEN = os.environ.get("LISTEN", "0.0.0.0")
PORT = int(os.environ.get("PORT", "8080"))

STOP = {
    "a",
    "an",
    "and",
    "are",
    "as",
    "at",
    "be",
    "but",
    "by",
    "das",
    "dem",
    "den",
    "der",
    "des",
    "die",
    "ein",
    "eine",
    "einer",
    "for",
    "from",
    "hat",
    "ich",
    "in",
    "is",
    "ist",
    "it",
    "mit",
    "not",
    "of",
    "on",
    "or",
    "the",
    "to",
    "und",
    "von",
    "was",
    "with",
}

OPENAPI = {
    "openapi": "3.0.3",
    "info": {
        "title": "Paperless RAG",
        "version": "1.0.0",
        "description": "Search the Paperless-ngx archive and return matching passages.",
    },
    "paths": {
        "/search": {
            "get": {
                "operationId": "search_documents",
                "summary": "Search Paperless documents by full text",
                "description": (
                    "Search the user's Paperless archive. Use this for any question "
                    "about invoices, contracts, letters, or other stored documents."
                ),
                "parameters": [
                    {
                        "name": "query",
                        "in": "query",
                        "required": True,
                        "schema": {"type": "string"},
                        "description": "Search keywords or a short question.",
                    },
                    {
                        "name": "limit",
                        "in": "query",
                        "required": False,
                        "schema": {"type": "integer", "default": 5},
                    },
                ],
                "responses": {"200": {"description": "Matching passages"}},
            }
        }
    },
}


def keywords(query: str) -> list[str]:
    words = re.findall(r"[A-Za-z0-9ÄÖÜäöüß]{3,}", query)
    return [w for w in words if w.lower() not in STOP]


def paperless_get(path: str, params: dict[str, str]) -> dict:
    url = f"{PAPERLESS_URL}{path}?{urllib.parse.urlencode(params)}"
    req = urllib.request.Request(
        url,
        headers={
            "Authorization": f"Token {TOKEN}",
            "Accept": "application/json",
        },
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.load(resp)


def search_paperless(query: str, limit: int) -> list[dict]:
    terms = keywords(query) or [query.strip()]
    and_q = " AND ".join(terms)
    data = paperless_get(
        "/api/documents/",
        {"query": and_q, "page_size": str(limit)},
    )
    if data.get("count", 0) == 0 and len(terms) > 1:
        data = paperless_get(
            "/api/documents/",
            {"query": " OR ".join(terms), "page_size": str(limit)},
        )
    out = []
    for doc in data.get("results", [])[:limit]:
        content = doc.get("content") or ""
        hit = doc.get("__search_hit__") or {}
        passage = hit.get("highlights") or excerpt(content, terms)
        doc_id = doc["id"]
        out.append(
            {
                "id": doc_id,
                "title": doc.get("title") or f"document {doc_id}",
                "created": doc.get("created"),
                "url": f"{PUBLIC_URL}/documents/{doc_id}",
                "passage": re.sub(r"<[^>]+>", "", passage).strip(),
            }
        )
    return out


def excerpt(content: str, terms: list[str], window: int = 450) -> str:
    if not content:
        return ""
    lower = content.lower()
    spans: list[tuple[int, int]] = []
    for term in terms:
        start = 0
        needle = term.lower()
        while True:
            i = lower.find(needle, start)
            if i < 0:
                break
            spans.append((max(0, i - window), min(len(content), i + len(term) + window)))
            start = i + len(term)
    if not spans:
        return content[: window * 2]
    spans.sort()
    merged = [spans[0]]
    for a, b in spans[1:]:
        if a <= merged[-1][1]:
            merged[-1] = (merged[-1][0], max(merged[-1][1], b))
        else:
            merged.append((a, b))
    return " … ".join(content[a:b].strip() for a, b in merged[:4])


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt: str, *args) -> None:
        print(f"{self.address_string()} {fmt % args}")

    def _send(self, code: int, body, content_type: str = "application/json") -> None:
        raw = body if isinstance(body, bytes) else json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def do_GET(self) -> None:  # noqa: N802
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        qs = urllib.parse.parse_qs(parsed.query)
        try:
            if path == "/health":
                self._send(200, {"ok": True})
                return
            if path == "/openapi.json":
                self._send(200, OPENAPI)
                return
            if path == "/search":
                query = (qs.get("query") or [""])[0].strip()
                if not query:
                    self._send(400, {"error": "query is required"})
                    return
                limit = int((qs.get("limit") or ["5"])[0])
                docs = search_paperless(query, max(1, min(limit, 10)))
                self._send(200, {"count": len(docs), "documents": docs})
                return
            self._send(404, {"error": "not found"})
        except urllib.error.HTTPError as exc:
            self._send(exc.code, {"error": f"paperless returned {exc.code}"})
        except Exception as exc:  # noqa: BLE001
            self._send(502, {"error": str(exc)})


def main() -> None:
    server = ThreadingHTTPServer((LISTEN, PORT), Handler)
    print(f"paperless-rag listening on {LISTEN}:{PORT}")
    server.serve_forever()


if __name__ == "__main__":
    main()
