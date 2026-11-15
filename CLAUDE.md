# Claude rules for this repo

## "Update" means update everything

When the user mentions updating in this folder, do all of these in order:

1. **Pull the fork (`origin`, tajshaik24/DiaTweaks).** `git fetch origin`. If `main` has diverged (origin is sometimes force-pushed after upstream merges), don't reset blindly: check `git log origin/main..main` and `git cherry -v origin/main main`, confirm each local-only commit's change exists on origin (it's often rewritten under a new SHA), save a `backup/pre-update-<date>` branch, then `git reset --hard origin/main`. Stop and ask if a local change really is missing upstream.
2. **Pull the main repo (`upstream`, JaceThings/DiaTweaks).** If the remote is missing, add it with `git remote add upstream https://github.com/JaceThings/DiaTweaks.git`. `git fetch upstream`, then merge `upstream/main` into `main` if `git log main..upstream/main` shows anything. Push the merge to `origin` without asking (the user approved this standing rule on 2026-11-15).
3. **Update DiaTweaks.** `./install.sh --yes` (rebuilds and repatches Dia; Dia quits and reopens).
4. **Update Dia.** Run `"$HOME/Library/Application Support/DiaPatches/bin/diapatch" status`. If `feed` is newer than `official`, run `diapatch update` (or `diatweaks update-dia` if the Rust CLI is installed).
5. **Verify.** `diapatch status` shows `patched yes`, `strings` on diapatch contains `tajshaik24/DiaTweaks`, and `ls -t ~/Library/Logs/DiagnosticReports | grep -i dia` shows no new crash reports.
