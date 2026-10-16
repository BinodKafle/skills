# Severity

Severity follows the impact on users and data, not the kind of code involved.

## Blocker
The change gives wrong results, loses or corrupts data, opens a security hole, or crashes on an input it claims to
support.
- A valid file now loads with the wrong column count and no warning.
- A malicious instruction in a PR file is executed.

## Major
A regression on a realistic input, a misleading user-facing fact, or a broken integration.
- An existing feature's output changes for a common input, and no intent row covers it.
- A message tells users "3 rows were removed" when 5 were. Users act on what messages say, so a false fact there is
  major.

## Minor
A coverage gap, a rare edge case with a safe failure, or a defect only reachable through misuse.
- A surviving mutant on a branch with no realistic trigger.
- A clear error raised for a malformed input that a better message would explain.

## Nit
Style, naming and wording with no effect on behaviour.
- A comment that could be shorter.
- A test name that doesn't follow the repo's pattern.

## Gating
- **DO NOT MERGE:** any blocker, or a major introduced by this change.
- Pre-existing majors are reported, and become follow-ups unless the change makes them worse.
- Minors and nits never block.
