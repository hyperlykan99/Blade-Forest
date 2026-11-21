# M7 — Social systems, guilds, parties, trading and vaults

| Record | Value |
| --- | --- |
| Branch | `m7/social-guilds-trading-vaults` |
| Implementation commit | `34ef2e9a101b3a3c8ed40f24c04c5f48666f4c11` |
| Baseline | M6 `47fcd18b689cf7590d923e8dff8d37dcbb62b27a`, saved v60 |
| Private development | Place `103379930563763`, universe `10777797608`, world v2 |
| M7 save | Cloud update `2026-11-21T23:19:38.431Z`. Team Create confirmed no unsaved changes. Numeric version unverified because the save response omitted it and the place history read returned HTTP 403. |
| Rollback | Private checkpoint cloud update `2026-11-21T04:49:59.443Z`, numeric version unverified. `ServerStorage.M7Rollback` contains 13 inert originals with source path and class metadata. |
| Editor | Released in Edit mode |

## Parties and encounters

Parties are server-local and hold two to four players after invitations are accepted. A leader can start alone, invite, kick or transfer leadership. Invitations expire in 45 seconds and are specific to the inviting party and leader. Leaving or disconnecting removes the player and promotes the next remaining member. The HUD shows each member's current island and encounter.

- **Raids.** The leader rallies at the currently scheduled raid. Every member must be in the arena area on the correct island and meet its Power gate. The world encounter keeps its original nearby-player scaling and individual contribution, daily, and slot checks.
- **Heart of Winter.** The leader launches a private arena for the party at the Sanctum. Each member needs Frostbound access, sufficient Power, an individual Winter Key, a living character near the entrance, and no conflicting run or travel. The group uses the existing M6 phases and per-player weekly reward ledger. A retreat, death or disconnect follows M6 key preservation rules.
- **Expeditions.** Eligible party members at the Frostbound Expedition Gate stream into a shared leased arena. Tree HP scales by 55% per extra member. At each cleared depth, 2% damage or 12 hits qualifies a player for the original individual weekly progression and rewards. The current leader can advance and leadership passes to a surviving member if the leader exits. Separate arrival slots and active-lease validation gate combat and return travel.
- All three encounters retain solo entry. Joining a party adds no combat bonuses.

## Guilds

Guilds have up to 30 members. A persistent guild record holds its filtered name and description, applications, invitations, member roles, contracts, XP and 40 audit entries. Owners edit the profile, change roles, transfer ownership and remove members. Officers handle applications and invitations and may kick regular members. Members may leave. The owner transfers leadership first or closes an otherwise empty guild.

Membership starts with a compare-and-swap claim on the player's separate membership key. A guild update adds the matching claim token and, for a new member, consumes the invite in the same write. The pointer becomes active after the guild confirms the same token. A join interrupted between writes is resumed by the next membership lookup. Leave and kick remove membership in the guild record first and retire the matching pointer. Each role-sensitive action checks current guild membership and permissions in the update. Guild profile previews expose audit and application data only to current management. Invitation delivery uses a bounded inbox plus an authoritative guild invitation, and an application approval creates an invitation that the player accepts.

Guild XP raises levels 1–10 at cumulative thresholds 0, 350, 850, 1,700, 3,000, 5,000, 8,000, 12,500, 19,000 and 27,000. Contributions use bounded, per-member weekly high-water marks and idempotent guild updates. The leaderboard indexes guild XP. Guild progression unlocks cosmetics at levels 3 and 7 and contributes **0%** to Logs and combat.

| Weekly guild contract | Goal | Per-member contribution cap | Reward |
| --- | ---: | ---: | ---: |
| Woodland stewards | 1,800 credited chops | 450 | 550 Guild XP |
| Island defenders | 12 boss credits | 4 | 750 Guild XP |
| Into the frost | 30 reward-eligible expedition depths | 10 | 850 Guild XP |

