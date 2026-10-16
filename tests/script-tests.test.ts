import { it } from 'vitest';
import { expectAllPesterFilesDeclared, pesterTest } from './script-tests-executor/pester-test.ts';

// One pesterTest per file in tests/script-tests/. Names are listed by hand so the VS Code Test
// Explorer shows them; the last test catches a file added or removed without updating this list.
pesterTest('notify/notify.Tests.ps1');
pesterTest('win-app-spy/act.Tests.ps1');
pesterTest('win-app-spy/attach.Tests.ps1');
pesterTest('win-app-spy/dump-tree.Tests.ps1');
pesterTest('win-app-spy/flaui-basics.Tests.ps1');
pesterTest('win-app-spy/get-state.Tests.ps1');
pesterTest('win-app-spy/preflight.Tests.ps1');
pesterTest('win-app-spy/screenshot.Tests.ps1');
pesterTest('win-app-spy/wait.Tests.ps1');
pesterTest('win-app-spy/win-app-spy.Tests.ps1');

it('pesterTest list matches the Pester files', expectAllPesterFilesDeclared);
