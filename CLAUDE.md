# Claude rules for this repo

## "Update" means update everything

When the user mentions updating in this folder, do all of these in order:

1. **Pull the fork (`origin`, tajshaik24/DiaTweaks).** `git fetch origin`. If `main` has diverged (origin is sometimes force-pushed after upstream merges), don't reset blindly: check `git log origin/main..main` and `git cherry -v origin/main main`, confirm each local-only commit's change exists on origin (it's often rewritten under a new SHA), save a `backup/pre-update-<date>` branch, then `git reset --hard origin/main`. Stop and ask if a local change really is missing upstream.
2. **Pull the main repo (`upstream`, JaceThings/DiaTweaks).** If the remote is missing, add it with `git remote add upstream https://github.com/JaceThings/DiaTweaks.git`. `git fetch upstream`, then merge `upstream/main` into `main` if `git log main..upstream/main` shows anything. Push the merge to `origin` without asking (the user approved this standing rule on 2026-11-15).
3. **Update DiaTweaks.** `./install.sh --yes` (rebuilds and repatches Dia; Dia quits and reopens).
4. **Update Dia.** Run `"$HOME/Library/Application Support/DiaPatches/bin/diapatch" status`. If `feed` is newer than `official`, run `diapatch update` (or `diatweaks update-dia` if the Rust CLI is installed).
5. **Verify.** `diapatch status` shows `patched yes`, `strings` on diapatch contains `tajshaik24/DiaTweaks`, and `ls -t ~/Library/Logs/DiagnosticReports | grep -i dia` shows no new crash reports.

## The daily sync and its "Upstream sync needs a hand" issue

`.github/workflows/sync.yml` runs `scripts/sync-upstream` every day: it merges `upstream/main`, pins uBlock Origin's latest release, runs `make check` and the CLI tests, and publishes the next `v<upstream>-taj.<n>` release. When a merge conflicts, a check fails, or a push is refused, it pushes nothing and opens (or comments on) an issue titled "Upstream sync needs a hand". With a `CLAUDE_CODE_OAUTH_TOKEN` (or `ANTHROPIC_API_KEY`) secret, Claude first tries steps 1–3 below on the runner; the workflow re-checks and releases its commits itself, and the issue (with Claude's note) only opens if that still fails. "Run workflow" with **dry run** ticked tries all of it without pushing or releasing.

When the user points at that issue, or asks to "pull the main repo" / "make a new release":

1. `git fetch origin upstream`, then `git merge upstream/main`.
2. For each conflict, read ours, theirs and the merge base (`git show HEAD:f`, `upstream/main:f`, `$(git merge-base HEAD upstream/main):f`). Keep every fork-only change (uBlock Origin, the Horizontal Tabs toggles, the two-layout test runner, `DIATWEAKS_DOMAIN`, links to tajshaik24/DiaTweaks releases) on top of upstream's new code. If upstream changed something a fork tweak relies on and the right fix isn't clear, stop and ask.
3. `make`, `make check`, `cargo test --manifest-path cli/Cargo.toml` must all pass; fix what the merge broke. Upstream tests sometimes call the fork's changed test helpers, and some count tweaks, sections and Settings rows by hand (`tests/settings-cleanup.m`, `tests/local-tweaks.m`): add the fork's three tweaks (uBlock Origin, Hide Pinned Tabs in Tab Bar, Hide Profile Name) and two sections (Horizontal Tabs, Privacy) to upstream's numbers.
4. Commit the merge, push `main`, then run the workflow (`gh workflow run sync.yml`) so it pins uBlock Origin, releases with cleaned-up notes, and closes the issue. Watch the run and report the release link.

