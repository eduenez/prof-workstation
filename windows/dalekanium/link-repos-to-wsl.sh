#!/usr/bin/env bash
# windows/dalekanium/link-repos-to-wsl.sh — make WSL's clones the only copy of most repositories.
# Each top-level entry of M:\Eduardo\repos is replaced by a directory symlink to the same name under
# \\wsl.localhost\<distro>\home\eduardo\repos, EXCEPT the repositories that hold machine-specific state
# and stay as separate Windows clones (KEEP).  The Windows copy is moved to M:\Eduardo\repos-windows-old\
# (nothing is deleted).  Run from Git Bash (Developer Mode on, so mklink needs no admin):
#   bash link-repos-to-wsl.sh            dry run: what would happen to each entry, and why
#   bash link-repos-to-wsl.sh --apply
# An entry is LEFT ALONE when: it is in KEEP; it is already a link; WSL has no clone of that name; or the
# Windows copy has uncommitted changes, unpushed commits or stashes (push/commit them first and re-run).
# Untracked and git-ignored files (build output, *~ ...) exist only in the Windows copy: they are counted,
# stay in repos-windows-old, and can be copied over by hand if any matter.
# Settings (environment): KEEP="<names>" (default below)  OLD=/m/Eduardo/repos-windows-old  WSL_DISTRO=Ubuntu-26.04
#   WSL_USER=eduardo
set -u
# No global MSYS_NO_PATHCONV: git.exe is a Windows program and must get Windows paths (W below);
# only the cmd.exe/mklink call disables Git Bash's path conversion, for its /D switch.
APPLY=false; [[ ${1:-} == --apply ]] && APPLY=true
# Separate Windows clones: machine-specific state (elisp: Elpaca builds; prof-workstation: kanata config and the
# Restic scripts the Windows tasks run; site-tools: the Windows `repos` tool; prettify-LaTeX-mode: built by
# Windows Emacs from the local repo), and filetree-reorg, kept duplicate for now.
KEEP=${KEEP:-"elisp prof-workstation site-tools prettify-LaTeX-mode filetree-reorg"}
DISTRO=${WSL_DISTRO:-Ubuntu-26.04}; WUSER=${WSL_USER:-eduardo}
SRC=/m/Eduardo/repos; OLD=${OLD:-/m/Eduardo/repos-windows-old}     # where the replaced Windows copies go
WSL_WIN="\\\\wsl.localhost\\$DISTRO\\home\\$WUSER\\repos"      # \\wsl.localhost\Ubuntu-26.04\home\eduardo\repos
WSL_POSIX="//wsl.localhost/$DISTRO/home/$WUSER/repos"
$APPLY || echo "DRY RUN (nothing changes; --apply to do it)"
ls "$WSL_POSIX" >/dev/null 2>&1 || { echo "cannot reach $WSL_WIN (is WSL installed and the distro named $DISTRO?)" >&2; exit 1; }
n_link=0; n_skip=0
for d in "$SRC"/*/; do
    name=$(basename "$d"); d=${d%/}
    if [[ " $KEEP " == *" $name "* ]]; then printf '  %-28s keep       separate Windows clone\n' "$name"; continue; fi
    if [[ -L $d ]]; then printf '  %-28s link       already -> %s\n' "$name" "$(readlink "$d")"; continue; fi
    if [[ ! -e $WSL_POSIX/$name ]]; then printf '  %-28s SKIP       no %s in WSL (clone it there first)\n' "$name" "$name"; n_skip=$((n_skip+1)); continue; fi
    why="" local_only=0
    if [[ -d $d/.git ]]; then
        W=$(cygpath -m "$d")                     # M:/Eduardo/repos/<name>, what git.exe understands
        # core.fsmonitor=false: with fsmonitor on (git config --global core.fsmonitor true), every
        # `git status` starts a resident fsmonitor daemon (a git.exe per repository) that keeps the
        # folder open, and Windows then refuses to move it ("Permission denied").
        g() { git -c core.fsmonitor=false -C "$W" "$@" 2>/dev/null; }
        # a failing git (e.g. "dubious ownership") must not look like a clean repository
        if ! err=$(git -c core.fsmonitor=false -C "$W" status --porcelain 2>&1 >/dev/null) || [[ -n $err ]]; then
            printf '  %-28s SKIP       git status failed: %s\n' "$name" "$(head -1 <<<"$err")"; n_skip=$((n_skip+1)); continue
        fi
        changed=$(g status --porcelain --untracked-files=no | wc -l)
        unpushed=$(g log --oneline --branches --not --remotes | wc -l)
        stashes=$(g stash list | wc -l)
        (( changed ))  && why+="$changed uncommitted, "
        (( unpushed )) && why+="$unpushed unpushed commit(s), "
        (( stashes ))  && why+="$stashes stash(es), "
        local_only=$(g status --porcelain --ignored --untracked-files=all | grep -c '^\(??\|!!\)')
    else
        why="not a git repository, "        # e.g. a folder of several repositories: handle by hand
    fi
    if [[ -n $why ]]; then printf '  %-28s SKIP       %s\n' "$name" "${why%, }"; n_skip=$((n_skip+1)); continue; fi
    note=""; (( local_only )) && note="  ($local_only untracked/ignored file(s) stay in repos-windows-old)"
    printf '  %-28s %-10s -> %s\\%s%s\n' "$name" "$($APPLY && echo LINKED || echo would-link)" "$WSL_WIN" "$name" "$note"
    if $APPLY; then
        mkdir -p "$OLD"
        [[ -e $OLD/$name ]] && { echo "    !! $OLD/$name exists already; skipped"; n_skip=$((n_skip+1)); continue; }
        [[ -d $d/.git ]] && git -C "$(cygpath -m "$d")" fsmonitor--daemon stop >/dev/null 2>&1   # one left from earlier git use
        mv -- "$d" "$OLD/$name" || { echo "    !! could not move $d (open in a program?)"; n_skip=$((n_skip+1)); continue; }
        if ! MSYS_NO_PATHCONV=1 cmd.exe /d /c mklink /D "M:\\Eduardo\\repos\\$name" "$WSL_WIN\\$name" >/dev/null; then
            echo "    !! mklink failed; moving the Windows copy back"; mv -- "$OLD/$name" "$d"; n_skip=$((n_skip+1)); continue
        fi
    fi
    n_link=$((n_link+1))
done
echo; echo "$n_link $($APPLY && echo linked || echo to link), $n_skip left alone (see SKIP lines)"
$APPLY && echo "Windows copies: $(cygpath -w "$OLD") (delete when you are sure nothing there is missing)"
exit 0
