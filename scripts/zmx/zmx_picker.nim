## The rows `zmx-select` hands to fzf.

import std/[algorithm, strutils]
import zmx_snapshot

func fmtDir*(dir, home, dotfiles: string): string =
  ## `dotfiles` for the chezmoi source, `Code` for ~/Code, the path under
  ## ~/Code or under home relative to it, `Home` for home, else the full path.
  let code = home & "/Code"
  if dir == dotfiles:
    "dotfiles"
  elif dir == code:
    "Code"
  elif dir.startsWith(code & "/"):
    dir[code.len + 1 .. ^1]
  elif dir == home:
    "Home"
  elif dir.startsWith(home & "/"):
    dir[home.len + 1 .. ^1]
  else:
    dir

func pickerRows*(
    views: openArray[SessionView], cwd: string, hereOnly: bool, home, dotfiles: string
): seq[seq[string]] =
  ## Every session but the current one, sessions in `cwd` first, then by
  ## directory, state and name: `name, dir, state, running or -, cl:N, pid:N`.
  var shown: seq[SessionView]
  for view in views:
    if view.session.current or (hereOnly and view.session.cwd != cwd):
      continue
    shown.add view
  shown.sort do(a, b: SessionView) -> int:
    result = cmp(a.session.cwd != cwd, b.session.cwd != cwd)
    if result == 0:
      result = cmp(a.session.cwd, b.session.cwd)
    if result == 0:
      result = cmp(a.state, b.state)
    if result == 0:
      result = cmp($a.session.name, $b.session.name)
  for view in shown:
    result.add @[
      $view.session.name,
      fmtDir(view.session.cwd, home, dotfiles),
      $view.state,
      view.running.get("-"),
      "cl:" & $view.session.clients,
      "pid:" & $view.session.pid,
    ]
