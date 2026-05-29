# xh request items — full grammar

Request items are the positional `key<sep>value` arguments after the URL. The separator determines whether the pair becomes a body field, a query parameter, a header, or a file. This is HTTPie's [request-item syntax](https://httpie.io/docs/cli/request-items), which xh implements.

## Separators at a glance

| Syntax | Becomes | Notes |
|--------|---------|-------|
| `key=value` | Body field, **string** | JSON string by default; form field under `-f`/`--multipart` |
| `key:=value` | Body field, **raw JSON** | `value` is parsed as JSON — number, bool, null, array, object |
| `key==value` | Query string | Appended to URL as `?key=value`, URL-encoded |
| `header:value` | Header | e.g. `user-agent:foobar` → `User-Agent: foobar` |
| `header:` | **Unset** header | Suppresses a header xh would otherwise send (e.g. `connection:`) |
| `header;` | Header with **empty value** | Sends the header name with no value |
| `field@path` | File upload | Requires `-f` or `--multipart`; field is a form part |
| `@path` | Whole request body | The file's contents become the raw body |

## String vs raw JSON (`=` vs `:=`)

The single most common mistake is using `=` where `:=` is needed. `=` always produces a JSON **string**; `:=` parses the value as a JSON literal.

```bash
xh --offline POST :8000 count=5 active=true
# {"count": "5", "active": "true"}   <- strings, probably not what you want

xh --offline POST :8000 count:=5 active:=true
# {"count": 5, "active": true}       <- numbers and bools
```

Use `:=` for numbers, booleans, `null`, arrays, and inline objects:

```bash
xh --offline POST :8000 \
  age:=24 \
  verified:=true \
  nickname:=null \
  tags:='["red","green"]' \
  meta:='{"k":"v"}'
```

Quote the value in the shell when it contains characters the shell would otherwise interpret (`[`, `]`, `{`, `}`, spaces).

## Reading values from a file (`@` prefix on the value)

Prefix any value with `@` to load it from a file. Works for body fields, headers, and query params:

```bash
xh -I POST :8000/posts body=@article.md          # string field from file
xh -I :8000/me x-api-key:@secrets/api-key.txt     # header value from file
xh -I POST :8000 config:=@config.json             # raw JSON field from a JSON file
```

This differs from `@path` (no key), which sends the file as the **entire** request body.

## Request body from a file or stdin

```bash
# Entire body from a file (Content-Type inferred from extension)
xh -I POST :8000/data @payload.json

# Entire body from stdin — note: NO -I here, because piping a body is the intent
echo '[1, 2, 3]' | xh POST :8000/numbers
cat payload.json | xh POST :8000/data
```

When you pipe a body in, command-line body items (`key=value`) cannot also be used — the stdin body wins.

## File uploads (multipart)

The `field@path` form attaches a file as a multipart part. It requires `-f`/`--form`-style multipart, so pass `--multipart` (or `-f` with at least one file):

```bash
xh -I --multipart POST :8000/upload \
  photo@./ra.jpg \
  caption=sunset
```

Override the part's MIME type and/or filename with `;type=` and `;filename=`:

```bash
xh -I --multipart POST :8000/upload \
  pfp@ra.jpg;type=image/jpeg;filename=profile.jpg
```

## Headers — set, unset, empty

```bash
xh -I :8000 user-agent:my-script/1.0      # set a header
xh -I :8000 connection:                    # unset a header xh sends by default
xh -I :8000 x-trace;                        # send "X-Trace:" with an empty value
```

Header names are case-insensitive on the wire; xh title-cases them.

## Escaping separators in keys

If a key legitimately contains `:`, `=`, `@`, etc., escape it with a backslash so xh doesn't read it as a separator:

```bash
xh --offline POST :8000 'weird\:key=value'    # field named "weird:key"
```

## Nested JSON via JSON-path keys

To build a nested object/array without writing raw JSON, use a JSON path as the key. xh follows HTTPie's [nested-JSON syntax](https://httpie.io/docs/cli/nested-json).

- `[key]` — object member
- `[index]` — array element (by position)
- `[]` — append to an array

```bash
xh --offline POST :8000 \
  'app[container][0][id]=090-5' \
  'app[container][0][tags][]:=1' \
  'app[container][0][tags][]:=2' \
  'app[name]=demo'
```

produces roughly:

```json
{
  "app": {
    "container": [
      { "id": "090-5", "tags": [1, 2] }
    ],
    "name": "demo"
  }
}
```

`=` vs `:=` still controls string-vs-raw at the leaf. Always confirm complex nests with `--offline` before sending — the bracket grammar is finicky and easier to verify than to reason about.

## `--raw` — bypass all body processing

When you need to send a body exactly as written, with no request-item parsing, pass it via `--raw`:

```bash
xh -I --raw 'arbitrary unprocessed payload' POST :8000/ingest
```

`--raw` and stdin bodies are mutually exclusive with command-line body items.
