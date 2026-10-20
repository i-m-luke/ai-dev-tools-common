import { it } from "vitest";
import { pesterSuite } from "./pester-executor/pester-suite.ts";

const suite = pesterSuite("repo-checks");

// The checks' own tests run first: a broken check cannot validate the skills, so the rest is skipped.
suite.prerequisite("skill-frontmatter/skill-frontmatter.Fixtures.Tests.ps1");
suite.prerequisite("skill-structure/skill-structure.Fixtures.Tests.ps1");

// One suite.test per check. Names are listed by hand so the VS Code Test Explorer shows them; the
// last test catches a file added or removed without updating this list.
suite.test("skill-frontmatter/skill-frontmatter.Tests.ps1");
suite.test("skill-structure/skill-structure.Tests.ps1");

it("repo check list matches the Pester files", suite.expectAllFilesDeclared);
