# In-progress

[`in-progress/`](../in-progress) holds agent tools that are still being developed and are not part of
the plugin: [`in-progress/skills/`](../in-progress/skills) mirrors [`skills/`](../skills) for unfinished
skills.

- Their evals live in [`evals/in-progress/`](../evals/in-progress) and run separately from the production
  ones: `./tools/evals.ps1 -InProgress` (see [Evals](verification/evals.md)).
- The script tests check their frontmatter like that of the shipped skills.
- To ship a skill, move its folder to `skills/` and its eval to `evals/`, and point the eval's
  `skill_directories` back at `../../skills`.
