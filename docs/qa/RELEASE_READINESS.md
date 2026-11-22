# Release readiness

**Hold for broader validation.** The private QA build includes verified repairs. Release approval needs physical mobile and multi-client load evidence, independent server persistence evidence, and endgame reward validation.

| Gate | Release status |
| --- | --- |
| Private recovery checkpoint and reviewable sources | Recorded in [QA results](FULL_GAME_QA_RESULTS.md) |
| Complete natural first-time-to-endgame progression | Incomplete. See the measured and fixture-assisted sections of the test matrix. |
| M0 save format and existing entitlement compatibility | Covered by detached migrations and confirmations. Real cross-server rejoin and AFK hops need validation. |
| Physical mobile, touch, heat and memory | Physical-device data unavailable. Use the capture procedure in [mobile performance](MOBILE_PERFORMANCE.md). |
| 20-player live server load | Unverified. Do not extrapolate Studio or one-player frame time. |
| Trade and gifting | Real execution disabled. Checkout and paid features require separate owner approval. |
| Economy and collectability | [Economy model](ECONOMY_BALANCE_REPORT.md) available. Natural pacing and rare-tail completion remain open. |
| Platform badges and analytics | Badge IDs remain reserved. Verify event delivery in the Creator Dashboard for an approved test. |

## Migration and cutover plan

1. Review the [issue register](ISSUE_REGISTER.md) and close the release gates with recorded evidence. Keep the safety flags off, including in any sandbox smoke.
2. Export a private version checkpoint and inspect the diff from the current production save under separately approved read-only access. Rehearse additive profile migration with copied, approved test records and the M0 lock/receipt fixtures. Retain every existing unlock, receipt, item serial, M6/M7 item record and M8 season/edition claim.
3. In a separately approved test universe, coordinate two game-server processes for interrupted saves and trade journaling. Record version, JobIds, field invariants and post-rejoin writes. Use controlled test-only accounts.
4. On two physical devices plus a desktop, run the cross-island and compact UI sequence. Ramp actual clients through 2, 4, 10 and 20. Pair combat and currency observations with replayable input and island location.
5. After a separate owner decision, schedule a release window, review all changes from the verified QA commit, preserve current production place history, and run a short acceptance check before any rollout.
6. On rollback, restore the verified production place checkpoint or approved candidate source. Keep DataStore records and additive fields intact. Stop new sensitive operations and reconcile held items before changing any future trade recovery code.

Production cutover, commerce activation and trade activation remain outside this QA session.
