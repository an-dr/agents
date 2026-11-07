# Execution

## Sessions

- Preflight and record the declared environment per `an-dr-convention-agent-skill-testing`.
- Install and verify the tested revision and dependencies in the host's normal discovery path; never force-load the target for discovery cases.
- One fresh agent session per trial and arm, with the target skill and its declared dependencies available.
- Independent evaluator agents are authorized only for the explicitly requested cases.
- Never fork the author's conversation, conclusions, or grading rubric into a session; the tested agent gets only the prompt, input evidence, and necessary skill instructions.

## Scratch repositories

- Validate fixture ZIPs; materialize baseline and working trees in a separate scratch repository per trial, per the convention.
- Resolve every write inside the scratch root; reject symlink or reparse-point ancestors; exclude live credentials and services.
- The scratch repository is the agent's working directory.
- Preserve baseline file hashes and git state to check unauthorized changes afterward.
- Never materialize fixtures into the user's working repository.

## Run

- Send follow-ups in order within the same case session.
- Capture transcript, tool results, generated artifacts, and final repository diff; preserve artifacts before cleanup.
- Stop at the attempt or spending limit; record interrupted work as blocked.
- Enforced network, filesystem, or discovery isolation unavailable → follow the best-effort host section of [run-protocol.md](run-protocol.md); mark unsupported security or activation claims blocked.
- Host cannot provide fresh sessions, scratch containment, rubric separation, the requested model, or usage controls a stated cap needs → report blocked coverage; a normal response is not an independent run.
