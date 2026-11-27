# Personal instructions for Claude Code (all projects, all machines)

Deployed from `prof-workstation/dotfiles/claude/CLAUDE.md` as a symlink at `~/.claude/CLAUDE.md`; edit it there and commit.

## Where research material lives

- **Feedback on other people's work** (comments on colleagues' preprints, referee reports, grant-panel notes, comments on
  students' drafts) goes in `~/repos/research/reviews/` (private repository), one directory per item named
  `YYYY-MM-<authors>-<short>/`, with `comments.md` (sent to the authors) and an optional `notes.md` (private). Conventions are in
  `reviews/README.md`: pin the exact version read (commit hash, arXiv vN, or date), general comments first, anchor specific comments
  by page + section heading + a short verbatim quote, math in LaTeX. Not `~/synchro`, and not a new repository.
- **Version-pinned file references** in any notes (Markdown or Org) use one format: link text `OWNER/REPO@<short-sha>:<path>`,
  target `https://github.com/OWNER/REPO/blob/<full-sha>/<path>[#L10-L20]` (never a branch), then `(blob <short-hash>)`, or
  `(lines 10–20; blob …)` for a range. Spec: `research/reviews/README.md`. The user makes, updates and follows them from Emacs with
  `my-gitpin` (`elisp/my-lisp/my-gitpin.el`); when writing one by hand, get the hashes from git (`git rev-parse`), never guess them.
