---
name: who-changed
description: >-
  Attribute code to the person, ticket, branch and pull request that produced it,
  using only local git history. Reports author name, commit hash, ticket number,
  branch name and date, plus commit and PR links. Use this whenever the user asks who
  wrote, changed, added, touched or owns some code - "who changed this", "who wrote
  this function", "who worked on this file last", "who is the author of this feature",
  "which ticket added this", "which PR introduced this", "when was this added", "git
  blame this", "blame these lines" - whether they name a file, a line range, or a
  function. Also use it before attributing code to someone in passing, so the name
  comes from history rather than from a guess.
---

# Who Changed

Answer "who built this, under which ticket, and when" without leaving the terminal.
Everything needed is already in local git history. The only thing the code host adds is
the PR narrative, and the output hands over a link for that.

It replaces a manual loop: open the file, find the feature, open the blame view, copy a
hash, paste it into the code host, click through to the PR, read off the ticket and
author.

## What the user gets

Author name, commit hash, ticket number, branch name, date, PR number, and clickable
commit and PR links. One lead verdict for the range, then a table of every commit that
touched it.

## Run the script

```bash
bash ~/.claude/skills/who-changed/scripts/who-changed.sh <file> [start end] [raw]
```

If the skill is installed per project, the path is
`.claude/skills/who-changed/scripts/who-changed.sh` instead.

- `<file>` alone: whole-file mode. Top contributors plus the last 12 commits.
- `<file> <start> <end>` (or one line number): line-range mode. Per-commit line ownership.
- append `raw`: blame without `-w -C -M`, for when the user wants byte-level truth.

Environment overrides: `WHO_CHANGED_BASE` sets the ref that PR lookup walks toward
(default: `origin/HEAD`, then `origin/main`, `origin/master`, `main`, `master`);
`WHO_CHANGED_TICKET_REGEX` changes the ticket pattern (default `[A-Z][A-Z0-9]+-[0-9]+`).

The script prints a tab-separated report and never writes to the repo or the network.
Reformat it for the user - do not paste the raw TSV.

## Step 1: resolve the target to a line range

The script takes numbers, so a function name has to be turned into a range first. Git's
`-L :functionName:` shortcut depends on a language-specific function pattern, and for
many languages (TypeScript class members in particular) it fails with `no match`.
Resolve the range yourself:

1. Grep for the declaration, for example
   `^\s*(public|private|protected)?\s*(async\s+)?<name>\s*[(<]`, and
   `<name>\s*[:=]\s*(function|\()` for arrow-function properties. For HTML or CSS, grep
   the literal selector, key or block.
2. Read from that line and brace-match from the first `{` to find the closing line.
3. **If the name matches in more than one place, list the matches and ask which one.**
   Never silently pick the first - common names often exist in several files.

Line numbers come from the working tree, so they line up with what the user sees in
their editor.

Given an explicit range (`285-300`, `285`, `L285-L300`) use it as-is. Given only a file
path, use whole-file mode.

## Step 2: read the output

The `## meta` block carries `base` (the ref the PR lookup walks toward),
`base_tip_date`, `web` and `host` (link base, derived from `git remote`), the blame
mode, and whether the file has uncommitted changes.

Rows in `## commits` are sorted by lines owned. **The verdict is the first row** - the
commit owning most of the range. Mention the runner-up when the range is genuinely
shared; a function built by four people across three years should not be reported as
belonging to one.

The script already builds `commit_url` and `pr_url` for Bitbucket, GitHub and GitLab
remotes. When they are `-`, there is no recognizable remote - say so and omit links
rather than inventing a host.

Present it like this (the names below are invented):

```
### calculateTotal - src/cart/cart.service.ts:42-61

**Alice Moreno** · `a1b2c3d` · 2023-02-08 · owns 13 of 20 lines
Ticket SHOP-88 · branch `SHOP-88-cart-totals` · PR #41

| Lines | Author | Commit | Date | Ticket | Branch | PR |
|---|---|---|---|---|---|---|
| 13 | Alice Moreno | a1b2c3d | 2023-02-08 | SHOP-88 | SHOP-88-cart-totals | #41 |
| 6 | Ben Carter | 9f8e7d6 | 2026-03-11 | SHOP-310 | SHOP-310-rounding-fix | not merged |
| 1 | Chen Wei | 4c5d6e7 | 2024-06-20 | — | release-2024-06 | #112 |
```

