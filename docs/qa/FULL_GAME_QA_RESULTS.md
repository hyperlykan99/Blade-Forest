# Blade Forest full-game QA

**Hold release.** The candidate has verified fixes and usable single-client gameplay evidence. Some requested journeys require independent game servers, multiple accounts or physical devices.

| Record | Value |
| --- | --- |
| Branch | `qa/full-game-validation` |
| Code commit | `5248c6d94b2d5125b5bbb1d4857819dc89484df7` |
| Baseline | M8 `2d719aa97093481a719c23f1c625811132b830f9`, private v69 |
| Private candidate | **v75**, confirmed in Roblox Studio Version History. Cloud update `2026-11-22T00:23:31.521Z`, Team Create reports no unsaved changes. |
| Place and universe | `103379930563763` / `10777797608` |
| Rollback | Private baseline v69 and QA checkpoint v70, cloud update `2026-11-21T23:43:43.775Z`. `ServerStorage.QARollback` retains the 25 pre-fix source copies and two inert copies of the original Silvershore template. |
| Trade and gifting | Both disabled in the saved candidate. |
| Editor | Released in Edit mode. |

The final private Edit model compiled and checksum-matched 23 source scripts. Both safety flags and the Studio sandbox toggle were off in the saved candidate. The temporary two-client driver was removed from the editor.

## Scope and evidence labels

**Played** uses game client inputs, server remotes and real game systems. **Prepared** uses an explicitly seeded isolated profile or repositioned avatar, then exercises the game behavior. **Fixture** uses detached tables or controlled mock stores. **Unverified** denotes a path without the requested evidence. The Studio tests used the account’s separate `BF_QA1_` namespace. The initial profile had zero Logs, rolls and chops, and its existing account’s Starter Pack entitlement was read into the test copy.

## Audit and validation matrix

| System | Evidence | Result |
| --- | --- | --- |
| M0 save schema, lock, serialized writer, receipt idempotency | Fixture and isolated real store | 64 migration, 15 locking, 13 mock receipt, 64 M0.1 and 11 real-store lock checks passed. The real store test exercised two session owners within one Studio process. |
| New join and first chop | Played | Started in Timber Haven with zero recorded chops. Walked to a real Sapling and received Logs and chop credit from server blade overlaps. |
| Onboarding | Played, partial | Guide served a fresh sandbox profile. Tutorial completion acknowledgement persisted. A timed pass through every guide card remains outstanding. |
| Upgrade, rolling, equip, affordability | Played | Speed 0→1, rolled and equipped Farmhand Scythe from the ordinary remotes. Initial Frostbound entry rejected. |
| Weapon models and rarity | Fixture and Studio asset review | M2 suite passed 46 checks, covering all 120 model instances, ownership/odds structure and catalog compatibility. Silvershore Saber now uses original accessible geometry. |
| Mastery and Tech Tree | Played / prepared and fixture | Mastery reached 48 after additional staged XP and real combat. Blade01 unlocked through the server remote. The M3 harness validated the 72 nodes and 100 levels. |
| Pet and trait | Prepared and fixture | Purchased a Cat egg and equipped it. Acquired Sapling through the normal Trait remote. M3 harness validated 21 families, 63 model forms and 12 traits. Full evolved profile rejoin remains separate. |
| Timber, Crystal and Frostbound travel | Played / prepared | Initial Frostbound entry was rejected, then ordinary Crystal travel unlocked after the observed Blade King credit and earned Timber chops. Ordinary Frostbound travel succeeded after a real Colossus credit and a seeded Crystal tree threshold. |
| Progression bosses and raids | Played with prepared equipment | Blade King and Crystal Colossus each credited a real kill and first-clear reward. The Colossus approach used a staged avatar position. Frost Monarch also credited a real kill and first clear in Frostbound after a staged approach. Crystal Hydra spawned in its actual scheduled window and credited Skyshard Aegisblade, the rotation slot and one daily reward. |
| Daily Contracts and Story quests | Played | Accepted a Daily Contract, filled a 45-chop target and claimed it. Claimed the first Timber story step. |
| Chopping Trials | Played | Finished a real timed Trial, scored nine trees, earned four Trial Tokens and returned to the Timber arrival. |
| Expeditions | Played with a staged start position | Entered from the real gate prompt, cleared depth 1, advanced to the next depth and returned to Frostbound. |
| Forge, Awakening, Runes and Winter Key | Prepared | At the actual Frostgate Forge Annex, used the normal remote to Awaken Frostbound Reaper through III, crafted Edge1, socketed it in slot 3 and crafted one Winter Key. The sandbox supplied the required item Stars and material budget. |
| Heart of Winter | Played with prepared equipment | Entered through the Winter Key prompt, reached phases I, II and III, broke the seals, saw Victory and returned to Frostbound. The save confirmed one clear, weekly credit recorded, one Eternal Winter reward and the key spent. |
| Parties and Guilds | Played, partial | Created a server-local party and a guild using the isolated stores. Invites across two actual clients and cross-server guild admission remain unverified. |
| Vault | Played and fixture | Deposited the owned Farmhand Scythe. Detached checks also blocked both favorite and vaulted trade candidates. |
| Season, achievements and collection | Played and prepared | Ordinary gameplay earned 106 XP before the restart. Seeded level-one readiness in the sandbox, claimed the live free-track reward and received `Already claimed` on replay. Claimed the First clearing achievement, rejected its replay and claimed the 10% collection milestone from 244 points. Full-season rollover remains separate. |
| Rejoin | Played | Rejoined a fresh Studio process session with confirmed saved QA progress. Cat, Sapling, Blade01, tutorial completion, guild, Farmhand Scythe vault deposit, four Tokens and Trial best of nine remained present. A second confirmed rejoin preserved Awakening III, Edge1 in socket 3, Eternal Winter, weekly Heart credit and the spent key. |
| AFK, Auto Chop and Auto Roll | Played, partial | Auto Chop toggle started and stopped, and the chosen 45-chop Contract completed. Auto Roll started and stopped via its normal controller binding and the saved roll count rose from one to eight. The hosted AFK teleport flow remains unverified. |
| Performance and replication | Desktop single client and device emulation where recorded | [Measured result and device plan](MOBILE_PERFORMANCE.md). The two-client launcher did not expose a usable test server or a saved test result. The supported API attempt lost its bridge, and Studio did not make the native controls available while the local session was stalled. The dedicated harness is retained under `tools/qa`. The 20-player load remains unverified. |
| Trading and gifting | Detached recovery fixture | Seven fixture scenarios passed, including aborted and committed item settlement, retry and reconciliation, vault checks and the Heart phase regression. No enabled trade or payment ran. |

- [Raw Studio results](STUDIO_EVIDENCE.json)
- [Issue register](ISSUE_REGISTER.md)
- [Economy balance report](ECONOMY_BALANCE_REPORT.md)
- [Security and persistence](SECURITY_AND_PERSISTENCE.md)
- [Mobile performance](MOBILE_PERFORMANCE.md)
- [Release checklist, migration and cutover](RELEASE_READINESS.md)
