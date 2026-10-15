# Army-first Expedition Polish Implementation Plan

> **For agentic workers:** Use subagent-driven-development for bounded tasks and primary Sol for shared integration. Track checkboxes here; publication requires explicit user authorization (now granted for push, merge and installation).

**Goal:** Make Soulbound's existing army matter visibly from first binding to camp return.
**Architecture:** Army owns transient deed tracking and targeting. Main owns the early soul drop, first-binding presentation and result payload. Existing guidance and town rendering consume those systems without new authoritative rewards.
**Tech Stack:** Godot 4.x, GDScript, existing SceneTree test runner.
**Spec:** `docs/superpowers/specs/2026-10-14-army-first-polish-design.md`

## Global Constraints
- No new dependencies, currencies, classes, save schema, art generation or release changes.
- Preserve Classic balance and unrelated files; isolate QA with local-only override.cfg.
- Workers edit only assigned files, do not dispatch workers, commit or publish.
- All named deeds are mission-earned, and failure/retreat claims must be truthful.
- Delivery is now user-authorized: preserve the default branch's newer features, exclude local QA files, validate the integrated tree, use the existing PR/build/release workflow, and back up the installed app before replacement.

## Review Focus
- Deployed/restored/recruited units must not consume the first natural binding spotlight.
- Packed-array swap removal must carry telemetry with the correct minion.
- Returning veterans' old kills cannot inflate the current mission's story.
- Boss cleanup must clear target priority across deferred node deletion and range limits.
- Missing/malformed legacy report fields must not crash or imply banked failure rewards.

### Task 1: Army telemetry and optional objective priority
**Files:** `scripts/army.gd`, `tools/army_story_test.gd`
**Interfaces:** Produce `soul_bound(kind: String)` for successful soul-funded raises only, `story_report() -> Dictionary`, and `set_priority_target(swarm: EnemySwarm) -> void` (null clears).
Report keys: `raised` (allies rallied this mission), `kills`, `promotions`, `fallen_veterans` (names), `standout` (optional dictionary with `name`, mission `kills`, `rank`, `returning`, `survived`, `close_call`). Track close calls only when alive at <=25% HP. Count restoration neither as a new rally nor a fresh soul binding. Default priority is null; only Swarm prefers an alive reachable priority swarm, within existing sight/leash. All callers remain compatible.
- [x] Write real Army fixture tests for soul-funded versus recruited/restored raises, mission-only returning-veteran deeds, promotion/loss, array swap removal and reachable priority targets.
- [x] Run the test and record the expected missing-behavior failure.
- [x] Implement the minimum runtime state and update hooks.
- [x] Run focused tests and report evidence for independent review.

### Task 2: Camp return recognition
**Files:** `scripts/campaign/campaign_army_story.gd`, `scripts/campaign/campaign_town.gd`, `tools/campaign_army_story_test.gd`
**Interfaces:** Consume optional `report.army_story` with Task 1's shape. Produce `CampaignArmyStory.summary(value: Variant, outcome: String) -> String`; town renders nonempty text near the top of the result screen using existing copy styling. No controller/reward changes.
- [x] Write tests for earned returning/promoted/close-call/surviving/fallen accounts, zero deeds, success/failure/retreat, malformed and legacy payloads.
- [x] Run to verify missing behavior fails, implement helper/UI hook, rerun.
- [x] Add a real town rendering assertion and render a native 720p result fixture.

### Task 3: First binding, guardian tactics and integration (primary Sol)
**Files:** `scripts/main.gd`, `scripts/final_mechanics.gd`, `scripts/campaign/campaign_guidance.gd`, `tools/campaign_first_expedition_test.gd`, `tools/campaign_guidance_test.gd`, `tools/army_first_integration_test.gd`, `tools/run_tests.sh`, `README.md`
**Interfaces:** Connect Task 1's soul_bound signal; add `army_story` to the existing report. Link a campaign-only Army to FinalMechanics; set/clear priority as Lich wards change. Extend guardian_hint compatibly with optional army/key context and derive tips from actual live mechanic state.
- [x] Red tests: once-only normal souls on first opening-route kill; no extra drop with army, restricted trial, later route, boss, or terminal result; spotlight only on a real binding; structured story survives result and settlement; live guardian phase tips/priority/cleanup without auto-switching.
- [x] Implement bounded first-drop and non-pausing spotlight using existing effects/audio; no global balance changes.
- [x] Implement campaign-only targeting link and clear stance opportunities on guard/ward/exposure/seal phase changes.
- [x] Register new suites, run focused then full test runner and smoke bot; inspect rendered first-binding, guardian and camp states.
- [x] Independent cross-family review, fix findings, reverify, document actual evidence/limits and preserve original profiles.

### Final review fix wave
The first stable full run passed 43/43, but independent whole-change review found
three report-producer paths not yet covered. These are completion fixes, not
new gameplay systems or reward changes.
- [x] Share named-loss bookkeeping with Soul Altar sacrifices without triggering Soulfire or duplicate loss signals.
- [x] Count real Soulfire death deltas in the aggregate mission total, without crediting another minion's lifetime deeds.
- [x] Admit real named zero-kill surviving close calls; retain stronger kill-based/fallen candidates and zero-deed silence.
- [x] Observe regression RED/GREEN, scoped independent re-review, and a stable final full-suite pass.

### User-authorized publication and installation
- [x] Commit only feature/source/test/documentation files; exclude override.cfg, .serena, .runtime and review scratch.
- [x] Integrate default 4cbeab7 (PR57) without dropping its world/UI or five-night-system features; inspect merged lifecycle and rerun combined tests/native presentation.
- [ ] Push a feature branch, create a PR against claude/focused-fermat-m7jhtk, wait for required checks and merge without bypassing protections.
- [ ] Wait for all release jobs, verify the Mac asset's commit/SHA-256/archive/signature, back up the current app, then install and verify the matching build while preserving original saves.
