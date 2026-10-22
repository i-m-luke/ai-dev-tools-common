## Scripts

Print a script's help with `{{help-command}}` and read it before you run the script for the first time. Read the script's source only when the help leaves out what you need, and then tell the user which part the help left out.

The exit code alone decides whether a script succeeded:

- On `0`, when the help says the script returns a result, take the compact JSON after `::result::` on the one stdout line that starts with it; every other stdout line is log. When that line is missing or appears more than once, tell the user the script broke its contract and stop.
- On any other exit code, ignore stdout; the error is on stderr.
