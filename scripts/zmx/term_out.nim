## Terminal output shared by the zmx tools: colours, glyphs, and the column
## layout of their views. Everything is drawn in-process: starting `gum` cost
## about 60 ms a call, and `gum table --print` dropped cell colours.

import std/strutils
from std/unicode import runeLen, runeLenAt, runeSubStr

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
  Ellipsis* = "…"
  NameWidth* = 28 ## an agent's name is clipped to this in every view

func paint*(color, text: string): string =
  ## Empty text stays empty, so a blank cell carries no escapes.
  if text.len == 0:
    ""
  else:
    color & text & Reset

func clip*(text: string, width: int): string =
  ## `text` in at most `width` characters, the last an ellipsis when it was
  ## longer.
  if width <= 0:
    ""
  elif text.runeLen <= width:
    text
  else:
    # A negative length would count from the end, hence the guard above.
    text.runeSubStr(0, width - 1) & Ellipsis

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
