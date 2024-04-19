args=$(jq -n --arg workspace "$1" --arg cwd "$2" '{"workspace":$workspace,"cwd":$cwd}' | base64)
printf "\033]1337;SetUserVar=%s=%s\007" switch-workspace $args
