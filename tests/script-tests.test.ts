import { it } from "vitest";
import { expectAllPesterFilesDeclared, pesterTest } from "./script-tests-executor/pester-test.ts";

// One pesterTest per file in tests/script-tests/. Names are listed by hand so the VS Code Test
// Explorer shows them; the last test catches a file added or removed without updating this list.
pesterTest("manage-github-issues/add-assignee.Tests.ps1");
pesterTest("manage-github-issues/add-blocker.Tests.ps1");
pesterTest("manage-github-issues/add-comment.Tests.ps1");
pesterTest("manage-github-issues/add-sub-issue.Tests.ps1");
pesterTest("manage-github-issues/check-prerequisites.Tests.ps1");
pesterTest("manage-github-issues/close-item.Tests.ps1");
pesterTest("manage-github-issues/get-external-prs.Tests.ps1");
pesterTest("manage-github-issues/get-issues.Tests.ps1");
pesterTest("manage-github-issues/get-item.Tests.ps1");
pesterTest("manage-github-issues/get-ready-sub-issues.Tests.ps1");
pesterTest("manage-github-issues/github-client.Tests.ps1");
pesterTest("manage-github-issues/new-issue.Tests.ps1");
pesterTest("manage-github-issues/set-labels.Tests.ps1");
pesterTest("manage-github-issues/update-issue.Tests.ps1");
pesterTest("notify/notify.Tests.ps1");
pesterTest("win-app-spy/act.Tests.ps1");
pesterTest("win-app-spy/attach.Tests.ps1");
pesterTest("win-app-spy/dump-tree.Tests.ps1");
pesterTest("win-app-spy/flaui-basics.Tests.ps1");
pesterTest("win-app-spy/get-state.Tests.ps1");
pesterTest("win-app-spy/preflight.Tests.ps1");
pesterTest("win-app-spy/screenshot.Tests.ps1");
pesterTest("win-app-spy/wait.Tests.ps1");
pesterTest("win-app-spy/win-app-spy.Tests.ps1");

it("script test list matches the Pester files", expectAllPesterFilesDeclared);
