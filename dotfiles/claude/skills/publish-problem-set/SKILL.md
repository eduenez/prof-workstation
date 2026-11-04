---
name: publish-problem-set
description: Release a drafted problem set to its website — a course set from course-data/assignments/drafts onto the `courses` site, or a PS Club .tex sheet onto the `psclub` site. Use when asked to publish, release, deploy, wire in or put a problem set on the site.
---

# Publish a problem set

Find out which site it's for. Course sets go to `~/repos/courses` and are generated from
`course-data`. PS Club sets go to `~/repos/psclub`. Publishing is outward-facing:
**stop before `git push`** and show the instructor the diff and the build
result, unless they already said to push.

## A. Course set → `courses`

The site is generated. Never hand-edit `~/repos/courses` (course-data hard rule 2).

1. Check `ps<N>.md` and `ps<N>-instructor-notes.md` exist in
   `terms/<term>/<course>/assignments/drafts/`, and that the notes' open flags
   are resolved. If not, ask.
2. `git mv` both files up into `assignments/`. The notes are never built, because the
   Makefile filters out `*-instructor-notes.md`. Update the notes' DRAFT banner
   to say "released <date>".
3. Add a `ps<N>.pdf` entry to `downloads/public/assignments/_meta.yml`,
   matching the previous entries: `name: "Problem Set N"` and a `note:` reading "due <Day D Month> — <topics>".
4. Do **not** edit `schedule.yml` links. A row with `due: Problem Set N`
   links itself once the PDF exists (hard rule 9). Just confirm the due row says
   exactly that.
5. In `~/repos/course-data`: `make publish`. This builds the PDF, validates, runs the leak
   check and regenerates `../courses`. Report the page count of the built PDF
   (six-page cap).
6. Commit in `course-data` (sources + `_meta.yml` + built PDF), then in
   `~/repos/courses` review `git status`/`git diff --stat` and commit. Push
   both only on the instructor's go-ahead.

## B. PS Club set → `psclub`

Follow the "Adding a problem set" section in `~/repos/psclub/CLAUDE.md`. In outline:

1. Add the set to `SETS` in `bin/extract-problems.py`, newest first, with slug,
   `source="<Term>/<file>.tex"`, title, term, `date="YYYY-MM-DD"` (meeting
   date) and a two- or three-sentence `blurb`. Add the same `slug:source` pair to
   `SETS` in `bin/sync-sets.sh`. The two lists must agree.
2. `python3 bin/extract-problems.py`, then `./bin/sync-sets.sh <slug>`.
3. Create `problems/<slug>.md` by copying the newest stub (`layout: set`,
   `slug`, `title`, `permalink: /problems/<slug>/`, `description` = blurb).
4. Run the checks, using CI's Ruby:
   `./bin/check-pii.sh` and
   `RBENV_VERSION=3.3.12 PATH="$HOME/.rbenv/shims:$PATH" ./bin/check-build.sh`.
   If it reports changed published/withheld/authored counts, update the
   numbers in `CLAUDE.md` as it says.
5. Check the PDF in `assets/sets/<slug>.pdf` prints no solutions.
6. Commit (message style: "Add the <D Month> <topic> set"). On go-ahead, push,
   then run `gh run list --workflow=build.yml` and confirm the **deploy** job is green, not
   just build.

If several drafted sheets are waiting, release only the ones the instructor
names; if unclear, ask rather than publishing future meetings early.
