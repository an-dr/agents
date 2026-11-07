# Buckets

| Bucket   | Meaning                                                                                                                                                             |
| -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| keep     | true, useful, in the right place; carry across unchanged, wording included                                                                                          |
| rewrite  | true but buried, bloated, or out of order                                                                                                                           |
| cut      | false, duplicated elsewhere in the file, or dead                                                                                                                    |
| relocate | true but at the wrong altitude: a specification to its owning document, design detail to `design/`, implementation notes to doc comments; move and link, never both |
| missing  | the baseline or a conditional module the evidence supports                                                                                                          |

- A chaotic README suffers more from redundancy, dead links, and bad order than from missing content; a cut improves it as much as an addition.
- Before relocating a section that restates a specification, check it against the owning document; the copy readers reach first has usually drifted already.
