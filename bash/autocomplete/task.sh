_taskfile_completions() {
  local cur tasks
  cur=${COMP_WORDS[COMP_CWORD]}

  # extract function names but exclude those starting with underscore
  tasks=$(grep -E '^function [a-zA-Z][^ ]+ *\{|^[a-zA-Z][^ ]+\(\) *\{' ./Taskfile |
    sed -E 's/^function //; s/\(\) *\{//; s/ *\{//' |
    grep -v '^_')

  # generate completions
  COMPREPLY=($(compgen -W "$tasks" -- "$cur"))
}

# Register the completion function
complete -F _taskfile_completions task