Then the links, then a caveat line whenever a confidence flag fired.

## Confidence labels, and what to say about each

| Label | Meaning | Tell the user |
|---|---|---|
| `ok` | Ticket branch merged via a PR | Nothing needed |
| `local-only` | Commit is not on `base` yet | "Not merged to the base branch yet" - there is no PR |
| `no-pr-merge` | On the mainline, but no PR merge carries it | Committed straight to the mainline, or the merge subject broke convention |
| `squash` | PR number read from a `(#123)` suffix | Squash-merged, so per-line history inside that PR is flattened |
| `low-no-ticket` | No ticket in the message or the branch | **State that no ticket was recorded.** Do not guess one |
| `low-integration-branch` | Merged via a branch with no ticket in its name | The PR is where the integration branch landed, *not* where the code was written. Low confidence |
| `uncommitted` | `Not Committed Yet` | Local uncommitted edits; excluded from the verdict |

Older code often arrives through long-lived integration branches (`develop`,
`release-*`, `ui-dev`). For those the honest answer is "merged to the mainline via
PR #112, but that PR is an integration branch - it is not the PR this was written in."

## Why `-w -C -M` is the default

`-w` ignores whitespace, `-M` follows lines moved within the file, `-C` follows lines
copied in from another file. This is not cosmetic. Take a block that was written in 2023
and only re-indented in 2026 (illustrative numbers):

- smart (`-w -C -M`): 9 of 9 lines go to the original author, 2023 - correct
- raw: 8 of 9 lines go to the person who re-indented, 2026 - credits them with old code

So the named author is the last person to change *behavior*, not the last to touch
bytes. Say so when it matters, and offer `raw` as a follow-up.

## Honesty rules

- **Never invent a ticket ID.** No ticket in the commit message or the branch: report
  `—` and say no ticket was recorded.
- **Never invent an author.** If blame is inconclusive, say which commits are candidates.
- **Distinguish "merged via" from "authored in"** whenever a low-confidence flag fires.
- If `base_tip_date` looks stale, note that the base ref has not been fetched recently
  and recent merges may be missed. Suggest `git fetch origin` - do not run it unasked.

## Limits worth stating when relevant

- **The "why" is not in git.** PR description, reviewers and ticket title need the code
  host's or tracker's API and credentials. The PR link is the handoff point.
- **Squash merges flatten history.** If a PR was squashed, one commit owns the whole
  feature and per-line attribution inside it is gone.
- **`--ancestry-path` picks the first merge** that carried the commit to the mainline.
  With nested feature branches that can be an intermediate merge, not the ticket's own PR.
- **Whole-file contributors do not follow renames.** `git shortlog` has no `--follow`;
  the commit list does follow renames, the contributor tally does not.
- **`-C` occasionally surprises** by attributing copy-pasted code to the file it came from.
- **PR detection recognizes three merge-message styles:** Bitbucket
  (`Merged in <branch> (pull request #N)`), GitHub (`Merge pull request #N from ...`),
  and squash (`... (#N)`). Other styles fall through to `no-pr-merge`.

## Fallback if the script is unavailable

```bash
git blame -w -C -M -L <start>,<end> --date=short -- <file>
git log -1 --date=short --pretty=format:"%H%n%an%n%ad%n%s%n%b" <sha>
git merge-base --is-ancestor <sha> origin/main     # not an ancestor -> unmerged
git log --merges --ancestry-path --reverse --pretty=format:"%h|%s" <sha>..origin/main | grep -m1 "pull request"
git branch --contains <sha>                        # unmerged case
```

Parse the merge subject for the branch and PR number. Two traps: `git shortlog` needs an
explicit `HEAD` or it silently reads stdin and returns nothing, and branch names may be
prefixed (`feature/SHOP-88-...`), so do not anchor the ticket regex to the start of the
string.
