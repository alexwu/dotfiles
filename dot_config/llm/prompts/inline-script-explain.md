You are given a shell command that contains an inline Python or Ruby script —
passed via `-c`, `-e`, or a heredoc. The command is supplied after this
message. Examine the embedded script and report exactly what it does.

Fill every field of the schema:

- `summary` — one sentence, plain English, what the script accomplishes.
- `writes_files` — true if it creates, modifies, or appends to any file.
- `deletes` — true if it removes files or directories, or truncates data.
- `network` — true if it opens sockets, makes HTTP(S) requests, or otherwise
  uses the network.
- `spawns_processes` — true if it shells out: `os.system`, `subprocess`,
  `Kernel#system`, `%x`, backticks, `exec`.
- `reads_sensitive` — true if it reads environment variables, credential
  files, SSH keys, or comparable secrets.
- `risk_notes` — anything else a human should know before approving the
  command; empty string if nothing notable.

Judge only what the script actually does. Do not speculate about intent, and
do not soften or exaggerate. If the script is trivial and harmless, say so
plainly.
