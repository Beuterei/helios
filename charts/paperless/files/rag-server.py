#!/usr/bin/env python3
"""Search Paperless by text and metadata. OpenAPI for Open WebUI tools."""

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

# Paperless advanced-search fields. A query that uses one is sent through unchanged.
FIELD = re.compile(
    r"\b(?:title|content|correspondent|document_type|type|storage_path|path|tag|"
    r"original_filename|asn|created|added|modified|note|custom_field):",
    re.IGNORECASE,
)

OPENAPI = {
    "openapi": "3.0.3",
    "info": {
        "title": "Paperless RAG",
        "version": "1.0.0",
        "description": (
            "Search the Paperless-ngx archive by document text and by metadata "
            "(tags, correspondent, document type, dates) and return matching passages."
        ),
    },
    "paths": {
        "/search": {
            "get": {
                "operationId": "search_documents",
                "summary": "Search Paperless documents by text or metadata",
                "description": (
                    "Search the user's Paperless archive. Use this for any question "
                    "about invoices, contracts, letters, or other stored documents. "
                    "Set tag, correspondent, document_type, or created when the "
                    "question names them. created takes a year, yesterday, "
                    "previous year, or a range such as [2024-01 to 2024-06]."
                ),
                "parameters": [
                    {
                        "name": "query",
                        "in": "query",
                        "required": False,
                        "schema": {"type": "string"},
                        "description": (
                            "Words to find in the document text. Also accepts "
                            'Paperless field syntax such as tag:tax, type:invoice, '
                            'correspondent:"city utilities", or title:contract.'
                        ),
                    },
                    {
                        "name": "tag",
                        "in": "query",
                        "required": False,
                        "schema": {"type": "string"},
                        "description": (
                            "Tag name. Comma-separated names must all match, "
                            "for example bills,unpaid."
                        ),
                    },
                    {
                        "name": "correspondent",
                        "in": "query",
                        "required": False,
                        "schema": {"type": "string"},
                        "description": "Correspondent name.",
                    },
                    {
                        "name": "document_type",
                        "in": "query",
                        "required": False,
                        "schema": {"type": "string"},
                        "description": "Document type, such as invoice or letter.",
                    },
                    {
                        "name": "created",
                        "in": "query",
                        "required": False,
                        "schema": {"type": "string"},
                        "description": (
                            "Document date: a year, yesterday, previous year, "
                            "or a range such as [2024-01 to 2024-06]."
                        ),
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


def field_clause(field: str, value: str) -> str:
    value = value.strip()
    if re.fullmatch(r"\[[^\]]+\]|[\wÄÖÜäöüß./,-]+", value):
        return f"{field}:{value}"
    cleaned = value.replace('"', "")
    return f'{field}:"{cleaned}"'


def build_query(
    text: str,
    tag: str = "",
    correspondent: str = "",
    document_type: str = "",
    created: str = "",
) -> tuple[str, list[str]]:
    """Return the Paperless query and the plain words used for excerpts."""
    clauses = []
    if tag:
        clauses.append(field_clause("tag", tag))
    if correspondent:
        clauses.append(field_clause("correspondent", correspondent))
    if document_type:
        clauses.append(field_clause("type", document_type))
    if created:
        clauses.append(field_clause("created", created))
    text = text.strip()
    terms = keywords(text)
    if text and (FIELD.search(text) or any(op in f" {text} " for op in (" AND ", " OR ", " NOT "))):
        clauses.append(text)
        terms = []
    elif terms:
        clauses.append(" AND ".join(terms))
    elif text:
        clauses.append(text)
        terms = [text]
    return " AND ".join(clauses), terms


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


_names: dict[str, dict[int, str]] = {}


def names(kind: str, path: str) -> dict[int, str]:
    cached = _names.get(kind)
    if cached is not None:
        return cached
    table: dict[int, str] = {}
    page = 1
    while page <= 20:
        data = paperless_get(path, {"page_size": "100", "page": str(page)})
        for row in data.get("results", []):
            table[row["id"]] = row.get("name") or str(row["id"])
        if not data.get("next"):
            break
        page += 1
    _names[kind] = table
    return table


def labels(kind: str, path: str, ids: list[int]) -> list[str]:
    if not ids:
        return []
    try:
        table = names(kind, path)
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError, KeyError):
        return []
    if any(i not in table for i in ids):
        _names.pop(kind, None)
        try:
            table = names(kind, path)
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError, KeyError):
            return []
    return [table[i] for i in ids if i in table]


def search_paperless(
    text: str,
    limit: int,
    tag: str = "",
    correspondent: str = "",
    document_type: str = "",
    created: str = "",
) -> list[dict]:
    paperless_query, terms = build_query(
        text,
        tag=tag,
        correspondent=correspondent,
        document_type=document_type,
        created=created,
    )
    data = paperless_get(
        "/api/documents/",
        {"query": paperless_query, "page_size": str(limit)},
    )
    # A metadata query that misses should stay empty. OR would drop the field.
    plain = not FIELD.search(text) and not any((tag, correspondent, document_type, created))
    if plain and data.get("count", 0) == 0 and len(terms) > 1:
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
        tag_ids = [t for t in doc.get("tags") or [] if isinstance(t, int)]
        item = {
            "id": doc_id,
            "title": doc.get("title") or f"document {doc_id}",
            "created": doc.get("created"),
            "url": f"{PUBLIC_URL}/documents/{doc_id}",
            "passage": re.sub(r"<[^>]+>", "", passage).strip(),
        }
        correspondent_name = labels(
            "correspondents",
            "/api/correspondents/",
            [doc["correspondent"]] if isinstance(doc.get("correspondent"), int) else [],
        )
        type_name = labels(
            "document_types",
            "/api/document_types/",
            [doc["document_type"]] if isinstance(doc.get("document_type"), int) else [],
        )
        tag_names = labels("tags", "/api/tags/", tag_ids)
        if correspondent_name:
            item["correspondent"] = correspondent_name[0]
        if type_name:
            item["document_type"] = type_name[0]
        if tag_names:
            item["tags"] = tag_names
        out.append(item)
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
                def param(name: str) -> str:
                    return (qs.get(name) or [""])[0].strip()

                query = param("query")
                tag = param("tag")
                correspondent = param("correspondent")
                document_type = param("document_type")
                created = param("created")
                if not any((query, tag, correspondent, document_type, created)):
                    self._send(400, {"error": "query or a metadata filter is required"})
                    return
                limit = int((qs.get("limit") or ["5"])[0])
                docs = search_paperless(
                    query,
                    max(1, min(limit, 10)),
                    tag=tag,
                    correspondent=correspondent,
                    document_type=document_type,
                    created=created,
                )
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
