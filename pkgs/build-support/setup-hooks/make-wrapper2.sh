# Assert that FILE exists and is executable
#
# assertExecutable FILE
assertExecutable() {
  local file="$1"
  [[ -f "$file" && -x "$file" ]] || \
    die "Cannot wrap ${file@Q} because it is not an executable file"
}

# construct an executable file that wraps the actual executable
# makeWrapper EXECUTABLE OUT_PATH ARGS

# ARGS:
# --argv0        NAME    : set the name of the executed process to NAME
#                          (if unset or empty, defaults to EXECUTABLE)
# --inherit-argv0        : the executable inherits argv0 from the wrapper.
#                          (use instead of --argv0 '$0')
# --resolve-argv0        : if argv0 doesn't include a / character, resolve it against PATH
# --set          VAR VAL : add VAR with value VAL to the executable's environment
# --set-default  VAR VAL : like --set, but only adds VAR if not already set in
#                          the environment
# --unset        VAR     : remove VAR from the environment
# --chdir        DIR     : change working directory (use instead of --run "cd DIR")
# --run          COMMAND : run command before the executable
# --add-flag     ARG     : prepend the single argument ARG to the invocation of the executable
#                          (that is, *before* any arguments passed on the command line)
# --append-flag  ARG     : append the single argument ARG to the invocation of the executable
#                          (that is, *after* any arguments passed on the command line)
# --add-flags    ARGS    : prepend ARGS verbatim to the Bash-interpreted invocation of the executable
# --append-flags ARGS    : append ARGS verbatim to the Bash-interpreted invocation of the executable

