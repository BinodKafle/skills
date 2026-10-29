# Severity

By impact on users and data, not by kind of code.

- **Blocker:** wrong results, lost or corrupted data, a security hole, or a crash on a supported input. E.g. a valid
  file loads with the wrong column count and no warning.
- **Major:** a regression on a realistic input, a misleading user-facing fact, or a broken integration. E.g. a
  message says "3 rows removed" when 5 were; users act on messages.
- **Minor:** a coverage gap, a rare edge case that fails safely, or a defect reachable only by misuse.
- **Nit:** style, naming or wording with no behaviour effect.

## Gating
The verdict rules are in SKILL.md §8. Two notes on applying them:
- Pre-existing majors become follow-ups unless the change makes them worse.
- Minors and nits never block.
