# Switching the flow

- Exploration can prove the chosen flow wrong: a design the user wants to check step by step needs Supervised; a Supervised plan collapsing to one obvious change does not.
- Never delete `.progress/` to start over; requests, questions with answers, and the four requirements survive the switch.
- `switch-flow` returns to `INTAKE` and drops every approval and every planned increment, since the flows collect different gates and a carried phase would credit an approval nobody gave.
- Refused once `BRANCH` created a feature branch, once any increment left `planned`, or while the tree is dirty apart from `.progress/`; past those points the branch is finished or abandoned on its own terms, so no delivered work is orphaned.