# --prefix          ENV SEP VAL   : suffix/prefix ENV with VAL, separated by SEP
# --suffix
# --prefix-each     ENV SEP VALS  : like --prefix, but VALS is a list
# --suffix-each     ENV SEP VALS  : like --suffix, but VALS is a list
# --prefix-contents ENV SEP FILES : like --suffix-each, but contents of FILES
#                                   are read first and used as VALS
# --suffix-contents
makeWrapper() { makeShellWrapper "$@"; }
makeShellWrapper() {
  local original="$1"
  local wrapper="$2"
  local params varName value command separator n fileNames
  local argv0 flagsBefore flagsAfter flags

  assertExecutable "$original"

  # Write wrapper code which adds `value` to the beginning or end of
  # the list variable named by `varName`, depending on the `mode`
  # specified.
  #
  # A value which is already part of the list will not be added
  # again. If this is the case and the `suffix` mode is used, the
  # list won't be touched at all. The `prefix` mode will however
  # move the last matching instance of the value to the beginning
  # of the list. Any remaining duplicates of the value will be left
  # as-is.
  addValue() (
    local mode="$1"       # `prefix` or `suffix` to add to the beginning or end respectively
    local varName="$2"    # name of list variable to add to
    local separator="$3"  # character used to separate elements of list
    local value="$4"      # one value, or multiple values separated by `separator`, to add to list

    # Disable file globbing, since bash will otherwise try to find
    # filenames matching the the value to be prefixed/suffixed if
    # it contains characters considered wildcards, such as `?` and
    # `*`. We want the value as is, except we also want to split
    # it on on the separator; hence we can't quote it.
    set -o noglob

    if [[ -n "$value" ]]; then
      IFS=$separator

      if [[ "$mode" == '--prefix'* ]]; then
        # Keep the order of the components as written when
        # prefixing; normally, they would be added in the
        # reverse order.
        local tmp=
        for v in $value; do
          tmp=$v${tmp:+$separator}$tmp
        done
        value="$tmp"
      fi
      for v in $value; do
        # Add separators on both ends unless the variable is empty.
        printf '%s="${%s:+%q"$%s"%q}"\n' "$varName" "$varName" "$separator" "$varName" "$separator"
        if [[ "$mode" == '--prefix'* ]]; then
          # In prefix mode, remove the first instance of the value
          # (if any) from the variable, then prepend the value.
          printf '%s="${%s/%q%q%q/%q}"\n' "$varName" "$varName" "$separator" "$v" "$separator" "$separator"
          printf '%s=%q"$%s"\n' "$varName" "$v" "$varName"
        elif [[ "$mode" == '--suffix'* ]]; then
          # In suffix mode, add the value to the list if and only if
          # it isn't already in the list.
          printf 'if [[ "$%s" != *%q%q%q* ]]; then\n' "$varName" "$separator" "$v" "$separator"
          printf '    %s="$%s"%q\n' "$varName" "$varName" "$v"
          printf 'fi\n'
        else
          echo "unknown mode $mode!" 1>&2
          exit 1
        fi
        # Remove any separators at the start and end, and export the variable.
        printf '%s="${%s#%q}"\n' "$varName" "$varName" "$separator"
        printf '%s="${%s%%%q}"\n' "$varName" "$varName" "$separator"
        printf 'export %s\n' "$varName"
      done >>"$wrapper"
    fi
  )

  if [[ "$wrapper" = */* ]]; then
    mkdir -p -- "${wrapper%/*}"
  fi

  # TODO Drop the >"$wrapper" nonsense by changing stdout to the wrapper then
  # changing it back when finished.
  echo "#! @shell@ -e" > "$wrapper"

  params=("$@")
  for ((n = 2; n < ${#params[*]}; n += 1)); do
    p="${params[$n]}"

    case "$p" in
      --set)
        varName="${params[$((n + 1))]}"
        value="${params[$((n + 2))]}"
        n=$((n + 2))
        printf 'export %s=%q\n' "$varName" "$value" >>"$wrapper"
      ;;
      --set-default)
        varName="${params[$((n + 1))]}"
        value="${params[$((n + 2))]}"
        n=$((n + 2))
        printf 'export %s="${%s-%q}"\n' "$varName" "$varName" "$value" >>"$wrapper"
      ;;
      --unset)
        varName="${params[$((n + 1))]}"
        n=$((n + 1))
        printf 'unset %s\n' "$varName" >>"$wrapper"
      ;;
      --chdir)
        dir="${params[$((n + 1))]}"
        n=$((n + 1))
        printf 'cd -- %q\n' "$dir" >>"$wrapper"
      ;;
      --run)
        command="${params[$((n + 1))]}"
        n=$((n + 1))
        printf '%s\n' "$command" >>"$wrapper"
      ;;
      --suffix|--prefix)
        varName="${params[$((n + 1))]}"
        separator="${params[$((n + 2))]}"
        value="${params[$((n + 3))]}"
        n=$((n + 3))
        addValue "$p" "$varName" "$separator" "$value"
      ;;
      --suffix-each|--prefix-each)
        varName="${params[$((n + 1))]}"
        separator="${params[$((n + 2))]}"
        values="${params[$((n + 3))]}"
        n=$((n + 3))
        for value in $values; do
          addValue "$p" "$varName" "$separator" "$value"
        done
      ;;
      --suffix-contents|--prefix-contents)
        varName="${params[$((n + 1))]}"
        separator="${params[$((n + 2))]}"
        fileNames="${params[$((n + 3))]}"
        n=$((n + 3))
        for fileName in $fileNames; do
          contents="$(cat "$fileName")"
          addValue "$p" "$varName" "$separator" "$contents"
        done
      ;;
      --add-flag)
        flags=${params[n + 1]@Q}
        n=$((n + 1))
        flagsBefore="${flagsBefore-} $flags"
      ;;
      --append-flag)
        flags=${params[n + 1]@Q}
        n=$((n + 1))
        flagsAfter="${flagsAfter-} $flags"
      ;;
      --add-flags)
        flags="${params[$((n + 1))]}"
        n=$((n + 1))
        flagsBefore="${flagsBefore-} $flags"
      ;;
      --append-flags)
        flags="${params[$((n + 1))]}"
        n=$((n + 1))
        flagsAfter="${flagsAfter-} $flags"
      ;;
      --argv0)
        argv0="${params[$((n + 1))]}"
        n=$((n + 1))
      ;;
      --inherit-argv0)
        # Whichever comes last of --argv0 and --inherit-argv0 wins
        argv0='$0'
      ;;
      --resolve-argv0)
        # this is noop in shell wrappers, since bash will always resolve $0
        resolve_argv0=1
      ;;
      *)
        die "makeWrapper doesn't understand the arg $p"
      ;;
    esac
  done

  printf 'exec ' >>"$wrapper"
  [[ -v argv0 && "$argv0" ]] && printf -- '-a %q ' "$argv0" >>"$wrapper"
  printf -- '-- %q ' "$original" >>"$wrapper"
  [[ -v flagsBefore ]] && printf '%s ' "$flagsBefore" >>"$wrapper"
  printf '"$@"' >>"$wrapper"
  [[ -v flagsAfter ]] && printf ' %s' "$flagsAfter" >>"$wrapper"
  printf '\n' >>"$wrapper"

  chmod +x -- "$wrapper"
}

# Syntax: wrapProgram <PROGRAM> <MAKE-WRAPPER FLAGS...>
wrapProgram() { wrapProgramShell "$@"; }
wrapProgramShell() {
  local prog="$1"
  local hidden

  assertExecutable "$prog"

  if [[ "$prog" = */* ]]; then
    hidden="${prog%/*}/.${prog##*/}-wrapped"
  else
    hidden=".${prog}-wrapped"
  fi

  while [[ -e "$hidden" ]]; do
    hidden="${hidden}_"
  done
  mv -- "$prog" "$hidden"
  makeShellWrapper "$hidden" "$prog" --inherit-argv0 "${@:2}"
}