Contracts reset Monday UTC and each completion can add XP once per guild per week. Roblox filters public guild text and the server requires applicable content-sharing permission. [Roblox text filtering](https://create.roblox.com/docs/reference/engine/classes/TextFilterResult) · [Roblox policy fields](https://create.roblox.com/docs/reference/engine/classes/PolicyService/GetPolicyInfoForPlayerAsync)

## Profiles, titles, auras and vaults

The public card exposes an avatar thumbnail, Mastery, tree chops, highest island, weapon and pet showcases, three rare weapon highlights, equipped title and aura, guild affiliation and boss, raid, Trial and Expedition accomplishments. Online cards are generated from an explicit public projection. Offline cards use the stored projection. Vault slots are private by default and can each be included in the public showcase by the owner. Public lookups only receive the agreed fields.

Eight title and aura pairs are earned through chops, collection, Mastery, progression bosses, raids, Heart of Winter and guild levels. Titles use distance-limited overhead labels. Auras use a bounded highlight and optional short-range light. Reduced motion or Low graphics uses the static highlight.

Six vault slots accept owned weapons and normal, Golden or Rainbow pets. Each weapon slot references the M6 representative GUID, creating one if needed. Pet slots reference the exact variant and have their own stable vault entry ID. The item remains owned, equippable and compatible with favorites. The selected weapon stack is shielded from auto-sell, auto-fuse, manual fusion, Shiny crafting, salvage and trade. The selected pet variant is protected from evolution and trade. The owner can view rarity and item stats, retrieve a slot or toggle its public showcase. Deposit and retrieval modify the existing profile in a single non-yielding operation.

The two v2 islands each have four prompted stations for guild management, the vault, player showcase and party rally. The HUD's Social tile opens a scrollable six-tab layout for Party, Guilds, Profiles, Vault, Cosmetics and Trade.

## Trade journal and recovery

`M7Flags.TradeExecution=false` in server source. With the flag off, remotes refuse request and execution operations. The settings and history UI remains accessible. The enabled path is one-for-one, weapon for pet or eligible distinct copies, with no currency. Offers are limited to tracked spare weapon copies and tracked unequipped normal pets. Legacy untracked items, evolved pets, exclusive and bound items, favorites, equipped items, vaulted items and held items cannot transfer. Approved free-source duplicates acquire stable serials. Serials are retired conservatively when old inventory mechanics consume copies. A newly received weapon may become the M6 representative and retains its serial. The server checks both accounts' Roblox paid-item trading policy before escrow. [Roblox paid item policy](https://create.roblox.com/docs/production/monetization/paid-random-items)

1. The in-server window verifies ownership, serial, eligibility and both confirmations. A five-second countdown follows the last confirmation. Changes to inventory or offers invalidate confirmation. Requests expire, are rate-limited, and cancel on disconnect.
2. The server creates one durable transaction in `Preparing` with both user IDs, exact serials and an expiry. It removes both offered copies into profile-specific escrow and sets matching pending records.
3. M0/M0.1 serializes each profile write and fences it with the existing session lock. The journal accepts a `Prepared` acknowledgement for each user only after that user's save confirms. A single journal update commits when both acknowledgements exist. A timeout or cancellation while still preparing moves to `Aborted`. A terminal journal decision is immutable.
4. Each profile independently settles the same decision. Commit applies the incoming item and abort restores the outgoing item. Item update, history and pending-record removal are part of the same profile write. A reconnect can replay an unfinished settlement. A profile whose pending record is gone has nothing to apply again. A restart before both confirmed acknowledgements can only abort unless the journal had already committed. The profile loader reconciles before exposing inventory. An unavailable journal leaves pending escrow fenced for retry.

The transaction namespace and player profile saves are deliberately distinct. The journal is authoritative for the decision across the two independent saves. The trade flag must stay off until dedicated multi-server tests cover save ambiguity, concurrent session takeover, disconnect at each boundary and retries.

## Gifting and DataStores

`M7Flags.PaidGifting=false`. The gift-product allowlist is empty. The dormant adapter stages product, buyer and recipient consent for eligible accounts and can attach an authenticated receipt to a buyer outbox through the existing M0 confirmed receipt processor. Recipient delivery, real product setup and the purchase UX are deferred to a separately approved purchase-validation effort. Existing receipt grants and their deduplication remain on the existing receipt path. No product is activated.

| Storage | Purpose |
| --- | --- |
| Existing player profile | Additive schema `M7`, version 1, plus M6 `WeaponItems` references. Holds vault, cosmetic unlocks, showcases, guild contribution watermark, trade lineage, pending escrow, private trade history and dormant gifting outbox. |
| `BladeForest_M7_Guilds_v1` | Guild-owned records, member pointer keys and bounded notification inboxes |
| `BladeForest_M7_GuildXP_v1` | Ordered guild XP leaderboard |
| `BladeForest_M7_PublicCards_v1` | Allowlisted public card projections |
| `BladeForest_M7_Trades_v1` | Durable transaction decisions and serialized item identities |

The existing 120 weapon IDs were preserved. Roll back source via the private v60 baseline or original scripts in `ServerStorage.M7Rollback`. Retain existing player and guild records. The runtime stations disappear when the M7 server script is removed from the active tree. If a future build ever enables trading, settle pending escrows before removing its recovery code.

## Verification and outstanding checks

- Studio matched all 19 final sources to repository checksums and compiled them. Initial Play confirmed eight station prompts, both feature flags off, the group encounter entry binder and four-player Expedition capacity.
- The detached suite round-tripped the existing purchase flag, M5 tokens, M6 Awakening and rune socket, and the M7 vault. It rejected duplicate vault deposits, an out-of-range slot, vaulted salvage, favorite weapon trades and equipped pet trades. Guild snapshots gave audit access to the owner and withheld it from members and outsiders.
- The detached synthetic trade exercised first-save acknowledgement, stale expiry, abort, commit, duplicate acknowledgements, repeated settlement and round-trips. Final counts and both original serials matched the commit or abort outcome. The tests did not use real inventory.
- The single Studio client opened the six-tab Social panel, read the allowlisted profile, created and left a party, rejected duplicate creation and solo group launch, and received a disabled response from trade execution.
- Dedicated cross-server transaction testing, purchase-flow and recipient-delivery validation, end-to-end two-to-four-player encounters, guild admission across servers, and mobile QA remain outstanding.
