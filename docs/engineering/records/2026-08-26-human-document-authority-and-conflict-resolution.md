# Human document authority and conflict resolution

Human-owned documents:

- `docs/human/requirements/20260826-Engineering-Human Document Authority And Conflict Resolution.md`

## Why

The interaction rules already said `docs/human/` outranks AI-maintained
documents, proposals, comments and code names. They said nothing about the two
conflicts that actually stall work: a human-owned document that disagrees with
itself, and two human-owned documents that disagree with each other. With no
rule, the AI would have to guess which reading applies, and a guess about a
requirement is the one place guessing is most expensive.

The owner's answer separates the two cases. A document at odds with itself is
the owner's to resolve, so the AI stops and reports. Documents at odds with each
other usually mean the requirement moved, so the later document wins by default —
requirements change often, and the newer one is the current intent.

## What changed

Three rules added to `## 11. AI Assistant Interaction Rules` in
`docs/engineering/02_git_workflow.md`, next to the existing conflict rule:
`docs/human/` is the highest-priority rule source; an intra-document
contradiction stops the work and is reported; an inter-document disagreement with
no stated precedence resolves to the more recently modified document.

No existing rule was removed or reworded. No changelog entry: this is an
engineering process rule, not milestone or user-visible behavior.

## Verification

Documentation only, so verification is a read of the amended section. The three
new bullets sit inside section 11, after the existing `docs/human/` conflict
bullet and before the ambiguity bullet, and do not contradict either.

## Open point for the owner

The requirement says the more recent `修改日期` decides but does not define how
that date is read. The file name carries a creation date that does not move when
the requirement is later edited, so it cannot serve. The rule as written says
"more recently modified"; pinning it to the document's last Git commit time
would make it mechanical. That choice is the owner's and needs a requirement
update before the rule states it.
