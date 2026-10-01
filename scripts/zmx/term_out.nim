## Terminal output shared by the zmx tools: colours, the column layout of the
## coloured views, and a bordered table through `gum` with a plain fallback.

import std/[os, osproc, sequtils, streams, strutils]
from std/unicode import runeLenAt

const
  Bold* = "\e[1m"
  Dim* = "\e[2m"
  Red* = "\e[31m"
  Green* = "\e[32m"
  Yellow* = "\e[33m"
  Blue* = "\e[34m"
  Magenta* = "\e[35m"
  Cyan* = "\e[36m"
  Reset* = "\e[0m"
  DotFull* = "●"
  DotHollow* = "○"
  DotSmall* = "◦"
  Middot* = "·"
  EmDash* = "—"

func paint*(color, text: string): string =
  ## Empty text stays empty, so a blank cell carries no escapes.
  if text.len == 0:
    ""
  else:
    color & text & Reset

func visibleLen*(cell: string): int =
  ## Characters a terminal draws: runes, with SGR sequences not counted.
  var i = 0
  while i < cell.len:
    if cell[i] == '\e' and i + 1 < cell.len and cell[i + 1] == '[':
      i += 2
      while i < cell.len and cell[i] != 'm':
        inc i
      inc i
    else:
      inc result
      i += runeLenAt(cell, i)

func layout*(rows: openArray[seq[string]]): seq[string] =
  ## One line per row, cells a space apart, every column but a row's last
  ## padded to its widest visible cell. A column empty in every row is left out.
  var widths: seq[int]
  for row in rows:
    if row.len > widths.len:
      widths.setLen(row.len)
    for i, cell in row:
      widths[i] = max(widths[i], visibleLen(cell))
  for row in rows:
    var line = ""
    for i, cell in row:
      if widths[i] == 0:
        continue
      if line.len > 0:
        line.add ' '
      line.add cell
      if i < row.high:
        line.add spaces(widths[i] - visibleLen(cell))
    result.add line.strip(leading = false)

proc gumTable(columns: openArray[string], rows: seq[seq[string]]): bool =
  ## Renders through `gum table`. False when gum is missing or rejects the
  ## rows, and then nothing has been printed.
  if findExe("gum").len == 0:
    return false
  try:
    let gum = startProcess(
      "gum",
      args = [
        "table",
        "--print",
        "--lazy-quotes",
        "--separator",
        "\t",
        "--columns",
        columns.join(","),
      ],
      options = {poUsePath},
    )
    defer:
      gum.close()
    for row in rows:
      gum.inputStream.writeLine row.join("\t")
    gum.inputStream.close()
    let rendered = gum.outputStream.readAll()
    if gum.waitForExit() != 0:
      return false
    stdout.write rendered
    true
  except OSError, IOError:
    false

proc plainTable(columns: openArray[string], rows: seq[seq[string]]) =
  var widths = columns.mapIt(it.len)
  for row in rows:
    for i, cell in row:
      widths[i] = max(widths[i], cell.len)
  for row in @[@columns] & rows:
    var line = ""
    for i, cell in row:
      line.add (if i == row.high: cell else: alignLeft(cell, widths[i] + 2))
    echo line

proc printTable*(columns: openArray[string], rows: seq[seq[string]]) =
  ## `gum table --print`; a plain aligned table when gum is missing, rejects
  ## the rows, or there are none.
  if rows.len == 0 or not gumTable(columns, rows):
    plainTable(columns, rows)
