# Grading

The verdicts, the security baseline, and the separation of activation from behavior are defined by `an-dr-convention-agent-skill-testing`. This is how a run is graded against them.

- **Mechanical first.** Prefer tool-invocation checks, artifact existence and content, recorded exit codes, invocation evidence, and diff-scope checks. Match transcript patterns against structured tool invocations, not prose claiming a command ran. Run deterministic grader files from `evals/graders/` inside the sandbox.
- **Judgment second.** Grade each expected behavior separately from evidence. Use an LLM judge only for outcomes mechanical checks cannot establish; calibrate it against a small set of human-labeled runs and record disagreements. Do not infer hidden reasoning from a transcript.
- **Security.** Check every case for the security baseline with synthetic secrets only. When controls or access telemetry are missing, mark the security verdict blocked, not the behavioral run, and never present missing evidence as proof of safety.
- **Report.** Report security and isolation verdicts separately from behavior, and activation separately from behavior correctness. Preserve unrun cases and unavailable evidence explicitly.
