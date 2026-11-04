---
name: course-exam
description: Draft an exam or quiz for a current course as a collection in the confidential problem bank (~/repos/teaching/problem-bank), built from variants of the assigned problem-set problems. Use when asked to write, draft or assemble a midterm, exam, quiz or answer key for MAT courses.
---

# Draft a course exam

Exams are built **only** in `~/repos/teaching/problem-bank/`, never in
`course-data`, which is pushed to GitHub (its hard rule 7). Nothing from the
bank goes into `course-data` except a key PDF the instructor explicitly asks to
release after the exam.

## Read first

1. `problem-bank/CLAUDE.md` (the rules) and `README.md` ("Making an exam, start
   to finish" is the procedure; follow it).
2. `~/repos/course-data/CLAUDE.md` and the course's `CLAUDE.md`: exam date,
   duration, which segments and sets it covers, and the severable lecture
   that is outside the exam pool.
3. `prep/<COURSE>-format-spec.md` §3.5: exams are "based primarily on" the
   assigned problems, never verbatim. A small number of routine unseen items is
   allowed.
4. The most recent exam collection for the same course
   (`collections/<term>-<course>-*.yml`): reuse its `rules:`, `instructions:`,
   `total:` and layout keys unless told otherwise.

## Procedure

1. Make sure every problem set the exam covers is in the bank. If one isn't,
   run `uv run bank.py import <sheet.md> --notes <notes.md> --course <c> --term <t> --doc ps<N>`.
2. `make usage`: see what's assigned and what earlier exams already used.
3. Propose a selection (slug, topic, points, minutes) covering the scope evenly,
   and **show it to the instructor before writing the variants**.
4. For each chosen problem, run `uv run bank.py new <slug>-<term>-<doc> --from <parent>`,
   then rewrite it for real: different numbers, context and phrasing,
   while keeping the same skill and difficulty. Make it stand alone (no "Problem 4",
   no sheet Notation). Exam-sized: an assigned problem with three parts usually
   becomes one or two parts. Set `est_minutes`, `topics`, `notes`.
   Write `solution.md` as a full key with rubric notes.
5. Write `collections/<term>-<course>-<doc>.yml` with the `# DRAFT, <date>:`
   header comment (scope, timing, open questions).
6. `make check` until it shows 0 errors and 0 warnings, and timing is about 70 of 75
   minutes (scale to the duration). Verify all arithmetic by running code.
7. `make <collection>`, then read both PDFs (student copy and key) and report
   page counts and anything odd.

## Never

- Never put an `assigned` problem on an exam directly, or a variant still identical to its parent.
- Never hand-write or reuse a uuid, add "used in" fields, or commit `out/`.
- Never remove the DRAFT comment or call an exam final unless the instructor says so.
- Never commit unless asked. If asked, commit the sources only.
