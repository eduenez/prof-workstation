---
name: psc-problem-set
description: Draft a new problem set (LaTeX sheet) for the UTSA Math Problem Solving Club in ~/repos/teaching/ProblemSolving/ProblemSetsPSC. Use when asked to write or plan a PSC / problem-solving club / Putnam-prep sheet or meeting. Drafting only; putting it on the club site is publish-problem-set.
---

# Draft a PS Club problem set

Sources live in `~/repos/teaching/ProblemSolving/ProblemSetsPSC/<Term>/<slug>.tex`
(for example `Fall2026/optimization.tex`). That private repo is the single source of truth.
The public site `~/repos/psclub` holds only built artifacts.

## Read first

1. `~/repos/psclub/CLAUDE.md`, the section "Conventions that are easy to violate".
2. The term's plan, if any (e.g. `Fall2026/rest-of-semester-plan.md`): the
   meeting date, topic and routes may already be decided there. It also holds the
   "Shared approach" pedagogy, which applies to every sheet.
3. The most recent sheet in the term folder. **Copy its preamble verbatim**:
   the `challenge` tcolorbox with the `\if\relax\detokenize{#3}\relax` guard,
   the burgundy `themecolor`, `fancyhdr` header, and the title block with the
   date, the site URL and any current QR/announcement. Change only the title,
   header text and date.
4. `~/repos/psclub/_data/sets.yml`: every published problem, so you don't repeat one.
   Also grep the other `.tex` files, including commented-out reserve problems.

## Format

- Two pages. Page 1 has about five accessible lead-ins that lead somewhere, with at
  least one satisfying stopping point. `\newpage`. Page 2 is a menu of three to five
  harder problems (Putnam A1/B1/A2/B2 level, rarely one A3/B3 stretch).
  Every page-2 problem has a page-1 lead-in. That gives a few "routes", but
  there is no printed hint ladder and no "Going Further" banner.
- Every problem is `\begin{challenge}{Title}{Topic / Difficulty}{Source}`.
  Field 2 is metadata; the site shows it as a hint layer.
- **Field 3 is a citation, not a characterization**: competition + year +
  number (`Putnam 2008 B3`) or author + publication + year. Otherwise it's `{}`.
  Never "Classic", "Folklore" or "Standard". Park any such label in a comment: `{} %{Folklore}`.
- **Solutions, hints, equality cases and teaching notes go in `%` comments**
  right after each box, never in printed text. (A `solution` environment is
  stripped at publish, but comments are the convention.)
- A leading `%` on a whole problem withholds it from the site. Use this for reserves.
- Each meeting must stand alone: you may reuse earlier ideas, but never require them.
- Extremum problems need attainability. Probability problems specify the
  sampling model explicitly.

## Verify

- Check every Putnam/competition statement against the original. Kedlaya's
  archive is `https://kskedlaya.org/putnam-archive/<year>.pdf`. Put the URL in a
  header comment. Paraphrases must keep the mathematics exact.
- Check answers in the comments by running code where possible.
- Compile in a **scratch directory**, never in the source tree:
  `latexmk -pdf -interaction=nonstopmode -halt-on-error -outdir=<scratchpad> <file>.tex`.
  Confirm it is two pages and that no solution text is printed.
- If the term has a plan document, update its table and add a meeting section.
- Do not commit unless asked, and do not touch `~/repos/psclub`.
