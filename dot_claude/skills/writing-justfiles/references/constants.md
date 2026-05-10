# Justfile Constants — Reference

Source: <https://just.systems/man/en/constants.html>

29 predefined constants, all available without `set unstable`. Three groups: hex digits (3), path separators (2), and ANSI/SGR escape sequences (24 — clear + 7 attribute toggles + 8 foreground colors + 8 background colors).

See also: [`built-in-functions.md`](built-in-functions.md) — `style(name)` returns just's *internal* styles (`'command'` / `'error'` / `'warning'`) that match its own diagnostic output. Use `style()` when you want output to look like just itself; use the raw constants below when you want explicit, portable SGR codes.

## Full table

| Name | Since | Value | Windows |
|------|------:|-------|---------|
| `HEX` | 1.27.0 | `"0123456789abcdef"` | — |
| `HEXLOWER` | 1.27.0 | `"0123456789abcdef"` | — |
| `HEXUPPER` | 1.27.0 | `"0123456789ABCDEF"` | — |
| `PATH_SEP` | 1.41.0 | `"/"` | `"\"` |
| `PATH_VAR_SEP` | 1.41.0 | `":"` | `";"` |
| `CLEAR` | 1.37.0 | `"\ec"` | — |
| `NORMAL` | 1.37.0 | `"\e[0m"` | — |
| `BOLD` | 1.37.0 | `"\e[1m"` | — |
| `ITALIC` | 1.37.0 | `"\e[3m"` | — |
| `UNDERLINE` | 1.37.0 | `"\e[4m"` | — |
| `INVERT` | 1.37.0 | `"\e[7m"` | — |
| `HIDE` | 1.37.0 | `"\e[8m"` | — |
| `STRIKETHROUGH` | 1.37.0 | `"\e[9m"` | — |
| `BLACK` | 1.37.0 | `"\e[30m"` | — |
| `RED` | 1.37.0 | `"\e[31m"` | — |
| `GREEN` | 1.37.0 | `"\e[32m"` | — |
| `YELLOW` | 1.37.0 | `"\e[33m"` | — |
| `BLUE` | 1.37.0 | `"\e[34m"` | — |
| `MAGENTA` | 1.37.0 | `"\e[35m"` | — |
| `CYAN` | 1.37.0 | `"\e[36m"` | — |
| `WHITE` | 1.37.0 | `"\e[37m"` | — |
| `BG_BLACK` | 1.37.0 | `"\e[40m"` | — |
| `BG_RED` | 1.37.0 | `"\e[41m"` | — |
| `BG_GREEN` | 1.37.0 | `"\e[42m"` | — |
| `BG_YELLOW` | 1.37.0 | `"\e[43m"` | — |
| `BG_BLUE` | 1.37.0 | `"\e[44m"` | — |
| `BG_MAGENTA` | 1.37.0 | `"\e[45m"` | — |
| `BG_CYAN` | 1.37.0 | `"\e[46m"` | — |
| `BG_WHITE` | 1.37.0 | `"\e[47m"` | — |

## ANSI / SGR notes

Constants prefixed `\e` are [ANSI escape sequences](https://en.wikipedia.org/wiki/ANSI_escape_code). `CLEAR` clears the screen (similar to the `clear` command); the rest are of the form `\e[Nm` where `N` is an integer, and set terminal display attributes (SGR codes).

Terminal display attribute escape sequences can be combined — for example text weight `BOLD`, text style `STRIKETHROUGH`, foreground color `CYAN`, and background color `BG_BLUE` — and they should be followed by `NORMAL` to reset the terminal back to normal.

Escape sequences should be quoted, since `[` is treated as a special character by some shells.

## Example

```just
@scary:
    echo '{{BOLD + STRIKETHROUGH + CYAN + BG_BLUE}}Hi!{{NORMAL}}'

@cross-platform:
    echo "delim:{{PATH_SEP}} pathvar:{{PATH_VAR_SEP}}"
```

## When to reach for which

- **`HEX` / `HEXLOWER` / `HEXUPPER`** — building hex literals, generating IDs/colors, validating digits in functions like `replace_regex`. `HEX` and `HEXLOWER` are aliases (both lowercase); use `HEXUPPER` only when you specifically need uppercase output.
- **`PATH_SEP` / `PATH_VAR_SEP`** — the only two constants that differ between Unix and Windows. Use them in cross-platform recipes that build paths or `PATH`-style variables; on Windows you get `\` and `;` instead of `/` and `:`.
- **SGR colors / styles** — for raw, portable ANSI output. If you instead want to *match just's own diagnostic styling* (e.g. echo a recipe-style banner), prefer [`style(name)`](built-in-functions.md#stylename-1370), which respects the user's `--color` setting and outputs `'command'` / `'error'` / `'warning'` styles. Raw constants always emit the escape regardless of `--color`.
- Always pair an SGR opener with `NORMAL`; combine with `+` inside `{{ ... }}` interpolation; quote the whole interpolated string so shells don't choke on `[`.
