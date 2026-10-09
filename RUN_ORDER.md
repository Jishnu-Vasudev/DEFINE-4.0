# How to drive the agent cheaply
1. Put these files at the repo root, open the folder in Antigravity.
2. New chat per phase. First message: `Run the build-phase workflow.` (or: `Do the next phase in @docs/TASKS.md`).
3. Use a fast/cheap model for P0-P4 and P7 (boilerplate). Switch to a stronger model only for P3, P6, P8.
4. Commit to git after every phase so a bad run can be reverted instead of re-prompted.
5. If the agent drifts: `Re-read AGENTS.md rules 1-5 and continue.` Do not paste long corrections.
