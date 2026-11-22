# Mobile, server load and performance

## Measurements

All measured results below come from one attached Studio client and one local Studio server. Each frame-time observation used 100 samples. Studio memory reflects the measured Studio environment and can include editor and server resources. The iPhone preset is an emulated viewport on the same desktop. It supplies no physical handset FPS, battery, memory or thermal evidence.

| Sample | Viewport / graphics | Mean frame time | P50 | P95 | Max | Mean FPS | Reported total memory |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Desktop during QA suite work | 957×532 / High | 215.22 ms | 186.47 ms | 338.84 ms | 1,686.94 ms | 4.65 | 6,380 MB |
| Desktop during Timber gameplay | 957×532 / High | 182.25 ms | 173.08 ms | 255.40 ms | 342.09 ms | 5.49 | 6,386 MB |
| iPhone 17 Pro portrait preset during Auto Chop | 401×778 / Low / Reduced Motion | 195.58 ms | 190.57 ms | 319.66 ms | 386.73 ms | 5.11 | 6,440 MB |
| Single-player server heartbeat | Local Studio | 17.42 ms | 16.74 ms | 28.25 ms | 39.94 ms | — | 6,401 MB |

The server sample recorded 300 Starter Grove, 900 Pine Forest, 620 Crystal Wilds and 830 Frost Peaks trees. Timber Haven totals 1,200. The sorted Crystal position digest was `620:1325136453` before gameplay. No tree positions, tree models or camera occlusion code changed in this branch. Streaming was on. A later one-player sample showed an UpdateAsync request budget of 2,882. That is the sandbox budget at one instant. Studio reported 0 receive Kbps and approximately 0.4 Kbps sent in desktop sampling, so these readings are unsuitable for live network sizing.

The portrait preset enabled touch input and exposed 44×44 pixel Social, Seasons and right drawer controls. The Journal's computed bounds were inside the viewport. Automated clicks in device mode did not open the compact drawer, even though Studio returned success. Treat touch activation as unverified. The emulator was returned to default at the end.

## Changes and interpretation

Auto Chop no longer runs a heartbeat just to replicate its UI toggle, and uses weak keys for destroyed targets. Blade visuals share the frame’s movement buffers and one bulk model movement call. The Silvershore Saber replacement has six primitives and no external mesh. These changes target script and asset cost. The measurements above were taken before the blade batching fix. The post-batch Frostbound Low/Reduced Motion sample reported 4.10 FPS, 134.48 ms P50, 628.94 ms P95 and a 4,757 ms spike. It used a different island and test moment, so it establishes no causal speedup.

Desktop Studio frame rates are poor enough to make further performance work a release gate. The profile still needs a targeted rendering and memory capture. The readings were collected on the authoring host, with the full Studio editor and local server in operation. They do not identify an individual system's GPU or memory cost.

## Required physical device and load checks

1. Use a physical iPhone of the intended minimum tier and a representative Android device in a separately approved test environment. Record OS, Roblox version, thermal state and connection. Use a separate desktop observer and confirm all JobIds.
2. Run 60-second stationary and moving samples from each island’s arrival and busy forest, then trials, parties and the Heart. Run Default, Low/Battery Saver and Reduced Motion at the same sample positions. Record cold join time, P50/P95/P99 frame time, memory, ping, streaming stalls and sustained battery state.
3. In portrait and landscape open and close Upgrades, Roll, Pets, Traits, Travel, Mastery, Adventures, Forge, Social and Seasons using the physical touch surface. Check notch and home indicator clearance, compact drawer activation, visible text sizes, camera obstruction, tree labels, weapon and pet VFX, and boss telegraph legibility.
4. Stage 2, 4, 10 and 20 actual clients. Test simultaneous spawn slots, Auto Chop supply, hit replication, regeneration, raid and guild settlement, streaming and DataStore budgets. Keep counts separate from any synthetic allocation stress.

For local multiplayer only, choose **Server & Clients** in Studio's testing mode dropdown, set the client count to **2**, and press **Play**. Use the separate QA profile mode in the authorized private editor. Local Studio clients share one simulated server, so they do not establish hosted cross-server evidence. [Roblox Studio testing modes](https://create.roblox.com/docs/studio/testing-modes)
