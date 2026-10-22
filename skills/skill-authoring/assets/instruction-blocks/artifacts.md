## Artifacts

Write the files this skill produces for its own work or for the user to its artifacts folder: `.artifacts/{{skill}}/` in the workspace root, or `{{skill}}/` in the system's temporary folder when there is no workspace. It holds:

- `<yyyyMMdd-HHmmss>/` — the output of one run of the skill, e.g. reports, previews, state files; one folder per run. Take its path from the script that creates it, or create it yourself when no script does.
- `.temp/` — the input of a script's `<Noun>Path` parameter: write it to `.temp/<noun>-<seed>.<ext>`, where `<seed>` is 6 letters and digits that differ from every seed used in this conversation and name no existing file, then pass that path.

Files that belong in the user's repository, such as documentation, go where the steps say.
