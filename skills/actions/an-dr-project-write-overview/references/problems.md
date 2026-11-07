# Problems

Hunt each category deliberately; do not just report what the scan surfaced.

| Problem                   | Evidence that proves it                                                                                                              |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| Circular dependencies     | a concrete import cycle, named module by module                                                                                      |
| Layering violation        | an inner layer importing an outer one — domain reaching into transport, business logic importing the database driver, UI holding SQL |
| God module                | one file or class with disproportionate size and fan-in, named with both numbers                                                     |
| Duplicated logic          | the same rule implemented in two places that can now disagree                                                                        |
| Hidden coupling           | modules that always change together in the churn history without importing each other                                                |
| Dead code                 | exports, flags, or whole directories nothing reaches                                                                                 |
| Untested critical path    | the primary flow's modules absent from the test evidence                                                                             |
| Silent failure            | swallowed exceptions, ignored return values, bare catches on the main path                                                           |
| Configuration and secrets | committed credentials, hardcoded hosts, defaults that only work on one machine                                                       |
| Dependency risk           | unpinned, duplicated, abandoned, or a lockfile that disagrees with its manifest                                                      |
| Build and CI gaps         | a build or test command in the documentation that CI does not run, or that fails on a clean checkout                                 |
| Documentation drift       | the whole intent-versus-reality table, summarised as one ranked entry                                                                |
