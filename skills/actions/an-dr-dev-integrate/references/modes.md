# Local modes

Used only when the request path in [pull-request.md](pull-request.md) is unavailable. `Request` and `RebaseMerge` remain in the scripts for a user who asks for them by name; they are not offered.


| Mode          | What it does                                                                                                                                                | Choose it when                                                                                    |
| ------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| `Commits`     | Rebases and fast-forwards the base, keeping every branch commit                                                                                             | each commit is a meaningful step worth keeping in the base history                                |
| `Regroup`     | Rebuilds the branch as the few logical commits the user asks for, then fast-forwards the base like `Commits`                                                | the increments were too many to keep, but the change has parts worth separating                   |
| `Squash`      | Collapses the branch into one commit, then fast-forwards the base                                                                                           | the branch is one logical change and the increments were the route, not the result                |
| `Request`     | Collapses the branch into one commit, pushes it, and opens a pull request                                                                                   | the change needs review or CI on the platform before it reaches the base                          |
| `RebaseMerge` | Regroups the branch into at most five logical commits, pushes them, opens a pull request, fixes CI on it, and lands it with the platform's rebase and merge | the change needs CI on the platform, and its parts belong in the base history as separate commits |

- `Commits`, `Regroup`, `Squash` push the base and delete the feature branch.
- `Request` leaves the base untouched and the branch alive; the platform merges it.
- `RebaseMerge` lands through the platform, driven by the agent.
- `gh` installed → it opens the request; otherwise the script pushes and prints where to open it by hand.
