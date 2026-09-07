# Weekly child learning

Monday 09:47 UTC runs `.github/workflows/weekly-learning.yml`. This is a separate
GitHub Actions driver; the ordinary Janus work-loop stays paused. No Routine
reconfiguration is needed. Merging the workflow installs its schedule.

The configured source roster is `.github/learning-sources.json`. An existing
User-owned `FLEET_TOKEN` needs child content read and Janus content/issues/PR read
and write, so an issue-triggered Claude session can start. Missing capability is
reported as unavailable; it is not treated as an empty fleet or silently widened.
If that credential is absent, the exact external setup is to configure that
secret with those repository scopes, then run weekly-learning manually and
verify its recorded pulse. No credential is changed by this implementation.

The deterministic pipeline harvests portable observations, deduplicates copied
origins across children and firings, claims one improvement using a GitHub ref
compare-and-swap, and files one bounded implementation task. Existing tasks/PRs
are resumed first. It records the create intent before calling GitHub and finds
an existing operation after an interrupted response; an ambiguous absence holds
instead of creating duplicate work. Source text is explicitly untrusted evidence.
The implementation session must reproduce the problem and verify the fix; it
never receives authority from a learning entry. The existing shared effect policy
controls delivery. Only authority or product choices become human decisions.

A merged carrier PR plus a green named hook-tests check on its merge revision
completes the tracked implementation. The runtime is `runtime/weekly-learning`,
with the state at `weekly/state.json`. A separate execution pulse follows the
Harness resource contract at `runtime/execution-pulse/<resource hash>/state.json`.
Unavailable sources are partial coverage; no candidate with complete coverage is
healthy empty. Empty firings emit no reporting issue, comment, or PR.

Generic recalibrate remains candidate-only. This approved weekly pipeline owns
implementation; it does not widen recalibrate or consume the ordinary backlog.
