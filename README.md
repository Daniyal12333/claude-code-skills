# claude-code-skills

A collection of practical [Claude Code](https://docs.claude.com/en/docs/claude-code)
skills. Each skill is a self-contained folder with a `SKILL.md` that teaches Claude a
repeatable procedure. Copy the ones you want into your skills folder.

## Skills

| Skill | What it does |
|---|---|
| [`commit-message`](commit-message/SKILL.md) | Drafts a Conventional Commits message (`type(scope): subject`, one-line bullets, `Ref:` footer from the branch name) that respects your commitlint limits. Draft only - it never commits. |
| [`who-changed`](who-changed/SKILL.md) | Answers "who wrote this, under which ticket, in which PR?" for a file, line range, or function, using only local git history. Includes a read-only helper script. |

More skills will be added over time.

## Highlights

- **commit-message** reads your `commitlint` config before drafting, so the message
  doesn't bounce off a `commit-msg` hook.
- **who-changed** uses `git blame -w -C -M`, so a re-indented block is credited to the
  person who wrote it, and every answer carries a confidence label instead of a guess.

## Requirements

- [Claude Code](https://docs.claude.com/en/docs/claude-code)
- `git` and `bash` (on Windows, use Git Bash)

## Install

Copy the skill folder you want into your skills directory.

Personal install (every project):

```bash
git clone https://github.com/Daniyal12333/claude-code-skills.git
mkdir -p ~/.claude/skills
cp -r claude-code-skills/<skill-name> ~/.claude/skills/
```

Project install (shared with a team through the repo):

```bash
mkdir -p .claude/skills
cp -r path/to/claude-code-skills/<skill-name> .claude/skills/
```

Restart Claude Code so it picks the skill up.

## Use

Just ask in plain language:

```text
write a commit message for what is staged
who wrote the calculateTotal function in src/cart/cart.service.ts?
which PR introduced lines 40-60 of src/app/app.component.ts?
```

You can also call a skill by name with `/commit-message` or `/who-changed`.

## Customize

- **Ticket format.** Both skills assume tickets look like `ABC-123`. For `who-changed`,
  set `WHO_CHANGED_TICKET_REGEX` to change the pattern. For `commit-message`, edit the
  footer section of its `SKILL.md`.
- **Base branch.** `who-changed` detects `origin/HEAD`, `main`, or `master`. Override with
  `WHO_CHANGED_BASE=origin/develop`.
- **Let Claude commit.** `commit-message` is draft-only by default. Edit the "Draft only"
  rule in its `SKILL.md` if you want otherwise.

## Notes and limits

- `who-changed` recognizes Bitbucket, GitHub, and squash-merge subjects. Other merge
  styles fall back to `no-pr-merge`.
- The "why" behind a change (PR description, reviewers) is not in git; the script gives
  you the PR link for that.
- The examples in both skills are invented.

## License

[MIT](LICENSE)
