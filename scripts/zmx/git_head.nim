## The branch checked out in a directory, read from `HEAD` without running git.

import std/[options, os, strutils]

export options

func parseHead*(head: string): Option[string] =
  ## `ref: refs/heads/feat/x` is `feat/x`; any other ref strips `refs/`
  ## (`refs/remotes/origin/x` is `remotes/origin/x`); a detached HEAD (a bare
  ## hash) is none.
  const Prefix = "ref: "
  let line = head.strip()
  if not line.startsWith(Prefix):
    return none(string)
  var name = line[Prefix.len ..^ 1].strip()
  if name.startsWith("refs/heads/"):
    name.removePrefix("refs/heads/")
  else:
    name.removePrefix("refs/")
  if name.len > 0:
    result = some(name)

proc gitDirOf(dotGit: string): Option[string] =
  ## Where `HEAD` lives: `.git` itself, or the directory a worktree's `.git`
  ## file names (relative to that file when not absolute).
  const Prefix = "gitdir: "
  if dirExists(dotGit):
    return some(dotGit)
  for line in readFile(dotGit).splitLines:
    if line.startsWith(Prefix):
      let target = line[Prefix.len ..^ 1].strip()
      return some(
        if target.isAbsolute:
          target
        else:
          dotGit.parentDir / target
      )

proc branchOf*(dir: string): Option[string] =
  ## The checked-out branch of the repository containing `dir`. None for a
  ## detached HEAD, a directory outside any repository, an empty `dir`, or a
  ## `HEAD` that cannot be read. `GIT_DIR` is not consulted.
  var at = dir
  while at.len > 0:
    let dotGit = at / ".git"
    if dirExists(dotGit) or fileExists(dotGit):
      try:
        let gitDir = gitDirOf(dotGit)
        if gitDir.isSome:
          return parseHead(readFile(gitDir.get / "HEAD"))
      except IOError, OSError:
        discard
      return none(string)
    let parent = at.parentDir
    if parent == at:
      break
    at = parent
