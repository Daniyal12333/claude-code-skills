---
name: commit-message
description: >-
  Draft a git commit message in Conventional Commits style - `type(scope): subject`,
  dash bullets describing the change, and an optional `Ref: PROJ-123` footer taken
  from the branch name. Use this whenever the user asks for a commit message, says
  "commit msg", "write my commit", "message for these changes", "msg for what is
  staged", or asks you to summarize their current work for committing - even if they
  never mention a format. Also consult it before proposing a commit message on your
  own initiative, so a self-directed commit reads the same as a requested one.
---

# Commit Message

Produce one commit message that reads like it belongs in the repo's history, and hand
it to the user as text. They run `git commit` themselves.

## The shape

```
type(scope): imperative subject

- What changed, specifically
- Another change, naming the real method/key/component
- Add N keys to en/es/fr

Ref: PROJ-123
```

The subject line is what shows up in `git log --oneline`, so it carries the headline.
The bullets are for the person who runs `git show` six months later and needs to know
what actually moved without reading the diff.

**One bullet is one line.** Every bullet is a single physical line that fits under the
repo's `body-max-line-length`. No continuation lines - see [bullets](#deriving-each-field).

## Gather context first

Never guess at a diff. Read it:

```bash
git status --short              # what's staged vs unstaged vs untracked
git diff --staged               # the default subject of the message
git branch --show-current       # source of the ticket ID
git log -8 --no-merges --pretty=format:"%s"   # confirm the house style
cat commitlint.config.js .commitlintrc* 2>/dev/null   # the limits you must draft within
```

The last line is not optional. `header-max-length` and `body-max-line-length` are
project-specific - read them **before** drafting, not after a hook rejects the message.
See [Line length](#line-length).

If the staged diff is large, run `git diff --staged --stat` first to find the center of
gravity, then read the interesting files in full. A message assembled from filenames
alone reads generic and unhelpful - the value is in naming the behavior that changed.

**Which changes to describe:** default to staged only, since that is what a commit would
capture. If nothing is staged, don't stop - describe the unstaged (and untracked) work
and say plainly that nothing is staged yet. When the user asks for a message covering
"all uncommitted changes" or "everything I've changed", include unstaged and untracked
work too, and mention that they will need to stage it.

## Deriving each field

**type** - `feat` for new behavior, `fix` for corrected behavior, `docs` for
documentation, `refactor` when behavior is unchanged, `style` for pure visual or CSS
work, `test` for tests only, `chore` for build and tooling. Pick based on what the
change does for a user, not on how large the diff is: a one-line change that adds a
confirmation dialog is a `feat`. If `git log` shows the repo uses other types, use those.

**scope** - the feature or component the change lives in, kebab-case, matching the
folder name: `cart`, `order-history`, `user-settings`. Use a slash for a sub-area when
the parent alone would be misleading (`orders/notes`). Use `i18n` when the change is
cross-cutting translation work rather than one screen. If a change spans several
modules, pick the one a reader would search for first - usually where the primary
behavior changed, not where the supporting edits landed.

The ticket ID does **not** go in the scope. It goes in the footer, once.

**subject** - imperative mood, as if completing "this commit will ...": `align`,
`translate`, `confirm before`, `show`, `add`. Capitalize only proper nouns. No trailing
period.

Length is a hard constraint, not a preference: **check `header-max-length` before you
write the subject.** The count covers the whole header line - `type`, `(scope)`, the
colon and space, and the subject - so a long scope spends part of the budget. Treat the
configured limit as the ceiling; within that, don't amputate the meaning to hit a
number - a clear 85-character subject beats a cryptic 60. With no config present, keep
it under 72, the conventional default. If it doesn't fit, cut words and move the detail
into a bullet - the subject cannot be wrapped.

**bullets** - 3-6 dash bullets, each starting with a capital letter. Up to about 8 when
splitting a long one earns the extra.

**One bullet, one line, one change.** When a bullet doesn't fit, work in this order:

1. **Cut the *why*.** Most overlong bullets are one fact plus a clause explaining why it
   matters. The rationale belongs in a code comment, the ticket, or a design doc - a
   `git show` reader wants what moved.
2. **Split it into two bullets** if it holds two facts. A bullet that needs three lines
   to say one thing is usually describing two things wearing one dash.
3. **Shorten the wording** if it really is one atomic fact. Do *not* split an atomic
   fact: two half-sentences that only make sense together are worse than one terse bullet.

Splitting is always preferred over wrapping. The one-line rule is what makes the body
greppable: `git log --format=%b | grep` returns the line, and the line is the whole
claim. Past about 8 bullets the message is carrying detail that belongs in the ticket;
cut it rather than wrap it.

Be concrete: name the method (`validateCoupon`), the i18n key (`couponItemLimit`), the
component (`ConfirmDialogComponent`), the count (`Add 48 keys to en/es/fr`). Those
specifics make the history searchable later, and they survive shortening better than
prose does - drop the clause explaining the consequence before you drop the identifier.

Skip bullets for mechanical noise like import reordering. A single-line change can
justify one bullet, or none if the subject already says everything.

**footer** - `Ref: PROJ-123`, extracted from the branch name. A branch called
`SHOP-214-fix-coupon-limit` yields `Ref: SHOP-214`. Match a ticket as one or more
capital letters or digits, a hyphen, then digits (`[A-Z][A-Z0-9]+-[0-9]+`), anywhere in
the branch name - names can be prefixed (`feature/SHOP-214-...`), so don't anchor the
pattern to the start. If the branch carries no recognizable ticket ID, omit the footer
rather than inventing one, and ask the user for the ticket if the work looks
ticket-driven. If the repo's history uses a different footer (`Closes #12`,
`Refs: ...`), match that instead.

