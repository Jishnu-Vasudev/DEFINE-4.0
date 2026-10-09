# AGENTS.md (always-on rules, keep short)

Project: closed-network PTT communicator (hackathon). Read `SPEC.md` once, then work ONLY from `TASKS.md`.

## Token discipline (strict)
1. Do the NEXT unchecked phase in `TASKS.md` only. Stop after it. Do not start the next phase.
2. Do not scan or summarise the whole repo. Open only files named in the task.
3. Do not re-explain plans. No long summaries. Final reply: max 5 lines (what changed, how to run, what is next).
4. Do not write READMEs, docs, comments-heavy code, or unit tests unless the task says so.
5. No refactors, no renaming, no "improvements" outside the task.
6. Do not browse the web or open a browser to test unless the task says "verify in browser".
7. Do not add dependencies beyond `SPEC.md` "Stack". Ask first.
8. Follow `CONTRACT.md` exactly for routes, events, and table names. Never invent new ones; if something is missing, append it to CONTRACT.md in one line.
9. If a command fails twice with the same error, stop and report the error. Do not loop.
10. After finishing a phase: tick its boxes in TASKS.md, nothing else.

## Code style
- Server: Go 1.22+, `gin`, `gorilla/websocket`, `mattn/go-sqlite3`. Plain functions, one file per concern, files under 200 lines.
- App: Flutter, Android only, `provider` for state. Keep widgets small.
- Admin: one static `admin/index.html` with vanilla JS. No build step.
- Everything runs offline on a LAN. No cloud SDKs, no analytics, no external API calls. Firebase/FCM is out of scope.
