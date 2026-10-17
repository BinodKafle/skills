# Skills for software engineers

Agent skills for real engineering work, built for Claude Code. Other tools may load them without their Claude
Code-only safety rails (frontmatter hooks).

## Install

```bash
claude plugin marketplace add BinodKafle/skills
claude plugin install binodkafle-skills@binodkafle
```

Then run `/binodkafle-skills:break-this-pr`. Or copy a skill folder into `~/.claude/skills/` and run
`/break-this-pr`.

## Skills

### Engineering

**User-invoked** (run only when you type them):

- [break-this-pr](./skills/engineering/break-this-pr/SKILL.md): adversarial PR review that runs every claim, attacks
  every changed line and gives a gated merge verdict. [Details](./skills/engineering/break-this-pr/README.md)

**Model-invoked** (Claude uses them when relevant): none yet.

### In progress

[Drafts](./skills/in-progress/README.md), not in the plugin.

## License

[MIT](./LICENSE)
