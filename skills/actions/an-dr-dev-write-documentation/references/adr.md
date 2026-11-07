# Record an ADR

An ADR follows the format and lifecycle of `an-dr-convention-adr`. Record one only for a lasting architectural decision.

1. Create the file with the next free number and the section skeleton:

   ```powershell
   pwsh <an-dr-convention-adr>/scripts/adr-new.ps1 -Title '<title>'
   ```

   It prints the path it created. Fill in every section, keeping each short.

2. To change an integrated decision, write a new ADR that supersedes it, and in the same commit add the single "Superseded by" line to the old one.
3. On a feature branch, when the branch changes its mind about an ADR it added, edit that ADR, or collapse several into the decision actually reached.
4. Before integrating, list the ADRs the branch added:

   ```powershell
   git diff --diff-filter=A --name-only <base>..HEAD -- docs/adr
   ```

   Merge any that supersede, contradict, or rename another from the same branch, and renumber so the numbers stay contiguous. Nothing outside the branch references them yet, so renumbering costs only the in-branch links.
