autoload -Uz vcs_info

# Enable Git
zstyle ':vcs_info:*' enable git

# Git branch + color-coded status indicators
zstyle ':vcs_info:git:*' formats       '%F{cyan}%f %b%c%u%m'
zstyle ':vcs_info:git:*' actionformats '%F{cyan}%f %b|%a%c%u%m'

# Enable change detection
zstyle ':vcs_info:git:*' check-for-changes true
zstyle ':vcs_info:git:*' stagedstr    ' %F{green}●%f'
zstyle ':vcs_info:git:*' unstagedstr  ' %F{yellow}✚%f'
zstyle ':vcs_info:git:*' untrackedstr ' %F{red}…%f'

# Only use one message slot
zstyle ':vcs_info:*' max-exports 1

# Refresh VCS info before prompt
precmd_functions+=(_update_vcs_info)
_update_vcs_info() {
  if [[ -d .git || -n $(git rev-parse --git-dir 2>/dev/null) ]]; then
    vcs_info
  else
    vcs_info_msg_0_=""
  fi
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

# Refresh GCP profile before prompt
precmd_functions+=(_update_gcp_profile)
_update_gcp_profile() {
  [[ $_min_has_gcloud -ne 1 ]] && return

  local active_config
  active_config="$(<~/.config/gcloud/active_config 2>/dev/null)"

  if [[ "$active_config" != "default" ]]; then
    MIN_GCP_PROFILE="󱇶 $active_config"
  else
    MIN_GCP_PROFILE=""
  fi
}

# Kubernetes context (cache commands availability)
_min_has_kubectx=0
_min_has_kubens=0
(( $+commands[kubectx] )) && _min_has_kubectx=1
(( $+commands[kubens] )) && _min_has_kubens=1

precmd_functions+=(_update_k8s_info)
_update_k8s_info() {
  [[ $_min_has_kubectx -eq 1 ]] && context=$(kubectx -c 2>/dev/null) || context=""
  [[ $_min_has_kubens -eq 1 ]] && namespace=$(kubens -c 2>/dev/null) || namespace=""
  [[ -z "$namespace" ]] && namespace="default"
  [[ -n "$context" ]] && MIN_K8S_INFO="󱃾 $context:$namespace" || MIN_K8S_INFO=""
}

# Exit code display (only if non-zero)
get_exit_code() {
  local last_status=$1
  if (( last_status != 0 )); then
    echo "%F{red}${last_status}%f "
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

  [[ -n "$MIN_K8S_INFO" ]] && segments+=("$MIN_K8S_INFO")

  [[ -n "$AWS_PROFILE" ]] && segments+=("  $AWS_PROFILE")

  [[ -n "$MIN_GCP_PROFILE" ]] && segments+=("$MIN_GCP_PROFILE")

  [[ $#segments -gt 0 ]] && echo "[ ${(j: | :)segments} ]"
}

precmd_functions+=(_update_rprompt_segments)
_update_rprompt_segments() {
  rprompt_segments="$(compose_rprompt)"
}

PROMPT_COLOR=cyan; [ $UID -eq 0 ] && PROMPT_COLOR=red

PROMPT='%{$fg[$PROMPT_COLOR]%}${shortened_path}%{$reset_color%} %(!.#.>) '
RPROMPT='${exit_code}${rprompt_segments}'
