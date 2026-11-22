# Economy balance report

No economy constants, catalog rarity, published entitlement or paid multiplier changed in this QA batch. The Heart fix changes the fight path for very large hits, and the payout fix applies already implemented eligibility rules at clear.

## Reproduction and evidence

Run `python3 tools/econsim/qasim.py` with NumPy available. This executes the existing M1 simulator with the M5 v2 world inputs and 12 agents per early scenario using seed 811. It re-runs the M5 anchored 200-hour model and the M6 and M8 issuance overlays. The 200-hour progression rows are the historical M2 median anchors and have their original Monte Carlo assumptions. M6 cooperative and M8 progression figures are deterministic overlays. The fixed seed and all assumptions are stored in the tools and checked-in JSON.

| Early scenario | Median 10-minute Logs issued | Median weapon Power | Median Luck | Median Souls |
| --- | ---: | ---: | ---: | ---: |
| Free active | 714,666 | 203 | 1.92 | 145 |
| Free casual | 584,843 | 231 | 1.87 | 118 |
| Free AFK | 623,596 | 231 | 1.88 | 180 |
| Paid active | 13.10M | 293 | 4.82 | 120 |
| Paid AFK | 29.32M | 572 | 5.36 | 180 |

| 200-hour anchor | Median time to Crystal | Median time to Frostbound | Logs issued | Rebirths | Luck |
| --- | ---: | ---: | ---: | ---: | ---: |
| Free active | 0.22h | 6.32h | 0.969T | 28.5 | 4.43 |
| Free casual | 0.38h | 6.43h | 0.715T | 26 | 4.37 |
| Free AFK | 0.37h | 6.40h | 0.540T | 24 | 4.30 |
| Paid active | 0.10h | 3.40h | 2.364T | 36 | 9.06 |
| Paid AFK | 0.07h | 3.38h | 1.495T | 31.5 | 8.85 |
| High-spend active | 0.09h | 1.67h | 4.190T | 40 | 50.00 |

The early simulation's paid modes model paid bonuses; they do not establish the experience of the Starter Pack entitlement used by the isolated Studio account. RNG differences between the small early arms are sizable. The historical 200-hour gates also predate several systems and are not live Frostbound clear times.

## Cross-milestone balance observations

- M1 production rules retain capped temporary bonuses, capped Luck, tier-scaled Logs, priced upgrades and bounded Forest Renewal. Former M1 goldens provide targeted checks. Active and AFK paths remain available under the same reward tables.
- M2 catalog checks cover normalized probabilities and rollable pool membership. Collection time needs full tail Monte Carlo for the 119 free weapon targets and 63 pet forms. The qualification route remains free.
- M3 Mastery, Tech Points, traits and evolved pets need integrated measurements against real time spent on bosses and chopping. The short simulation does not predict full Mastery, trait acquisition or evolution time.
- M5 Contracts, Trials and Expeditions add bounded Sources. M6's earlier free solo model reaches Awakening III at 68 play hours versus 56 in the cooperative scenario. In the M6 overlay, active raid travel and combat displace Logs earning, with modeled free net issuance −3.30% solo and −4.44% cooperative before a rune sensitivity. Active materials and rune supply can still be valuable. Actual boss DPS and clear times are required for re-pricing.
- M8's modeled free active track completes in week 4 at 19.5 hours. Paid active completes in week 3 at 18 hours. The fixed new-player and unattended AFK routes finish at levels 8 and 7. A full season amounts to 2.35 Logs Price Units, 78 Souls, 395 Essence and 1,590 Mastery XP. At the late free baseline unit that is about 0.026% of aggregate modeled 200-hour Logs.
- Before/after configured economy values are identical. Damage behavior, dependent fight times, and replay-safe payouts differ. The QA run does not justify a price change. Next balance capture should record time to real first upgrades, natural gate eligibility, percentiles through Frostbound and median raid time for solo and cooperative groups, then rerun the reward overlay with those times.
