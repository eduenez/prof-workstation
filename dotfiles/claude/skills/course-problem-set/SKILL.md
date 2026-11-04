---
name: course-problem-set
description: Draft the next homework problem set (ps<N>.md + instructor notes) for a current course in ~/repos/course-data. Use when asked to write, draft or plan a problem set / homework / assignment for MAT courses. Drafting only; releasing it to the site is the publish-problem-set skill.
---

# Draft a course problem set

Output: two files in `~/repos/course-data/terms/<term>/<course>/assignments/drafts/`:
`ps<N>.md` (the student sheet) and `ps<N>-instructor-notes.md`. Drafts live in
`drafts/` because `make assignments` only scans `assignments/*.md`, so a
routine publish cannot ship a sheet early. Never write a draft directly into
`assignments/`.

## Read first (they are authoritative and change; do not rely on memory)

1. `~/repos/course-data/CLAUDE.md` (hard rules), then `STATUS.md` (recent slips).
2. The course's `CLAUDE.md`, `course.yml`, `schedule.yml`, `texts.yml`, and
   `prep/<COURSE>-format-spec.md`.
3. The previous set and its instructor notes (`assignments/ps<N-1>*.md`): copy
   their header structure (due line, coverage sentence, page cap, completeness
   scoring, Sources paragraph, Notation block) exactly, updating only content.
4. The term's replan doc, if the course CLAUDE.md names one.

Current term = the newest directory under `terms/`. If the user didn't name the
course, ask which one.

## Design rules (instructor's standing decisions)

- **Coverage = one problem per meeting**, every lecture meeting since the
  previous set's due date up to (not past) this set's due date. Get the
  meetings from `schedule.yml`, not from the original plan: slips happen, and
  `STATUS.md` / the course CLAUDE.md record them. Q&A, exam and review meetings
  get no problem. A severable closing lecture named in CLAUDE.md is excluded.
- **Never state a problem count** anywhere (sheet, header, notes prose meant
  for students). Tell students to be ready on every problem.
- Six-page cap and the scoring wording come from the format spec; copy, don't
  paraphrase.
- **No SageMath item. No warnings against AI**: AI is permitted without
  restriction, and that wording must not be softened.
- Student-facing text says "Q&A", **never "defense"**.
- Pandoc Markdown + TeX math: `## Problem N (Title)` headings, parts `1.`,
  sub-parts `a.`. Raw LaTeX only in ```` ```{=latex} ```` blocks. Separate
  problems with `---`.
- Avoid examples that the Q&A-day enrichment activity uses (check
  `shared/activities/` and the course's `downloads/public/activities/`), the
  textbook's own worked examples, and anything already on an earlier set or in
  `~/repos/teaching/problem-bank/` (`make usage` there).
- Prefer problems with threads running through the set (a running example
  revisited from several angles), and say so in the notes.

## Instructor notes structure

Mirror the previous notes file: a DRAFT banner with today's date and the release
recipe; **Coverage map** table (Meeting | Topic | Reading | Problem);
**Threads**; **Avoided on purpose**; **Answer sketches** (`**N.**` heads, as
`bank.py import` parses them); **Q&A probes**; **Open flags** for the instructor.

## Verify before handing over

- Check every computation (numbers, counts, factorizations, gcds) by running
  code, e.g. `python3`, or `sage` if available. Write "Checked by machine." in
  the sketch only when you actually did.
- Build a preview PDF **outside the repo** to check it renders and fits six
  pages: run the Makefile's `PANDOC_PDF` command with `-o` pointing at the
  session scratchpad. Never into `downloads/`. Report the page count.
- Leave both files as drafts. Do not commit unless asked. Do not touch
  `_meta.yml`, `schedule.yml` or the site; that is publish-problem-set.

For student-facing prose that is more than boilerplate, the
`anthropic-skills:eduenez-voice` skill describes the instructor's style.
