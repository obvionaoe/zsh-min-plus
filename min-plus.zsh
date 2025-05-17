# Load async library (adjust path if needed)
if [[ -z ${functions[async_start_worker]} ]]; then
  # You must have zsh-async installed somewhere; adjust this path accordingly
  source ~/.zsh/plugins/zsh-async/async.zsh 2>/dev/null || echo "Warning: zsh-async not found!"
fi

# Start async worker for git prompt
async_start_worker gitprompt 2>/dev/null

# --- Shorten path: keep 3 letters per dir ---
shorten_path() {
  local keep=3
  local dir="${PWD/#$HOME/~}"
  local IFS='/' parts=(${(s:/:)dir})
  local out=""
  local i

  for (( i = 1; i < ${#parts[@]} - 1; i++ )); do
    [[ -n ${parts[i]} ]] && out+="${parts[i]:0:$keep}/"
  done

  out+="${parts[-1]}"
  echo "$out"
}

# --- Get AWS profile ---
get_aws_profile() {
  [[ -n $AWS_PROFILE ]] && echo "$AWS_PROFILE"
}

# --- Get GCP profile ---
get_gcp_profile() {
  local profile
  profile=$(gcloud config get-value account 2>/dev/null)
  [[ -n $profile && $profile != "unset" ]] && echo "$profile"
}

# --- Get Kubernetes context and namespace ---
get_k8s_info() {
  local context ns
  context=$(kubectl config current-context 2>/dev/null)
  [[ -z $context ]] && return
  ns=$(kubectl config view --minify --output 'jsonpath={..namespace}' 2>/dev/null)
  ns=${ns:-default}
  echo "$context/$ns"
}

# --- Async Git prompt function ---
__async_git_prompt() {
  local branch symbols status
  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo ""
    return
  fi

  branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null || git describe --tags --exact-match 2>/dev/null || echo "(detached)")

  status=$(git status --porcelain 2>/dev/null)
  local staged=0 dirty=0 untracked=0 line

  while read -r line; do
    [[ -z $line ]] && continue
    case "$line" in
      '??'*) ((untracked++)) ;;
      [MARC]?) ((staged++)) ;;
      ?[MARC]) ((dirty++)) ;;
      *) ((dirty++)) ;;
    esac
  done <<< "$status"

  local symbols=""
  ((staged))    && symbols+="+"
  ((dirty))     && symbols+="!"
  ((untracked)) && symbols+="?"

  [[ -n $branch ]] && echo " $branch$symbols"  #  Nerd Font branch icon (alternative to )
}

# --- Set GIT_PROMPT variable async ---
__set_git_prompt() {
  GIT_PROMPT="$1"
}

# --- Update git prompt async ---
update_git_prompt() {
  async_job gitprompt __async_git_prompt __set_git_prompt
}

# --- Exit code indicator ---
exit_code_prompt() {
  [[ $? -eq 0 ]] && echo "" || echo "%{$fg[red]%}✘ %?%{$reset_color%}"
}

# --- Compose right prompt ---
compose_rprompt() {
  local parts=()

  [[ -n $GIT_PROMPT ]] && parts+=("%{$fg[yellow]%}${GIT_PROMPT}%{$reset_color%}")

  local k8s
  k8s=$(get_k8s_info)
  [[ -n $k8s ]] && parts+=("%{$fg[cyan]%}⎈ ${k8s}%{$reset_color%}")

  local aws
  aws=$(get_aws_profile)
  [[ -n $aws ]] && parts+=("%{$fg[magenta]%} ${aws}%{$reset_color%}")

  local gcp
  gcp=$(get_gcp_profile)
  [[ -n $gcp ]] && parts+=("%{$fg[blue]%} ${gcp}%{$reset_color%}")

  if (( ${#parts[@]} )); then
    echo "[ ${(j:|:)parts} ]"
  else
    echo ""
  fi
}

# --- Main prompt setup ---
PROMPT_COLOR=cyan
[[ $UID -eq 0 ]] && PROMPT_COLOR=red

PROMPT="%{$fg[$PROMPT_COLOR]%}$(shorten_path) $(exit_code_prompt) %{$reset_color%}%(!.#.>) "
RPROMPT="$(compose_rprompt)"

# --- Hooks ---
autoload -Uz add-zsh-hook
add-zsh-hook precmd update_git_prompt
