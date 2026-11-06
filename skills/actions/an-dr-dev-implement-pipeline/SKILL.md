---
name: an-dr-dev-implement-pipeline
description: Set up or update a project's continuous integration and release pipeline from what the repository actually builds and tests. Use when a new project has no CI, when the user asks for CI or a release pipeline, or when an existing pipeline no longer matches how the project is built.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.0.0"
  an-dr.type: action
  an-dr.dependencies: an-dr-ai-send-message
---

# Pipeline

Makes every change build and test the same way everywhere, and turns a version into release artifacts through one repeatable path. It writes the pipeline files and leaves deployment to running environments out of scope.

## Establish what exists

Read the manifests, build scripts, test setup, README, and any existing pipeline files. Record:

- the commands that build, lint, and test the project, confirmed by running them locally;
- the hosting platform, taken from the repository's remote and existing files;
- the operating systems and toolchain versions the project supports;
- where the version lives, and what a release produces.

Ask through `an-dr-ai-send-message` for what the repository does not show, such as the platform of a repository with no remote. Never invent a target, a registry, or a supported platform.

## Build the CI

1. Run the same commands a developer runs locally, ideally one entry point the project already has. Add a project script when the steps would otherwise exist only in the pipeline.
2. Trigger on pushes and pull requests.
3. Test every operating system and toolchain version the project states it supports, and no others.
4. Pin third-party actions and tool versions, and grant only the permissions each job needs.
5. Cache dependencies only when the build is slow enough to benefit.

## Build the release

Add this when the project ships something and the user wants it.

1. Trigger on a version tag, and fail when the tag disagrees with the version in the repository.
2. Run the same checks as CI before building anything.
3. Build the artifacts, and attach them to the platform's release or the registry the user named.
4. Refer to credentials only as platform secrets, and name each secret the user must add.

## Verify

- Run every command the pipeline calls locally, and fix what fails.
- Validate the pipeline file with the platform's linter when one is installed. When it is missing, name it and let the user decide whether to install it.
- Report what stays unproven: a pipeline is only proven by a run on its platform, so state whether one happened and give its result.

## Output

The pipeline files and any project script they call, with a short README note on how CI and releases work. List the secrets to add, the first run to watch, and how to cut a release.

## Rules

- **No hidden logic.** A check that only the pipeline can run cannot be reproduced when it fails, so keep the steps runnable locally.
- **Explicit approval to publish.** Pushing a tag, publishing a release, changing repository settings, and adding a secret each need the user's explicit approval. Approval of the pipeline files does not cover them.
- **No secrets in files or logs.** Never commit a credential or print one in a step.
- **No unrequested stages.** Add a job only when it serves a command, target, or artifact the project has.
