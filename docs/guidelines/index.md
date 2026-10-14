# Guidelines

Conventions for writing the shipped skills in [`skills/`](../../skills).

## Workflow skills

A workflow skill — one that walks the agent through ordered steps — puts those steps under a
`## Steps` chapter, so the sequence stands apart from the reference it consults. Each step is a
chapter of its own, `### N. <action>`, named by what the agent does. Reference used by a single
step, such as a playbook, lives inside that step; reference shared by several steps gets a chapter
beside `Steps`.