## Line length

Two rules do the rejecting: `header-max-length` caps the subject line,
`body-max-line-length` caps every body line. Both are usually enforced by a `commit-msg`
hook, so guessing either one costs a round-trip. **Read them before drafting:**

```bash
cat commitlint.config.js .commitlintrc* 2>/dev/null   # rules live here
grep -n "commitlint" package.json                     # or inline under a "commitlint" key
```

The numbers are project-specific and often raised above the defaults, so don't carry a
limit over from another repo. With no config present, keep the subject under 72 and
every bullet under 72 - the git defaults, and safe under anything stricter. That is a
tight budget for one line, so it forces short bullets rather than wrapped ones. Either
number is a ceiling, not a target; coming in well under costs nothing.

**The header.** The limit covers `type`, `(scope)`, the colon and space, and the
subject together:

```
x header must not be longer than 100 characters [header-max-length]
```

A header **cannot be wrapped**; a second line reparses as body. If it doesn't fit, cut
words and move the detail into a bullet.

**The body.** commitlint counts **physical lines**, not bullets, and the error names the
rule rather than the offending line:

```
x body's lines must not be longer than 100 characters [body-max-line-length]
```

**Shorten or split, never wrap.** A bullet that does not fit gets cut down or divided,
not reflowed:

```
- Cover PUBLIC_ROUTES in routes.test.ts: a missing public route, a leaked protected route, LOGIN_REDIRECT being reachable without a session, and no entry undeclared in ROUTES
```

That is 174 characters and four claims. Cut the rationale and keep the identifiers:

```
- Cover PUBLIC_ROUTES: missing public route, leaked protected route
```

Or, when the halves are genuinely separate changes, split rather than compress:

```
- Cover PUBLIC_ROUTES: missing public route, leaked protected route
- Assert LOGIN_REDIRECT is public and no ROUTES entry is undeclared
```

Two things that break this silently:

- **Trailing whitespace.** A bullet under the limit on screen can fail because of spaces
  pasted after the last word. Strip trailing whitespace from every line.
- **The editor round-trip.** If the user is recovering from a rejected `commit-msg` hook
  and asks you to run the commit, write the message to a file and use
  `git commit -F <file>` rather than reproducing it through `-m` or an editor buffer,
  then confirm the lengths first:

  ```bash
  # substitute the repo's own two limits for 100 and 120
  awk 'NR==1 && length($0)>100 { printf "header: %d chars\n", length($0) }
       NR>1  && length($0)>120 { printf "%d: %d chars - shorten it\n", NR, length($0) }
       NR>2  && /^[ \t]/       { printf "%d: continuation line - one bullet, one line\n", NR }
       /[ \t]$/                { printf "%d: trailing whitespace\n", NR }' <file>
  ```

  Worth running on the draft even when you are not committing - it is the only way to be
  sure of a length rather than to estimate one. This does not loosen the draft-only rule
  below. Run `git commit` only when the user has asked for it in that request.

## Mixed diffs

When the staged changes span more than one concern, still write **one** message. Lead
with the main feature or fix - the reason the work was done - and let the supporting
changes become bullets underneath it. Don't propose splitting the commit, and don't hedge
the subject to cover everything equally; a subject that tries to name three unrelated
things names none of them well.

## Two standing rules

**Draft only.** Output the message in a fenced block ready to copy. Don't run
`git commit`, don't stage anything, don't amend. Many people keep that step for
themselves on purpose, so offering to commit "to save a step" is unwelcome. (Change this
rule if you want Claude to commit for you.)

**No co-author trailer by default.** Leave out `Co-Authored-By: Claude ...` so the commit
is stylistically indistinguishable from the rest of the history. Add the trailer only
when the user explicitly asks for it in that request.

## Examples

These are invented, for a fictional shop app. Match the quality bar, not the content.

**A bug fix with a translated user-facing string:**

```
fix(cart): align coupon error message with the 10-item limit

- Reject coupons on carts over 10 items with a 10-item error
- Use translate.instant('couponItemLimit') in validateCoupon
- Add couponItemLimit translations for en, fr, and es

Ref: SHOP-214
```

**A feature that reuses existing pieces:**

```
feat(order-history): confirm before cancelling an order

- Add a ConfirmDialogComponent step before CancelOrderService.cancel
- Show a translated "Order cancelled" snackbar on success
- Reuse the existing orderCancelled i18n key

Ref: SHOP-231
```

**A wide cleanup** - here the bullets carry real weight, because the subject can't:

```
refactor(i18n): consolidate checkout translations into global files

- Delete checkout/i18n, whose values overrode the global translations
- Remove loadTranslations() from the 6 components that called it
- Repoint templates to global keys (payKey -> paymentKey)
- Add 48 keys to en/es/fr global files

Ref: SHOP-240
```

## Edge cases

- **Merge and revert commits** - leave git's generated message alone; it is already
  conventional.
- **Nothing to describe** - if the working tree is clean, say so instead of producing a
  plausible-sounding message for changes that don't exist.
- **A repo with a different style** - read `git log` first and match what is there. The
  useful part of this skill is the method, not the exact `type(scope)` and `Ref:` shape.
