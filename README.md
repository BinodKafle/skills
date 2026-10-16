# Skills for software engineers

Agent skills I use for real engineering work. Each one is a folder with a `SKILL.md` and the reference files it
loads on demand.

Claude Code is the supported tool. Some skills rely on Claude Code features (frontmatter hooks, forked context), so
other tools may load them without their safety rails.

## Install

As a Claude Code plugin, which updates when you update the marketplace:

```bash
claude plugin marketplace add BinodKafle/skills
claude plugin install binodkafle-skills@binodkafle
```

Inside a session, the same is `/plugin marketplace add BinodKafle/skills`, then
`/plugin install binodkafle-skills@binodkafle`. Plugin skills are namespaced, e.g.
`/binodkafle-skills:break-this-pr`.

Or copy a single skill folder into `~/.claude/skills/` (it then runs as `/break-this-pr`).

## Skills

### Engineering

**User-invoked** (run only when you type them):

- [break-this-pr](./skills/engineering/break-this-pr/SKILL.md): adversarial senior-engineer PR review. It
  verifies every claim by running it, tries to break every changed line with real-world edge data, and gives a
  gated merge verdict. [Details](./skills/engineering/break-this-pr/README.md)

**Model-invoked** (Claude may use them when relevant): none yet.

### In progress

Drafts live in [skills/in-progress](./skills/in-progress/README.md). They're public, but not part of the plugin.

## License

[MIT](./LICENSE)
