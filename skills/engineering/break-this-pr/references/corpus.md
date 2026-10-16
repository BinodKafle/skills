# Building the test corpus

## Real data first
Before generating anything, run the repo's own fixtures and sample data, and any real exports the domain has, on
both trees. Generated data adds axes; it never replaces real files.

## Structural axes
Build axes from the **structure of the input**, not from past bugs or the PR's theme:

| Axis | Values to cross |
|---|---|
| Position | before the payload (preamble, title, comments), inside it (stray values, blank rows), after it (footers, totals, trailing notes) |
| Field | each field position: first, middle, last, missing, extra |
| Layer | every encoding, format, quoting, escaping, line-ending and locale layer the input passes through |
| Size | empty, one, two, typical, large |
| Values | the real-world value kinds the domain carries (ids, amounts, dates, codes, free text, lists inside fields) |
| Vintage | data produced before the change, data produced after |

Name each fixture after the artifact it mimics (an ERP export, a survey tool, a spreadsheet save-as).

## Ground truth by construction
Generate each input together with its correct answer. The answer never comes from running the code under test.
Inputs whose correct answer is genuinely ambiguous get crash and consistency checks only, and are counted
separately.

## Enumerate or sample
- Up to about 10,000 cells: enumerate the full cross product.
- Above that: stratified sampling across every axis. State the sample size and the strata.

## Score against the base
For every cell, record pass or fail on the base and on the head. Report:
- regressions (passes on base, fails on head): each is a finding;
- improvements;
- cells that fail on both: pre-existing, or ambiguous.

## Generator inventory
List what the generator **cannot** produce: missing axis values and missing combinations. Every "no regressions
over N" claim is limited to what the generator can produce. A shape outside the inventory is uncovered, not safe.
