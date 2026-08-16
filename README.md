# afk-marc

Marc's AFK ticket loop. After grill → spec → tickets, this runs one `/implement` per iteration until the frontier is empty.

Not a skill. A host: fresh process, one ticket, out.

## Install into a project

```bash
curl -fsSL https://raw.githubusercontent.com/marcsoehn99/afk-marc/main/install.sh | bash
```

Writes `afk-tickets.sh` and `ralph-status.sh` into the current directory.

## Dayshift

1. `/grill-with-docs` → `/to-spec` → `/to-tickets`
2. Tickets live at `.scratch/<slug>/issues/`
3. Ask whether the loop may run:

   ```bash
   ./ralph-status.sh <slug>
   ```

   Exit 0 = GO. Exit 1 = nothing to do. Exit 2 = broken tree — do not loop.

4. Run the loop:

   ```bash
   ./afk-tickets.sh 20 <slug>
   ```

   Extra arguments after the slug go to `pi` (model, thinking, …):

   ```bash
   ./afk-tickets.sh 20 <slug> --model grok-4.6
   ./afk-tickets.sh 20 <slug> --model grok-4.6 --thinking high
   ```

   No extra flags = whatever `pi` uses by default.

5. Review in a **new** session: `/code-review`

The loop calls `pi`. That is the only CLI this repo has been run with.

## What the loop does

Each iteration picks the lowest-numbered `ready-for-agent` ticket whose blockers are `done`, runs `/implement` (TDD included), skips `/code-review`, sets `Status: done`, commits.

Stops when `$1` is reached **or** the agent prints `<promise>COMPLETE</promise>`.
