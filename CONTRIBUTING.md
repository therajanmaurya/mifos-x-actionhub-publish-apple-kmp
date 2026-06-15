# Contributing

Thanks for considering a contribution to this composite-action repo. This is part of the [`openMF/mifos-x-actionhub`](https://github.com/openMF/mifos-x-actionhub) constellation.

## Repo scope

This repo houses **composite GitHub Actions** for KMP Android: build, Firebase Distribution, Play Store ladder (Internal → Beta → Production). See [`README.md`](./README.md) for the full sub-action catalog.

Sub-actions live as subdirectories at the repo root (`build/`, `firebase-distribution/`, `play-store-internal/`, `promote-to-beta/`, `promote-to-production/`), each with its own `action.yaml` + `README.md`.

Shared helpers live under [`_shared/scripts/`](./_shared/scripts/). The orchestrator workflow that wires the full promotion ladder lives at [`.github/workflows/release.yaml`](./.github/workflows/release.yaml).

## Development workflow

1. **Branch from `main`**: `git checkout -b feat/<short-description>` or `fix/<short-description>`
2. **Local validation** before pushing:
   ```bash
   # action.yaml YAML syntax
   for f in */action.yaml; do python3 -c "import yaml; yaml.safe_load(open('$f'))"; done
   # shellcheck on shared scripts
   shellcheck -S warning _shared/scripts/*.sh
   ```
3. **PR Check CI** auto-validates: actionlint, per-sub-action YAML + README presence, shellcheck.
4. Open PR against `main`. CI must pass before merge.

## Adding a new sub-action

1. Create subdir: `mkdir <new-action-name>/`
2. Write `<new-action-name>/action.yaml` — composite action shape (`runs: using: 'composite'`)
3. Write `<new-action-name>/README.md` — Inputs/Outputs table + 1 working example
4. Add the subdir to the matrix in [`.github/workflows/pr-check.yaml`](./.github/workflows/pr-check.yaml) `validate-sub-actions.strategy.matrix.subdir`
5. Document the new sub-action in [`README.md`](./README.md) sub-action table
6. Add a `CHANGELOG.md` entry under the `Unreleased` heading

## Releasing

Tags follow [SemVer](https://semver.org). Maintainers cut a release by manually dispatching the [`tag.yaml`](./.github/workflows/tag.yaml) workflow with a bump kind (`patch | minor | major`). The workflow:

- Computes next tag (`v2.0.X`)
- Pushes the tag
- Force-updates rolling `@v2` pointer
- Creates a GitHub Release

Consumers can pin exact `@v2.0.X` or rolling `@v2`.

## Code of conduct

By participating, you agree to follow the [openMF community guidelines](https://github.com/openMF/community).
