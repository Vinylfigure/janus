<!-- janus:ask:v1 -->
Ask: Close or re-spec the preflight change; its proof was the wrong proof
Because:
- The check refused a repository that was configured correctly, so the trial work order could not be sent.
- The change swaps that check for one a repository can pass while still being unable to open pull requests.
- The audit reserved this decision for the operator.
If-nothing: The trial work order stays unsent and the change stays parked.
Options: Close it | Re-spec it
Supersedes: none
Source-revision: 6d7c507
