# Override zoxide's default `z` completion to always show
# frecency-ranked results from the zoxide database.
complete --erase --command z
complete --command z --no-files --arguments '(zoxide query -l -- (commandline -opc)[2..] 2>/dev/null | string replace $HOME "~")'
