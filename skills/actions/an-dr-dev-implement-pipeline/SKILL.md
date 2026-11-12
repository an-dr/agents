---
name: an-dr-dev-implement-pipeline
description: Set up or update a project's continuous integration and release pipeline from what the repository actually builds and tests. Use when a new project has no CI, when the user asks for CI or a release pipeline, or when an existing pipeline no longer matches how the project is built.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.1.0"
  an-dr.type: action
  an-dr.dependencies: an-dr-ai-use-user-interface an-dr-convention-code
---

# Pipeline

Defers: questions to `an-dr-ai-use-user-interface`; formatter and linter setup to `an-dr-convention-code`. Deployment to running environments is out of scope.

## Establish what exists

1. Read manifests, build scripts, test setup, README, and existing pipeline files.
2. Record:
   - build, lint, and test commands, confirmed by running them locally;
   - hosting platform, from the remote and existing files;
   - supported operating systems and toolchain versions;
   - where the version lives and what a release produces.
3. Ask for what the repository does not show, such as the platform of a repository with no remote; never invent a target, registry, or platform.

## Build the CI

1. Run the commands a developer runs locally, ideally one existing entry point; add a project script when steps would otherwise exist only in the pipeline.
2. Formatting check and linter fail the build; when absent, configure them first, omitting them only when the user excludes them.
3. Trigger on pushes and pull requests.
4. Test every stated supported OS and toolchain version, and no others.
5. Pin third-party actions and tool versions; grant each job only the permissions it needs.
6. Cache dependencies only when the build is slow enough to benefit.

## Build the release

Only when the project ships something and the user wants it.

1. Trigger on a version tag; fail when the tag disagrees with the repository version.
2. Run the CI checks before building.
3. Build the artifacts; attach them to the platform's release or the registry the user named.
4. Credentials only as platform secrets; name each secret the user must add.

## Verify

- Run every command the pipeline calls locally; fix what fails.
- Validate the pipeline file with the platform's linter when installed; when missing, name it and let the user decide on installing.
- State whether a run on the platform happened and its result; only such a run proves the pipeline.

## Output

- Pipeline files, any project script they call, and a short README note on how CI and releases work.
- Secrets to add, the first run to watch, how to cut a release.

## Rules

- Every step runnable locally; a pipeline-only check cannot be reproduced when it fails.
- Pushing a tag, publishing a release, changing repository settings, and adding a secret each need explicit approval; approval of the pipeline files does not cover them.
- Never commit a credential or print one in a step.
- Add a job only when it serves a command, target, or artifact the project has.
