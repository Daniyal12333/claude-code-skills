#!/usr/bin/env bash
# who-changed.sh - attribute lines of a file to commit, author, ticket, branch and PR.
#
# Usage:
#   who-changed.sh <file>                  whole-file mode: contributors + last 12 commits
#   who-changed.sh <file> <line>           one line
#   who-changed.sh <file> <start> <end>    line-range mode: per-commit line ownership
#   append "raw" to any form               blame without -w -C -M (byte-level truth)
#
# Environment (all optional):
#   WHO_CHANGED_BASE           ref that PR lookup walks toward (default: auto-detected)
#   WHO_CHANGED_TICKET_REGEX   ticket pattern, ERE (default: [A-Z][A-Z0-9]+-[0-9]+)
#
# Read-only: it never writes to the repo and never touches the network.
# Output is a tab-separated report meant to be reformatted for a human.
set -u

die() { echo "who-changed: $*" >&2; exit 1; }
usage() { sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }

# ---------------------------------------------------------------- arguments
[ $# -ge 1 ] || usage
file=$1
shift
raw=0
nums=()
for a in "$@"; do
  case "$a" in
    raw) raw=1 ;;
    ''|*[!0-9]*) echo "who-changed: unrecognised argument: $a" >&2; usage ;;
    *) nums+=("$a") ;;
  esac
done
start=""; end=""
case ${#nums[@]} in
  0) ;;
  1) start=${nums[0]}; end=${nums[0]} ;;
  2) start=${nums[0]}; end=${nums[1]} ;;
  *) usage ;;
esac
if [ -n "$start" ] && [ "$start" -gt "$end" ]; then
  t=$start; start=$end; end=$t
fi

# ------------------------------------------------------------- repo checks
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not inside a git repository"
[ -f "$file" ] || die "file not found: $file"
git ls-files --error-unmatch -- "$file" >/dev/null 2>&1 || die "file is not tracked by git: $file"

TICKET_RE=${WHO_CHANGED_TICKET_REGEX:-'[A-Z][A-Z0-9]+-[0-9]+'}
# Prefixes that look like tickets but are not (UTF-8, SHA-256, ...)
NOT_TICKET='^(UTF|ISO|SHA|MD|AES|RSA|TLS|SSL|HTTP|ES|X)-'

# -------------------------------------------------------------------- base
detect_base() {
  local r
  r=$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null)
  if [ -n "$r" ] && git rev-parse --verify -q "$r" >/dev/null 2>&1; then echo "$r"; return; fi
  for r in origin/main origin/master main master; do
    if git rev-parse --verify -q "$r" >/dev/null 2>&1; then echo "$r"; return; fi
  done
  echo HEAD
}
BASE=${WHO_CHANGED_BASE:-$(detect_base)}
git rev-parse --verify -q "$BASE" >/dev/null 2>&1 || die "base ref not found: $BASE"
FIRST_PARENT=$(git rev-list --first-parent "$BASE" 2>/dev/null)

# --------------------------------------------------------------- web links
remote_web() {
  local u h proto rest
  u=$(git remote get-url origin 2>/dev/null) || { echo "-"; return; }
  [ -n "$u" ] || { echo "-"; return; }
  u=${u%.git}
  case "$u" in
    git@*:*)   h=${u#git@}; u="https://${h/:/\/}" ;;
    ssh://*)   rest=${u#ssh://}; rest=${rest#*@}; u="https://$rest" ;;
    http://*|https://*)
               proto=${u%%://*}; rest=${u#*://}; rest=${rest#*@}; u="$proto://$rest" ;;
    *)         echo "-"; return ;;
  esac
  echo "$u"
}
WEB=$(remote_web)
case "$WEB" in
  *bitbucket.org*) HOST=bitbucket ;;
  *github.com*)    HOST=github ;;
  *gitlab*)        HOST=gitlab ;;
  -)               HOST=none ;;
  *)               HOST=other ;;
esac

commit_url() {
  case "$HOST" in
    bitbucket) echo "$WEB/commits/$1" ;;
    github)    echo "$WEB/commit/$1" ;;
    gitlab)    echo "$WEB/-/commit/$1" ;;
    *)         echo "-" ;;
  esac
}
pr_url() {
  [ "$1" = "-" ] && { echo "-"; return; }
  case "$HOST" in
    bitbucket) echo "$WEB/pull-requests/$1" ;;
    github)    echo "$WEB/pull/$1" ;;
    gitlab)    echo "$WEB/-/merge_requests/$1" ;;
    *)         echo "-" ;;
  esac
}

# ------------------------------------------------------- per-commit lookup
extract_ticket() {
  printf '%s\n' "$1" | grep -oE "$TICKET_RE" | grep -vE "$NOT_TICKET" | head -1
}

