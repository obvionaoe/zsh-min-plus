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
  command -v gcloud >/dev/null || return
  gcloud config get-value account 2>/dev/null
}

# Kubernetes context
get_k8s_info() {
  command -v kubectl >/dev/null || return
  local context namespace
  context=$(kubectl config current-context 2>/dev/null) || return
  namespace=$(kubectl config view --minify --output 'jsonpath={..namespace}' 2>/dev/null)
  [[ -z "$namespace" ]] && namespace="default"
  echo "$context:$namespace"
}

# Git info
get_git_branch() {
  command -v git >/dev/null || return
  git rev-parse --is-inside-work-tree &>/dev/null || return
  local branch="$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)"
  [[ -n "$branch" ]] && echo "$branch"
}

# Exit code display (only if non-zero)
exit_code_prompt() {
  [[ $? -ne 0 ]] && echo "%{$fg[red]%}✖ $?%{$reset_color%}"
}

# Compose PROMPT: shorten path, optional exit code, prompt symbol
compose_prompt() {
  local color="%{$fg[$PROMPT_COLOR]%}"
  local reset="%{$reset_color%}"
  local path="$(shorten_path)"
  local exit="$(exit_code_prompt)"
  local symbol='%(!.#.>)'

  if [[ -n "$exit" ]]; then
    echo "${color}${path} ${exit} ${reset}${symbol} "
  else
    echo "${color}${path} ${reset}${symbol} "
  fi
}

# Compose RPROMPT: [ git | k8s | aws | gcp ]
compose_rprompt() {
  local segments=()

  local git="$(get_git_branch)"
  [[ -n "$git" ]] && segments+=(" $git")

  local k8s="$(get_k8s_info)"
  [[ -n "$k8s" ]] && segments+=("󱃾 $k8s")

  local aws="$(get_aws_profile)"
  [[ -n "$aws" ]] && segments+=(" $aws")

  local gcp="$(get_gcp_profile)"
  [[ -n "$gcp" ]] && segments+=("󱇶 $gcp")

  [[ $#segments -gt 0 ]] && echo "[ ${(j: | :)segments} ]"
}

update_minplus_prompt() {
  PROMPT="$(compose_prompt)"
  RPROMPT="$(compose_rprompt)"
}

# --- Main prompt setup ---
# Load colors
autoload -U colors && colors

PROMPT_COLOR=cyan
[[ $UID -eq 0 ]] && PROMPT_COLOR=red

# --- Hooks ---
autoload -Uz add-zsh-hook
add-zsh-hook precmd update_minplus_prompt
