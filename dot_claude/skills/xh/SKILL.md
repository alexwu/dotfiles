---
name: xh
description: Send HTTP requests from the shell with `xh`, the fast Rust HTTPie clone — build GET/POST/PUT/etc. requests with HTTPie-style request items (`key=val` JSON, `key:=val` raw JSON, `key==val` query string, `header:val` headers, `@file` bodies, file uploads), set auth, persist cookies/headers across calls with sessions, download files, and preview or translate requests before sending. Use whenever the user wants to call an API, hit an endpoint, test a REST/JSON service, POST a payload, send a request to a URL, debug an HTTP response, reach a local dev server (`:8000`, `localhost:3000`), or mentions `xh`, `xhs`, or HTTPie. Prefer this over hand-writing `curl` for any HTTP request, since xh is the configured client here and its request-item syntax is easy to get subtly wrong. Also covers the non-obvious `-I/--ignore-stdin` requirement for scripted use.
---

# xh — fast, friendly HTTP requests

`xh` is a Rust reimplementation of [HTTPie](https://httpie.io/): the same readable request syntax and pretty output, but a single static binary with fast startup. It's installed and on PATH here. Invoke it as `xhs` (or pass `--https`) to default the URL scheme to `https://`.

If `xh` is somehow missing, install with `brew install xh`.

## The one rule for scripted use: pass `-I`

**From a Bash tool / non-interactive shell, always pass `-I` (`--ignore-stdin`).**

Why: when xh detects redirected (non-TTY) stdin, it tries to read the *request body* from it. An agent's shell has non-TTY stdin, so without `-I` xh blocks forever waiting for a body that never arrives — and a hung xh looks exactly like a server or network stall, sending you down the wrong debugging path. The only time to omit `-I` is when you genuinely intend to pipe a body in (`echo '{...}' | xh POST ...`).

## Anatomy of a command

```
xh [METHOD] URL [REQUEST_ITEM ...]
```

- **METHOD** is optional — defaults to `GET`, or `POST` when the request has a body. Case-insensitive.
- **URL** — scheme is optional (`http://` by default). A leading colon is shorthand for localhost: `:8000` → `localhost:8000`, `:/users` → `localhost/users`. A leading `://` lets you paste a full URL verbatim: `xh ://example.com/path`.
- **REQUEST_ITEM** — the key-value pairs that build headers, query string, and body. The *separator* picks the type. Getting these right is the whole game.

## Request items — the separator decides the type

| Syntax | Type | Example | Effect |
|--------|------|---------|--------|
| `key=value` | Body field (string) | `name=ahmed` | `{"name": "ahmed"}` (JSON), or a form field with `-f` |
| `key:=value` | Body field (raw JSON) | `age:=24` `ok:=true` `ids:=[1,2]` | `{"age": 24, "ok": true, "ids": [1,2]}` — numbers, bools, null, arrays, objects |
| `key==value` | Query string param | `q==rust` `page==2` | appends `?q=rust&page=2` to the URL |
| `header:value` | Header | `x-api-key:12345` | sends header `X-Api-Key: 12345` |
| `header:` | Unset a default header | `connection:` | removes that header |
| `header;` | Empty-valued header | `x-trace;` | sends `X-Trace:` with no value |
| `field@path` | File upload | `pic@photo.jpg` | multipart upload (needs `-f` or `--multipart`) |
| `@path` | Request body from file | `@payload.json` | sends the file as the raw body |

**`@`-prefix reads a value from a file** for any item type: `x-api-key:@key.txt`, `bio=@bio.txt`. **Backslash escapes** a separator that's part of the key: `weird\:key=value`. **Nested JSON** is built with JSON-path keys: `app[container][0][id]=090`. See `references/request-items.md` for the file-upload mimetype/filename modifiers, `--raw`, and the full nested-JSON rules.

`=`/`:=` build a JSON body by default (`-j`, the default). Pass `-f`/`--form` to send them as `application/x-www-form-urlencoded` form fields instead, or `--multipart` to force multipart.

## Preview before you send

When the request item syntax is non-trivial, **verify it built what you intended before firing it at a real server:**

- `--offline` — construct the full request (method, URL, headers, body) and print it **without sending**. The fastest way to confirm `:=` vs `=` produced the right JSON types.
- `--curl` — print the equivalent `curl` command instead of sending (`--curl-long` for long flags). Handy when handing a request to someone who wants curl.

```bash
xh --offline POST :8000/users name=ahmed age:=24 admin:=false tags:='["a","b"]'
```

## Output control

Output is pretty/colored on a TTY and automatically plain when piped — so agent-captured output is already clean. To shape what's shown:

- `-b` body only · `-h` headers only · `-m` metadata only · `-v` whole request **and** response (`-vv` adds response metadata)
- `-p` for custom combinations: letters `H` (request headers) `B` (request body) `h` (response headers) `b` (response body) `m` (meta), e.g. `-p Hhb`
- Pipe `-b` output into `jaq` for JSON extraction.

**Exit status is meaningful** (xh enables `--check-status` by default): `0` ok · `2` timeout · `3` un-followed 3xx · `4` 4xx client error · `5` 5xx server error · `6` too many redirects · `1` usage/network error. Check `$?` in scripts instead of grepping the body for error strings.

## Common patterns

All include `-I` for scripted use. Drop it only for an interactive one-off or a deliberate `| xh` body pipe.

```bash
# GET with query string
xh -I :8000/search q==rust limit==10

# POST JSON with mixed types
xh -I POST :8000/users name=ahmed age:=24 admin:=false tags:='["x","y"]'

# Form submission
xh -I -f POST :8000/login username=me password=secret

# Body straight from a file
xh -I POST :8000/data @payload.json

# Custom header; read a secret header from a file
xh -I :8000/me x-api-key:@token.txt

# Basic auth (PASS prompted if omitted); bearer token
xh -I -a user:pass :8000/private
xh -I -A bearer -a "$TOKEN" :8000/me

# Download to a file, resumable
xh -I -d example.com/big.zip -o big.zip
xh -I -c -d example.com/big.zip -o big.zip   # resume

# Persist cookies/auth/headers across calls with a session
xh -I --session=./api.json -a user:pass :8000/login
xh -I --session=./api.json :8000/profile      # reuses the session

# HTTPS
xhs -I example.com/get          # or: xh -I --https example.com/get

# Follow redirects
xh -I -F :8000/old-path
```

## Reference files

Load as needed — don't preload both:

- **`references/request-items.md`** — the complete request-item grammar: every separator with edge cases, file uploads with `;type=`/`;filename=`, reading values from files, `--raw`, escaping, and the full nested-JSON path syntax with worked examples.
- **`references/flags.md`** — the full flag reference grouped by purpose: output/formatting, body serialization, auth & sessions, redirects & status, TLS/certs, networking (proxy, resolve, interface, unix-socket, http-version), config file, and environment variables.
