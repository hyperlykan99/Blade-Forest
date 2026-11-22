# Security and persistence

## Test isolation

The authorized private place was required by ID and universe before every Studio edit. The QA-only Studio profile mode routes persistence, leaderboards, guilds, public card projections and the trade journal to a separate `BF_QA1_` namespace. No production store was addressed. The owner’s ordinary private development save stayed outside the test. Known entitlement reads on the tester account can still populate the sandbox profile, so a new sandbox profile with the owner’s account is not free-player evidence. The mode is cleared in the saved QA configuration. The trade and gifting flags stay false.

## Evidence

- M0 detached suites passed 64 migration, 15 locking and 13 receipt cases using synthetic data. M0.1 passed 64 cases, including serialized writes, handoff failure and MovementGuard decisions. No real transaction was issued. The M1 run passed 40 of 41 initially. The readiness-aware gate retest passed all 11 E3 cases. Detailed gameplay evidence is recorded in the [test matrix](FULL_GAME_QA_RESULTS.md).
- All seven detached scenarios passed. They cover no escrow, one escrow, repeated first acknowledgement, abort, both acknowledgements and commit, replay after one profile settles, expiry or missing journal, favorite/vault protection, and the Heart phase regression.
- The separate real DataStore lock suite passed 11 of 11 in one Studio process. It refused a second owner on a fresh lease, refreshed and expired leases, rejected an old writer, and passed five sequential handoffs. A sandbox profile save returned confirmed. On a new Play session the saved Cat, Sapling trait, Blade01, vault deposit, four Trial Tokens and Trial best of nine were present. The second rejoin preserved Awakening III, socket 3, the spent Winter Key and weekly Heart reward credit.
- Existing server-side blade geometry remains the only damage path. The Heart caps a high hit at the next phase threshold and payout checks individual current eligibility. The phase-floor suite covers high values without changing a real profile.
- Legacy shop, roll and preference mutations now stop while a server handoff is active. Numeric preferences require a finite value. The ordinary Studio Meta endpoint rejected a non-finite preference with `Invalid setting`. All three remotes rejected the sandbox player while handoff was active.
- The vault uses M6 stable identities and protection checks. The detached test refused favorite and vaulted transfers and preserved the exact serial after retrieval. The live vault check is recorded separately from the detached tests.

## Remaining risk and reproducible test

Use a separately approved isolated game universe with two independently hosted JobIds and two test-only accounts. Move distinct tracked spare items through a QA-only journal adapter or explicitly approved sandbox configuration. Keep the saved shared development flag off. Capture a durable record and each session's profile view before escrow, after each acknowledgement, and after terminal settlement. Stop or disconnect the relevant server at each boundary and retry on another server. Verify that committed items switch owners once, aborted items return once, old writers cannot write after lease takeover, and an unavailable journal leaves escrow unavailable for use. Include same-session retries, account rejoin, delayed confirmation, server shutdown, missing writer and retry after backoff.

The detached code never proved a two-host escrow, the real Roblox AFK teleport flow, real purchase callbacks, concurrent raid credit or independent cross-server guild membership races. Keep these explicit in the release gate.
