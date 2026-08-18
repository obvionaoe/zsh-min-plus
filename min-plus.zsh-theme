prompt_min_plus_setup() {
    autoload -Uz vcs_info
    autoload -Uz colors && colors

    zstyle ':vcs_info:*' enable git
    zstyle ':vcs_info:git:*' formats       '%F{cyan}%f󰊢 %b%c%u%m'
    zstyle ':vcs_info:git:*' actionformats '%F{cyan}%f󰊢 %b|%a%c%u%m'
    zstyle ':vcs_info:git:*' check-for-changes true
    zstyle ':vcs_info:git:*' stagedstr    ' %F{green}●%f'
    zstyle ':vcs_info:git:*' unstagedstr  ' %F{yellow}✚%f'
    zstyle ':vcs_info:git:*' untrackedstr ' %F{red}…%f'
    zstyle ':vcs_info:*' max-exports 1

    precmd_functions+=(_update_vcs_info)
    precmd_functions+=(_update_gcp_profile)
    precmd_functions+=(_update_k8s_info)
    precmd_functions+=(_update_exit_code)
    precmd_functions+=(_update_rprompt_segments)
    chpwd_functions+=(_update_shortened_path)

    _min_has_gcloud=0
    (( $+commands[gcloud] )) && _min_has_gcloud=1
    _min_has_kubectx=0
    _min_has_kubens=0
    (( $+commands[kubectx] )) && _min_has_kubectx=1
    (( $+commands[kubens] )) && _min_has_kubens=1

    shortened_path="$(shorten_path)"

    PROMPT_COLOR=cyan; [ $UID -eq 0 ] && PROMPT_COLOR=red
    PROMPT="%{$fg[$PROMPT_COLOR]%}\${shortened_path}%{$reset_color%} %(!.#.>) "
    RPS1="\${exit_code}\${rprompt_segments}"
}

# Helper functions defined outside (they need to be available at runtime)
#
# _update_vcs_info is reassigned near the bottom of this file, once we know
# whether the zsh-async worker started — see the block after
# `prompt_min_plus_setup "$@"`. Both variants are defined up front since
# zsh-async requires job functions to exist before the worker forks.
_update_vcs_info_sync() {
  if [[ -d .git || -n $(git rev-parse --git-dir 2>/dev/null) ]]; then
    vcs_info
  else
    vcs_info_msg_0_=""
  fi
}
_update_vcs_info() { _update_vcs_info_sync }

# The async job: runs in a forked worker, so it has its own independent PWD
# — cd into the directory the dispatcher captured rather than relying on
# inherited state. Directory and message share one line, joined by a control
# character rather than a newline: job output is captured through a
# mechanism that strips trailing newlines, so an empty message (not a repo)
# would silently swallow the delimiter and corrupt the parse below.
_min_plus_async_vcs_info() {
  emulate -L zsh
  cd -q "$1" || return
  if [[ -d .git || -n $(git rev-parse --git-dir 2>/dev/null) ]]; then
    vcs_info
  else
    vcs_info_msg_0_=""
  fi
  print -r -- "$1"$'\x01'"$vcs_info_msg_0_"
}

_min_plus_async_callback() {
  local job=$1 output=$3
  [[ $job == _min_plus_async_vcs_info ]] || return
  local for_dir=${output%%$'\x01'*} msg=${output#*$'\x01'}
  [[ $for_dir == $PWD ]] || return
  vcs_info_msg_0_=$msg
  zle && zle reset-prompt
}

_update_vcs_info_async() {
  async_job min_plus_git _min_plus_async_vcs_info "$PWD"
}

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

_update_shortened_path() { shortened_path=$(shorten_path) }
_update_gcp_profile() {
  [[ $_min_has_gcloud -ne 1 ]] && return
  [[ -r ~/.config/gcloud/active_config ]] || return
  local active_config
  active_config="$(<~/.config/gcloud/active_config)"
  [[ "$active_config" != "default" ]] && MIN_GCP_PROFILE="%F{red}󱇶 $active_config%f" || MIN_GCP_PROFILE=""
}

_update_k8s_info() {
  local has_kubectx=0 has_kubens=0
  (( $+commands[kubectx] )) && has_kubectx=1
  (( $+commands[kubens] )) && has_kubens=1

  [[ $has_kubectx -eq 1 ]] && context=$(kubectx -c 2>/dev/null) || context=""
  [[ $has_kubens -eq 1 ]] && namespace=$(kubens -c 2>/dev/null) || namespace=""
  [[ -z "$namespace" ]] && namespace="default"
  [[ -n "$context" ]] && MIN_K8S_INFO="%F{blue}󱃾 $context:$namespace%f" || MIN_K8S_INFO=""
}

get_exit_code() {
  local last_status=$1
  (( last_status != 0 )) && echo "%F{red}${last_status}%f " || echo ""
}

_update_exit_code() { exit_code="$(get_exit_code $?)" }

compose_rprompt() {
  local segments=()
  [[ -n "$vcs_info_msg_0_" ]] && segments+=("$vcs_info_msg_0_")
  [[ -n "$MIN_K8S_INFO" ]] && segments+=("$MIN_K8S_INFO")
  [[ -n "$AWS_PROFILE" ]] && segments+=("%F{yellow}  ${AWS_PROFILE}%f")
  [[ -n "$MIN_GCP_PROFILE" ]] && segments+=("$MIN_GCP_PROFILE")
  [[ $#segments -gt 0 ]] && echo "[ ${(j: | :)segments} ]"
}

_update_rprompt_segments() { rprompt_segments="$(compose_rprompt)" }

setopt PROMPT_SUBST

prompt_min_plus_setup "$@"

# Move vcs_info off the prompt's critical path: with `check-for-changes true`
# (set above) it shells out to check dirty/staged/untracked state on every
# precmd, which is cheap on a small repo but a real stall on a large one.
# Requires zsh-async (github.com/mafredri/zsh-async) already sourced by the
# consumer — this repo doesn't bundle it, matching how this file already
# expects vcs_info itself to come from zsh's own distribution. Falls back to
# the synchronous path (_update_vcs_info_sync, defined above, unchanged
# behavior) if the worker can't start for any reason, rather than silently
# losing the git segment.
if (( $+functions[async_start_worker] )); then
  # Forces vcs_info's autoload body to actually load in *this* process
  # before the fork below — the worker inherits function definitions as of
  # fork time, and an unresolved autoload stub forks as "command not found".
  vcs_info
  if async_start_worker min_plus_git -u -n 2>/dev/null; then
    async_register_callback min_plus_git _min_plus_async_callback
    _update_vcs_info() { _update_vcs_info_async }
  fi
fi
