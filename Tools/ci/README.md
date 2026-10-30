# CI

`store.yml` runs on every pull request and every push to `main`: `python Tools/build_store.py --check` (the catalog,
packages and listings are up to date and every item is valid), then the source repository's `catalog_check.py` and the
Lua / JavaScript / Python checkers on the items the pull request changes (needs the secret `SOURCE_REPO_TOKEN` while
the source repository is private).

To enable it, copy it to `.github/workflows/store.yml` from the GitHub web UI (**Add file > Create new file**). Pushing
workflow files from a clone needs a GitHub token with the `workflow` scope. See [../README.md](../README.md) for the
branch protection rule that makes the owner's review mandatory.
