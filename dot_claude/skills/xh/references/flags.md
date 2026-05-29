# xh flag reference

Grouped by purpose. Every `--OPTION` can be reset with `--no-OPTION` (useful for overriding a default set in the config file). Run `xh help` for the long built-in help, `xh --help` for the cheatsheet.

## Body serialization

| Flag | Effect |
|------|--------|
| `-j`, `--json` | (default) Serialize `key=value` items as a JSON object. Overrides `-f`/`--multipart`. |
| `-f`, `--form` | Serialize items as `application/x-www-form-urlencoded` form fields. |
| `--multipart` | Force `multipart/form-data`, even with no file parts. |
| `--raw <RAW>` | Send `RAW` as the body verbatim, no request-item processing. |

## Output: what to print

| Flag | Effect |
|------|--------|
| `-p`, `--print <FORMAT>` | String of `H` req-headers, `B` req-body, `h` resp-headers, `b` resp-body, `m` resp-meta. e.g. `-p Hhb`. |
| `-h`, `--headers` | Response headers only (`= -p h`). |
| `-b`, `--body` | Response body only (`= -p b`). |
| `-m`, `--meta` | Response metadata only (`= -p m`). |
| `-v`, `--verbose` | Whole request + response (`-p HhBb --all`). `-vv` also prints response metadata. |
| `-P`, `--history-print <FORMAT>` | Like `-p` but only for intermediary (redirect) exchanges. |
| `--all` | Show intermediary requests/responses when following redirects. |
| `-q`, `--quiet` | Suppress stdout/stderr. `-qq` suppresses warnings too. |
| `-S`, `--stream` | Always stream the response body. |
| `-o`, `--output <FILE>` | Write output to `FILE` instead of stdout. |

## Output: formatting & color

| Flag | Effect |
|------|--------|
| `--pretty <STYLE>` | `all` (default), `colors`, `format`, `none`. Auto-downgrades to `none` when stdout isn't a TTY. |
| `--format-options <OPTS>` | e.g. `json.indent:2,headers.sort:false,json.format:true`. |
| `-s`, `--style <THEME>` | `auto`, `solarized`, `monokai`, `fruity`. |
| `--response-charset <ENC>` | Override response decoding for display, e.g. `latin1`. |
| `--response-mime <MIME>` | Override response MIME for coloring/formatting, e.g. `application/json`. |

## Auth & sessions

| Flag | Effect |
|------|--------|
| `-a`, `--auth <USER[:PASS] \| TOKEN>` | Credentials. PASS is prompted if omitted; trailing `:` (e.g. `user:`) authenticates with username only. For `-A bearer`, pass the token. |
| `-A`, `--auth-type <TYPE>` | `basic` (default), `bearer`, `digest`. |
| `--ignore-netrc` | Don't read credentials from `.netrc`. |
| `--session <FILE>` | Create or reuse+update a session — persists custom headers, auth, and server cookies across requests. A bare name uses `XH_CONFIG_DIR/sessions`; a path (`./api.json`) is a standalone file. |
| `--session-read-only <FILE>` | Use a session without writing changes back to it. |

## Redirects, status, timeout

| Flag | Effect |
|------|--------|
| `-F`, `--follow` | Follow redirects. |
| `--max-redirects <N>` | Cap redirect hops (only with `--follow`). |
| `--check-status` | (default in xh) Exit non-zero on HTTP error — see exit codes below. |
| `--timeout <SEC>` | Connection timeout; `0` (default) means no limit. |

**Exit codes:** `0` ok · `1` usage/syntax/network · `2` timeout · `3` un-followed 3xx · `4` 4xx · `5` 5xx · `6` too many redirects.

## Request construction / dry-run

| Flag | Effect |
|------|--------|
| `--offline` | Build and print the request without sending it. |
| `--curl` | Print a `curl` translation instead of sending. |
| `--curl-long` | Use curl's long-form flags in the translation. |
| `-x`, `--compress` | Deflate-compress the request body (`Content-Encoding: deflate`); repeat to force even at negative ratio. |
| `-I`, `--ignore-stdin` | Don't read stdin. **Required for scripted/non-TTY use** or xh blocks waiting for a body. |

## Download

| Flag | Effect |
|------|--------|
| `-d`, `--download` | Save the body to a file (sets `Accept-Encoding: identity`, follows redirects). Filename comes from the URL/Content-Disposition unless `-o` is given. |
| `-c`, `--continue` | Resume an interrupted download. Requires `-d` and `-o`. |

## TLS / certificates

| Flag | Effect |
|------|--------|
| `--verify <yes\|no\|FILE>` | `no`/`false` skips verification; a path is used as the CA bundle (disables system roots). Default `yes`. |
| `--cert <FILE>` | Client certificate for mutual TLS. |
| `--cert-key <FILE>` | Private key for `--cert` (if not bundled in the cert). |
| `--ssl <VERSION>` | Force TLS version: `auto`, `tls1`, `tls1.1`, `tls1.2`, `tls1.3`. |
| `--native-tls` | Use the system TLS library instead of rustls (if compiled in). |

## Networking

| Flag | Effect |
|------|--------|
| `--https` | Use HTTPS when the URL omits a scheme (same as invoking `xhs`). |
| `--http-version <V>` | `1.0`, `1.1`, `2`, `2-prior-knowledge`, `3-prior-knowledge`. |
| `--proxy <PROTO:URL>` | Per-protocol proxy; `PROTO` is `http`/`https`/`all`. Repeatable. Credentials go in the URL. Overrides `http_proxy`/`https_proxy` env entirely. |
| `--resolve <HOST:ADDR>` | Override DNS for a host to a fixed IP. Repeatable. |
| `--interface <NAME>` | Bind to a network interface or local IP. |
| `-4`, `--ipv4` / `-6`, `--ipv6` | Restrict resolution to IPv4 / IPv6. |
| `--unix-socket <FILE>` | Connect over a Unix domain socket, e.g. `xh :/index.html --unix-socket=/var/run/x.sock`. |

## Diagnostics & misc

| Flag | Effect |
|------|--------|
| `--debug` | Full error stack traces + debug logs. Tune with `RUST_LOG` (e.g. `RUST_LOG=trace`). |
| `--generate <KIND>` | Emit shell completions (`complete-{bash,zsh,fish,elvish,nushell,powershell}`) or `man`. |
| `-V`, `--version` | Version. |

## Config file & environment

- **`XH_CONFIG_DIR/config.json`** (default `~/.config/xh/`) — only key is `default_options`, a list of args prepended to every invocation:
  ```json
  { "default_options": ["--native-tls", "--style=solarized"] }
  ```
  Override a default per-call with the matching `--no-OPTION`.
- **`XH_CONFIG_DIR`** — relocate config + named session storage.
- **`XH_HTTPIE_COMPAT_MODE`** — strict HTTPie compatibility (disables xh's default `--check-status`). Also triggered by naming the binary `http`/`https`.
- **`REQUESTS_CA_BUNDLE` / `CURL_CA_BUNDLE`** — custom CA bundle path.
- **`http_proxy` / `HTTPS_PROXY` / `NO_PROXY`** — proxy config (ignored entirely if `--proxy` is passed).
- **`NETRC`** — `.netrc` location. **`NO_COLOR`** — disable coloring. **`RUST_LOG`** — low-level debug verbosity.
