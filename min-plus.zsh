autoload -Uz vcs_info

# Enable Git
zstyle ':vcs_info:*' enable git

# Git branch + color-coded status indicators
zstyle ':vcs_info:git:*' formats       '%F{cyan}%f %b%c%u%m'
zstyle ':vcs_info:git:*' actionformats '%F{cyan}%f %b|%a%c%u%m'

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

# Path shortener: preserves ~/ and shows full last directory
shorten_path() {
  local path="${PWD/#$HOME/~}"
  local IFS='/' parts shortened

  parts=(${(s:/:)path})
  local last="${parts[-1]}"
  unset 'parts[-1]'

  shortened=""
  for part in $parts; do
    if [[ "$part" == "~" ]]; then
      shortened="$part"
    elif [[ -n "$part" ]]; then
      shortened+="/${part[1,3]}"
    fi
  done

  echo "$shortened/$last"
}

# AWS profile
get_aws_profile() {
  [[ -n "$AWS_PROFILE" ]] && echo "$AWS_PROFILE"
}

# GCP profile
get_gcp_profile() {
  if (( $+commands[gcloud] )); then
    gcloud config get-value account 2>/dev/null
  fi
}

# Kubernetes context
get_k8s_info() {
  local context namespace

  if (( $+commands[kubectx] )); then
    context=$(kubectx -c 2>/dev/null) || return
  fi

  if (( $+commands[kubens] )); then
    namespace=$(kubens -c 2>/dev/null)
  fi

  [[ -z "$namespace" ]] && namespace="default"

  echo "$context:$namespace"
}

# Exit code display (only if non-zero)
exit_code_prompt() {
  [[ $? -ne 0 ]] && echo "%{$fg[red]%} ✖ $?%{$reset_color%}"
}

# Compose PROMPT: shorten path, optional exit code, prompt symbol
compose_prompt() {
  local color="%{$fg[$PROMPT_COLOR]%}"
  local reset="%{$reset_color%}"
  local path="$(shorten_path)"
  local symbol='%(!.#.>)'

  echo "${color}${path} ${reset}${symbol} "
}

# Compose RPROMPT: [ git | k8s | aws | gcp ]
compose_rprompt() {
  local segments=()

  local git="${vcs_info_msg_0_}"
  [[ -n "$git" ]] && segments+=("$git")

  local k8s="$(get_k8s_info)"
  [[ -n "$k8s" ]] && segments+=("󱃾 $k8s")

  local aws="$(get_aws_profile)"
  [[ -n "$aws" ]] && segments+=("  $aws")

  local gcp="$(get_gcp_profile)"
  [[ -n "$gcp" ]] && segments+=("󱇶 $gcp")

  local exit="$(exit_code_prompt)"

  [[ $#segments -gt 0 ]] && echo "[ ${(j: | :)segments} ]${exit}"
}

PROMPT='$(shorten_path) %(!.#.>) '
RPROMPT='$(compose_rprompt)'
