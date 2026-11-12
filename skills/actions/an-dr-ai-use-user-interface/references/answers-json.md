# Questions JSON

```json
{ "questions": [
  { "id": "Q1", "question": "Which storage should the cache use?",
    "options": [ { "label": "SQLite file (Recommended)", "description": "survives restarts" },
                 { "label": "In-memory map" } ] },
  { "id": "Q2", "question": "Delete the 3 files in build/?", "kind": "confirm",
    "options": [ { "label": "No — keep them" }, { "label": "Yes — delete them" } ] }
] }
```

- Options take keys `a`, `b`, … in order unless they set `key`.
- `multiSelect: true` allows several choices.
- `kind: "confirm"` also accepts `y`/`n`.
