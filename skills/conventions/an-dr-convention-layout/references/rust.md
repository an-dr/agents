# Rust layout

Inside each crate, Cargo's own conventions hold.

## Single crate

- A repository with one crate has `Cargo.toml` and `src/` at the root, with `src/main.rs` for a binary or `src/lib.rs` for a library.
- Runnable examples are Cargo examples in `examples/`.

## Workspace

- A repository with more than one crate is a single Cargo workspace. Its root `Cargo.toml` is virtual: it lists the members and shared dependencies and has no `[package]`. A folder of crates is a set of members of that workspace, never a second workspace.
- Library crates live in `crates/<crate>/`.
- Each shipped binary lives in `apps/<app>/`, with its `Cargo.toml`, `src/`, `build.rs`, and run-time `assets/` directly inside. An application of several parts, such as a native host and a web front end, holds each in `apps/<app>/<part>/`.
- Build, packaging, and release automation is an `xtask/` crate, run through an alias in `.cargo/config.toml`.
- Crates taken from another repository as git submodules live in `vendor/<name>/`.

## Names

- A workspace crate is named `<project>-<part>`, such as `devpanel-core`, and its folder carries the same name. The main application crate is named after the project.
- Crate names are lowercase with hyphens.

## Tests and docs

- A module's unit tests are in a sibling `tests.rs`, declared with `#[cfg(test)] mod tests;`. A few short tests may stay inline in a `#[cfg(test)] mod tests` block.
- Tests of a crate's public interface are in that crate's `tests/`.
- Each workspace crate has a `README.md` saying what it owns and what it depends on.

## Examples

```text
Cargo.toml            virtual workspace
.cargo/config.toml    xtask alias
apps/devpanel/        Cargo.toml  build.rs  src/  assets/
crates/devpanel-core/ Cargo.toml  README.md  src/lib.rs  src/tests.rs  tests/
crates/devpanel-infra/
xtask/                Cargo.toml  src/main.rs
vendor/bones/         git submodule
```
