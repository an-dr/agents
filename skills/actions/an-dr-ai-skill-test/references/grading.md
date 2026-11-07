# Grading

`an-dr-convention-agent-skill-testing` defines the verdicts, the security baseline, and the separation of activation from behavior.

- Mechanical first: tool-invocation checks, artifact existence and content, recorded exit codes, invocation evidence, diff-scope checks.
- Match transcript patterns against structured tool invocations, not prose claiming a command ran.
- Run deterministic grader files from `evals/graders/` inside the sandbox.
- Judgment second: grade each expected behavior separately from evidence.
- LLM judge only for outcomes mechanical checks cannot establish; calibrate it against a few human-labeled runs and record disagreements.
- Never infer hidden reasoning from a transcript.
- Check every case against the security baseline with synthetic secrets only.
- Controls or access telemetry missing → security verdict blocked, not the behavioral run; missing evidence is never proof of safety.
- Report security and isolation verdicts separately from behavior, and activation separately from behavior correctness.
- Report unrun cases and unavailable evidence explicitly.
