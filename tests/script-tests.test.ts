import { describe, it } from "vitest";
import { pesterSuite } from "./pester-executor/pester-suite.ts";

const suite = pesterSuite("script-tests");

// One suite.test per file in tests/script-tests/. Names are listed by hand so the VS Code Test
// Explorer shows them; the last test catches a file added or removed without updating this list.
// One describe per skill folder, so the Test Explorer can run a single skill's tests.
describe("document-app", () => {
  suite.test("document-app/convert-icon.Tests.ps1");
  suite.test("document-app/update-toc.Tests.ps1");
});

describe("manage-github-issues", () => {
  suite.test("manage-github-issues/add-assignee.Tests.ps1");
  suite.test("manage-github-issues/add-blocker.Tests.ps1");
  suite.test("manage-github-issues/add-comment.Tests.ps1");
  suite.test("manage-github-issues/add-sub-issue.Tests.ps1");
  suite.test("manage-github-issues/check-prerequisites.Tests.ps1");
  suite.test("manage-github-issues/close-item.Tests.ps1");
  suite.test("manage-github-issues/get-external-prs.Tests.ps1");
  suite.test("manage-github-issues/get-issues.Tests.ps1");
  suite.test("manage-github-issues/get-item.Tests.ps1");
  suite.test("manage-github-issues/get-ready-sub-issues.Tests.ps1");
  suite.test("manage-github-issues/github-client.Tests.ps1");
  suite.test("manage-github-issues/new-issue.Tests.ps1");
  suite.test("manage-github-issues/set-labels.Tests.ps1");
  suite.test("manage-github-issues/update-issue.Tests.ps1");
});

describe("notify", () => {
  suite.test("notify/notify.Tests.ps1");
});

describe("win-app-spy", () => {
  suite.test("win-app-spy/act.Tests.ps1");
  suite.test("win-app-spy/attach.Tests.ps1");
  suite.test("win-app-spy/check-prerequisites.Tests.ps1");
  suite.test("win-app-spy/dump-tree.Tests.ps1");
  suite.test("win-app-spy/flaui-basics.Tests.ps1");
  suite.test("win-app-spy/get-state.Tests.ps1");
  suite.test("win-app-spy/screenshot.Tests.ps1");
  suite.test("win-app-spy/spy.Tests.ps1");
  suite.test("win-app-spy/wait.Tests.ps1");
});

it("script test list matches the Pester files", suite.expectAllFilesDeclared);
