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
  local last shortened out

  parts=(${(s:/:)path})
  last="${parts[-1]}"
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

  if [[ "$shortened" == "~" ]]; then
    echo "~"
  else
    echo "$shortened/$last"
  fi
}

shortened_path="$PWD"
chpwd_functions+=(_update_shortened_path)
_update_shortened_path() {
  shortened_path=$(shorten_path)
}

# GCP profile (cache command availability)
_min_has_gcloud=0
(( $+commands[gcloud] )) && _min_has_gcloud=1

get_gcp_profile() {
  if (( _min_has_gcloud )); then
    gcloud config get-value account 2>/dev/null
  fi
}

# Kubernetes context (cache commands availability)
_min_has_kubectx=0
_min_has_kubens=0
(( $+commands[kubectx] )) && _min_has_kubectx=1
(( $+commands[kubens] )) && _min_has_kubens=1

get_k8s_info() {
  local context namespace
  [[ $_min_has_kubectx -eq 1 ]] && context=$(kubectx -c 2>/dev/null) || context=""
  [[ $_min_has_kubens -eq 1 ]] && namespace=$(kubens -c 2>/dev/null) || namespace=""
  [[ -z "$namespace" ]] && namespace="default"

  if [[ -n "$context" ]]; then
    echo "$context:$namespace"
  else
    echo ""
  fi
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

  local git="${vcs_info_msg_0_}"
  [[ -n "$git" ]] && segments+=("$git")

  local k8s="$(get_k8s_info)"
  [[ -n "$k8s" ]] && segments+=("󱃾 $k8s")

  [[ -n "$AWS_PROFILE" ]] && segments+=("  $AWS_PROFILE")

  local gcp="$(get_gcp_profile)"
  [[ -n "$gcp" ]] && segments+=("󱇶 $gcp")

  [[ $#segments -gt 0 ]] && echo "[ ${(j: | :)segments} ]${exit}"
}

precmd_functions+=(_update_rprompt_segments)
_update_rprompt_segments() {
  rprompt_segments="$(compose_rprompt)"
}

PROMPT_COLOR=cyan; [ $UID -eq 0 ] && PROMPT_COLOR=red

PROMPT='%{$fg[$PROMPT_COLOR]%}${shortened_path}%{$reset_color%} %(!.#.>) '
RPROMPT='${rprompt_segments}${exit_code}'
