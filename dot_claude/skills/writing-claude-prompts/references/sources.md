# Sources

The manifest of every page this skill distills. `just refresh-prompting-docs` in the chezmoi repo reads the table below: it scrapes each URL into `.firecrawl/<slug>.md` and diffs it against the previous scrape. Keep one page per row in this exact shape, with the URL in angle brackets, or the recipe won't see it.

The recipe also maps the prompt-engineering index (<https://platform.claude.com/docs/en/build-with-claude/prompt-engineering>) and reports pages missing from this table. A new model guide gets a row here and its own reference file.

| Slug | URL | Feeds | Fetched |
|---|---|---|---|
| claude-prompting-best-practices | <https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices> | best-practices.md | 2026-09-29 |
| overview | <https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/overview> | best-practices.md | 2026-09-29 |
| prompting-claude-fable-5-1 | <https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5-1> | fable-5-1.md | 2026-09-29 |
| prompting-claude-fable-5 | <https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5> | fable-5.md | 2026-09-29 |
| prompting-claude-opus-5-5 | <https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5-5> | opus-5-5.md | 2026-09-29 |
| prompting-claude-opus-5 | <https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5> | opus-5.md | 2026-09-29 |
| prompting-claude-opus-4-8 | <https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-4-8> | opus-4-8.md | 2026-09-29 |
| prompting-claude-sonnet-5-5 | <https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-sonnet-5-5> | sonnet-5-5.md | 2026-09-29 |
| prompting-claude-sonnet-5 | <https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-sonnet-5> | sonnet-5.md | 2026-09-29 |
| mid-conversation-system-messages | <https://platform.claude.com/docs/en/build-with-claude/mid-conversation-system-messages> | mid-conversation-system-messages.md | 2026-09-29 |

Every docs URL also serves plain markdown with `.md` appended. The recipe falls back to that when a firecrawl scrape fails or comes back backslash-escaped: lines ending in `[\`, `,\`, or `}\`, lines that are a bare `\`, or `\-\-\-`. Firecrawl's escaping varies from run to run on the same page. Once a page has come back raw (raw files start with `---` frontmatter), the recipe keeps fetching it raw so its diffs compare like with like. On 2026-09-29 four pages came back raw: best-practices, Sonnet 5.5, Fable 5.1, and mid-conversation.
