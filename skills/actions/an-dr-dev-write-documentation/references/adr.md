# Record an ADR

Format and lifecycle: `an-dr-convention-adr`. Only for a lasting architectural decision.

1. Create the file with the next free number and the section skeleton; it prints the path. Fill every section briefly.

   ```powershell
   pwsh <an-dr-convention-adr>/scripts/adr-new.ps1 -Title '<title>'
   ```

2. Changing an integrated decision → new superseding ADR, and in the same commit the single "Superseded by" line in the old one.
3. Feature branch changes its mind about an ADR it added → edit it, or collapse several into the decision reached.
4. Before integrating, list the branch's added ADRs:

   ```powershell
   git diff --diff-filter=A --name-only <base>..HEAD -- docs/adr
   ```

   Merge any that supersede, contradict, or rename another from the same branch; renumber to keep numbers contiguous (only in-branch links reference them).