# Sets R_TICKET R_BRANCH R_PR R_CONF for a commit.
re_bb='^Merged in (.+) \(pull request #([0-9]+)\)'
re_gh='^Merge pull request #([0-9]+) from ([^ ]+)'
re_sq='\(#([0-9]+)\)$'
resolve() {
  local sha=$1 msg subj ticket branch="-" pr="-" conf="ok" h s found=0 bt
  msg=$(git log -1 --format=%B "$sha" 2>/dev/null)
  subj=$(git log -1 --format=%s "$sha" 2>/dev/null)
  ticket=$(extract_ticket "$msg")

  if ! git merge-base --is-ancestor "$sha" "$BASE" 2>/dev/null; then
    local branches n cur
    branches=$(git branch --contains "$sha" --format='%(refname:short)' 2>/dev/null)
    n=$(printf '%s\n' "$branches" | grep -c .)
    cur=$(git branch --show-current 2>/dev/null)
    if [ "$n" -eq 1 ]; then
      branch=$branches
      [ -n "$ticket" ] || ticket=$(extract_ticket "$branch")   # only one branch holds it
    elif [ "$n" -gt 1 ]; then
      if printf '%s\n' "$branches" | grep -qx "$cur"; then branch=$cur; else branch=$(printf '%s\n' "$branches" | head -1); fi
    fi
    R_TICKET=${ticket:--}; R_BRANCH=$branch; R_PR="-"; R_CONF="local-only"
    return
  fi

  # A commit made directly on the base's first-parent chain was not carried by any PR merge.
  # Otherwise, find the first mainline merge whose side branch contains it (and the base side does not).
  if ! printf '%s\n' "$FIRST_PARENT" | grep -qx "$sha"; then
    while IFS='|' read -r h s; do
      git merge-base --is-ancestor "$sha" "$h^2" 2>/dev/null || continue
      git merge-base --is-ancestor "$sha" "$h^1" 2>/dev/null && continue
      if [[ $s =~ $re_bb ]]; then
        branch=${BASH_REMATCH[1]}; pr=${BASH_REMATCH[2]}; found=1; break
      elif [[ $s =~ $re_gh ]]; then
        pr=${BASH_REMATCH[1]}; branch=${BASH_REMATCH[2]}; branch=${branch#*/}; found=1; break
      fi
    done < <(git log --merges --first-parent --ancestry-path --reverse --format='%H|%s' "$sha..$BASE" 2>/dev/null)
  fi

  if [ "$found" -eq 0 ] && [[ $subj =~ $re_sq ]]; then
    pr=${BASH_REMATCH[1]}; found=2   # squash-merge: PR number lives in the subject
  fi

  if [ "$found" -eq 0 ]; then
    if [ -z "$ticket" ]; then conf="low-no-ticket"; else conf="no-pr-merge"; fi
  elif [ "$found" -eq 2 ]; then
    conf="squash"
  else
    bt=$(extract_ticket "$branch")
    if [ -z "$bt" ]; then
      conf="low-integration-branch"
    elif [ -z "$ticket" ]; then
      ticket=$bt
    fi
  fi
  R_TICKET=${ticket:--}; R_BRANCH=$branch; R_PR=$pr; R_CONF=$conf
}

print_commit_row() { # $1=lines  $2=sha
  local sha=$2 author date subj short
  short=$(git rev-parse --short "$sha")
  author=$(git log -1 --format=%an "$sha")
  date=$(git log -1 --date=short --format=%ad "$sha")
  subj=$(git log -1 --format=%s "$sha")
  resolve "$sha"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$1" "$author" "$short" "$date" "$R_TICKET" "$R_BRANCH" "$R_PR" "$R_CONF" \
    "$(commit_url "$sha")" "$(pr_url "$R_PR")" "$subj"
}

# --------------------------------------------------------------------- run
dirty=no
[ -n "$(git status --porcelain -- "$file" 2>/dev/null)" ] && dirty=yes
base_tip_date=$(git log -1 --date=short --format=%ad "$BASE" 2>/dev/null)

printf '## meta\n'
printf 'file\t%s\n' "$file"
if [ -n "$start" ]; then printf 'mode\trange\nrange\t%s-%s\n' "$start" "$end"; else printf 'mode\tfile\n'; fi
printf 'blame\t%s\n' "$([ "$raw" -eq 1 ] && echo raw || echo "smart (-w -C -M)")"
printf 'base\t%s\n' "$BASE"
printf 'base_tip_date\t%s\n' "$base_tip_date"
printf 'web\t%s\nhost\t%s\n' "$WEB" "$HOST"
printf 'dirty\t%s\n' "$dirty"

HEAD_ROW='lines\tauthor\tcommit\tdate\tticket\tbranch\tpr\tconfidence\tcommit_url\tpr_url\tsubject'

if [ -n "$start" ]; then
  # ---- line-range mode
  bargs=(--line-porcelain)
  [ "$raw" -eq 0 ] && bargs+=(-w -C -M)
  bargs+=(-L "$start,$end")
  blame_out=$(git blame "${bargs[@]}" -- "$file" 2>&1) || die "git blame failed: $blame_out"

  counts=$(printf '%s\n' "$blame_out" | awk '
    length($1)==40 && $1 ~ /^[0-9a-f]+$/ && NF>=3 && $2 ~ /^[0-9]+$/ { c[$1]++ }
    END { for (s in c) printf "%d\t%s\n", c[s], s }' | sort -rn -k1,1)
  total=$(printf '%s\n' "$counts" | awk -F'\t' '{ t += $1 } END { print t+0 }')
  printf 'total_lines\t%s\n' "$total"

  printf '\n## commits\n'
  printf "$HEAD_ROW\n"
  zero=0000000000000000000000000000000000000000
  printf '%s\n' "$counts" | while IFS=$'\t' read -r n sha; do
    [ -n "$sha" ] || continue
    if [ "$sha" = "$zero" ]; then
      printf '%s\tNot Committed Yet\t-\t-\t-\t-\t-\tuncommitted\t-\t-\t(uncommitted edits)\n' "$n"
    else
      print_commit_row "$n" "$sha"
    fi
  done
else
  # ---- whole-file mode
  printf '\n## contributors\n'
  printf 'commits\tauthor\n'
  git shortlog -sn HEAD -- "$file" 2>/dev/null | sed -E 's/^[[:space:]]*([0-9]+)[[:space:]]+/\1\t/'

  printf '\n## commits\n'
  printf "$HEAD_ROW\n"
  git log --follow -12 --format=%H -- "$file" 2>/dev/null | while read -r sha; do
    [ -n "$sha" ] || continue
    print_commit_row "-" "$sha"
  done
fi
