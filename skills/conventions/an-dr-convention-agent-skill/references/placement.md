# Placement, names, and registration

## Layout

- **Folders.** A skill is `skills/<category>/<name>/`. `actions/`, `concepts/`, and `conventions/` hold general skills of the matching type, and the folder and `an-dr.type` agree. A folder whose name starts with an underscore, such as `_repository/`, holds skills that exist for the repository itself, of any type.
- **Name.** Kebab-case, identical to the folder and the frontmatter `name`. A concept's name contains `concept-` and a convention's contains `convention-`, so the type shows in a tool's flat skill list. A project may add a namespace prefix and a naming scheme for its actions. Names are unique across all folders, because tools install skills side by side.
- **Paths.** SKILL.md commands write the skill's own scripts as `<skill>/scripts/...` and another skill's folder as `<that-skill-name>`, the form `AGENTS.md` defines. They contain no absolute path, no path through this repository's layout, and no submodule folder name.
- **Self-contained.** Everything a skill runs lives in its own folder.

## Registration

Every skill has a row in the table in `skills/README.md` with a one-line use, and the root `README.md` describes what the skill changes wherever it covers that area. After a rename, the old name appears nowhere in the repository.
