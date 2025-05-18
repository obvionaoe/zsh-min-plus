autoload -Uz vcs_info

# Enable Git
zstyle ':vcs_info:*' enable git

# Git branch + color-coded status indicators
zstyle ':vcs_info:git:*' formats       '%F{cyan}%f %b %c%u%m'
zstyle ':vcs_info:git:*' actionformats '%F{cyan}%f %b|%a %c%u%m'

# Enable change detection
zstyle ':vcs_info:git:*' check-for-changes true
zstyle ':vcs_info:git:*' stagedstr    '%F{green}●%f'
zstyle ':vcs_info:git:*' unstagedstr  '%F{yellow}✚%f'
zstyle ':vcs_info:git:*' untrackedstr '%F{red}…%f'

# Only use one message slot
zstyle ':vcs_info:*' max-exports 1

# Refresh VCS info before prompt
precmd_functions+=(_update_vcs_info)
_update_vcs_info() {
  vcs_info
}

# Path shortener: preserves ~ and shows full last directory
shorten_path() {
  local path="${PWD/#$HOME/~}"
  local IFS='/'
  local -a parts shortened_parts
  local last shortened

  parts=(${(s:/:)path})
  last="${parts[-1]}"

  if (( ${#parts} <= 1 )); then
    echo "$path"
    return
  fi

  parts=(${parts[1,-2]})
  shortened_parts=()

  for part in $parts; do
    if [[ "$part" == "~" ]]; then
      shortened_parts+=("$part")
    elif [[ -n "$part" ]]; then
      shortened_parts+=("${part[1,3]}")
    fi
  done

  shortened="${(j:/:)shortened_parts}"

  if [[ -z "$shortened" ]]; then
    echo "$last"
  elif [[ "$shortened" == "~" ]]; then
    echo "~/$last"
  else
    echo "$shortened/$last"
  fi
}

shortened_path="$(shorten_path)"
chpwd_functions+=(_update_shortened_path)
_update_shortened_path() {
  shortened_path=$(shorten_path)
}

# GCP profile (cache command availability)
_min_has_gcloud=0
(( $+commands[gcloud] )) && _min_has_gcloud=1

gcp_profile() {
  [[ $_min_has_gcloud -ne 1 ]] && return

  local active_config
  active_config="$(<~/.config/gcloud/active_config 2>/dev/null)"

  if [[ "$active_config" != "default" ]]; then
    MIN_GCP_PROFILE="$active_config"
  else
    MIN_GCP_PROFILE=""
  fi
}

# Refresh GCP profile before prompt
precmd_functions+=(_update_gcp_profile)
_update_gcp_profile() {
  gcp_profile
}

# Kubernetes context (cache commands availability)
_min_has_kubectx=0
_min_has_kubens=0
(( $+commands[kubectx] )) && _min_has_kubectx=1
(( $+commands[kubens] )) && _min_has_kubens=1

get_k8s_info() {
  local context namespace
  [[ $_min_has_kubectx -eq 1 ]] && context=$(kubectx -c 2>/dev/null) || return
  [[ $_min_has_kubens -eq 1 ]] && namespace=$(kubens -c 2>/dev/null) || namespace=""
  [[ -z "$namespace" ]] && namespace="default"

  echo "$context:$namespace"
}

# Exit code display (only if non-zero)
get_exit_code() {
  local last_status=$1
  if (( last_status != 0 )); then
    echo " %F{red}${last_status}%f"
  else
    echo ""
  fi
}

precmd_functions+=(_update_exit_code)
_update_exit_code() {
  exit_code="$(get_exit_code $?)"
}

# Compose RPROMPT: [ git | k8s | aws | gcp ]
compose_rprompt() {
  local segments=()

  [[ -n "$vcs_info_msg_0_" ]] && segments+=("$vcs_info_msg_0_")

  local k8s="$(get_k8s_info)"
  [[ -n "$k8s" ]] && segments+=("󱃾 $k8s")

  [[ -n "$AWS_PROFILE" ]] && segments+=("  $AWS_PROFILE")

  [[ -n "$MIN_GCP_PROFILE" ]] && segments+=("󱇶 $MIN_GCP_PROFILE")

  [[ $#segments -gt 0 ]] && echo "[ ${(j: | :)segments} ]"
}

precmd_functions+=(_update_rprompt_segments)
_update_rprompt_segments() {
  rprompt_segments="$(compose_rprompt)"
}

PROMPT_COLOR=cyan; [ $UID -eq 0 ] && PROMPT_COLOR=red

PROMPT='%{$fg[$PROMPT_COLOR]%}${shortened_path}%{$reset_color%} %(!.#.>) '
RPROMPT='${rprompt_segments}${exit_code}'
