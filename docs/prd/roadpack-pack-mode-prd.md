# RoadPack Pack Mode — Product Requirements Document

**Document Version:** 1.0
**Date:** August 10, 2026
**Author:** Praseeth / Claude
**Status:** Draft for Review
**Classification:** Internal
**Supersedes:** Layer 4 (Convoy & Group Rides) section of `roadpack-v2-prd.md`

---

## 1. Executive Summary

Pack Mode is group ride coordination for RoadPack — live route-relative positioning, rider status broadcast, and link-based joining. It is documented separately from the v2 PRD because it does more than add a feature: **it changes where RoadPack's front door is.**

The v2 PRD (July 7, 2026) positioned convoy as Layer 4, scheduled for Phase 2, framed as retained "convoy DNA" from v1. This document repositions it as the **acquisition layer** — the reason a rider installs RoadPack today, before any crash has happened to them.

The strategic claim is narrow and testable:

> Safety products have no *today* reason to install. Group ride products have no *tomorrow* reason to stay. RoadPack is the only product positioned to have both, because the underlying engine — members projected onto a shared route, anomalous-stop detection, circle notification — is identical for each.

Pack Mode is free, permanently and without gating. It is not a revenue line. It is the distribution mechanism for the safety core that the v2 PRD already specifies, and the retention mechanism for Pack Mode is the daily-commute crash detection RoadPack already ships.

---

## 2. Problem Statement

### 2.1 The Coordination Problem

Riding in a group breaks down the moment the group stops being a group. A rider takes a wrong turn, stops for fuel, or falls behind at a traffic light. The remaining riders are immediately stuck on a decision they have no information to make:

- Do we wait, or do we keep going?
- If we wait, does the rider ahead know we're waiting?
- Is the missing rider stopped by choice, or stopped by a problem?

The larger the group, the worse this scales. Every junction becomes a regroup point, every stop becomes a headcount, and the coordination overhead grows faster than the group does.

### 2.2 How Riders Solve It Today

Primary research (Aug 2026) across rider forums found the problem is **socially solved, not technically solved**:

> "We have a rule of never leaving anyone behind. We always gather and wait at any stop signs or turn offs" — [spyderlovers.com](https://www.spyderlovers.com/threads/group-rides-tail-gunner.119911/)

> "Before taking a turn, make sure he's behind you. Don't see him behind you? Stop, turn around and see what's what." — [twtex.com](https://www.twtex.com/forums/threads/group-riding-etiquette-and-trip-preparation.122774/)

The incumbent stack is lead/sweep discipline + corner marking + hand signals + WhatsApp live location. It works. Riders largely like it. **This must be stated plainly, because it constrains the product:** we are not selling into an unmet screaming need for a pack map.

The cost riders actually complain about is time, not danger:

> "The most annoying thing about larger groups is that every stop takes a LOOONG time."

> "Over 10 and it just gets to be a LOT more work keeping everyone together"

### 2.3 The One Failure Social Protocol Cannot Solve

Lead/sweep discipline has exactly one structural blind spot, and riders name it directly:

> "Too easy for the last one or two riders to drop off because of trouble and go un-noticed" — [spyderlovers.com](https://www.spyderlovers.com/threads/group-rides-tail-gunner.119911/)

The sweep rider cannot see behind himself. If the last rider goes down, the group's detection latency is bounded by the next regroup point — which on a highway stretch can be 20+ minutes.

**This is the seam where Pack Mode and the RoadPack safety core are the same product.** A rider who stops voluntarily taps a status. A rider who crashes taps nothing. RoadPack's existing crash detection engine can write that status on his behalf.

### 2.4 The Acquisition Problem (Why This Layer Exists)

RoadPack v2's core loop is excellent and nearly impossible to sell cold. Nobody wakes up and installs a crash detector for a crash that has not happened. Evidence from the category:

| Company | Outcome | Signal |
|---|---|---|
| Detecht (crash detection + social) | 8 years, 750k downloads, **25k paying subs**, €395k raised | Slow, grinding adoption |
| EatSleepRIDE | Founded 2008, $120k total funding | 18 years, no scale |
| Life360 | $489.5M FY25 — but **crash detection is free** | Safety is the hook, not the product |

Group rides invert the acquisition math. One leader shares a link, 8 riders join, and none of them were shopping for a safety app. The install has a concrete reason to happen *this Saturday*.

### 2.5 The Retention Problem (Why This Layer Cannot Be The Product)

Group rides happen roughly 4× per month. That is not a habit, and the category's history is unambiguous about what happens to companies built on it:

| Company | Outcome |
|---|---|
| REVER | Acquired by Comoto (RevZilla) 2020 — as a **gear retail funnel** |
| Riser | Acquired by Cardo (helmet hardware) 2023 → folded into Cardo Ride Apr 2026 |
| Calimoto | Majority stake to PE roll-up (Russmedia) 2022 |
| Zenly | 35–40M MAU, **shut down by Snap** Feb 2023, buyout offers refused |
| Polarsteps | Profitable — but tracking is **free**; revenue is printed books + affiliate |

**No company has ever monetized convoy tracking directly.** Every survivor attached it to something with marginal cost: gear, hardware, printed goods, roadside assistance.

RoadPack's answer is that the retention layer already exists and already ships. Riders who install for Saturday keep the app because it runs on their Monday commute.

---

## 3. Strategic Rationale

### 3.1 The Loop

```
Convoy (acquisition)  ->  Commute crash detection (retention)  ->  Dispatch/roadside (revenue)
     free forever              free forever                          paid tier
```

Each stage fixes the failure mode of the stage that would otherwise stand alone:

- **Convoy alone** dies of low frequency (4 rides/month is not a habit).
- **Safety alone** dies of cold start (no reason to install today).
- **Together** the install reason is social and immediate; the retention reason is daily and passive.

### 3.2 Why Competitors Cannot Copy the Loop

Copying the pack map is trivial. Copying the loop requires having both halves.

- **Convoy apps** (REVER, Calimoto, Cardo Ride, Pack Ride, Wolfes Club) have no daily-use surface. Nothing keeps the app open between rides.
- **Family safety apps** (Life360) have the daily habit but no cultural or product reason to build convoy — their user is a parent tracking a teen, not a rider leading a pack.
- **Google Maps** holds granted patent [US12018949B2](https://patents.google.com/patent/US12018949) (June 2024) covering navigation "in view of progress of the second user toward the shared destination" — and has shipped nothing in two years. Convoy is a rounding error inside Maps. It is not a rounding error for RoadPack.

### 3.3 The Unclaimed Primitive

Competitive analysis of 12 products (Aug 2026) found that **every one renders positions as dots on a map, and not one computes the gap**:

| Product | Live positions | Gap in km/min | No-install link |
|---|---|---|---|
| REVER (Comoto) | Yes | **No** | PRO only |
| Calimoto | Yes (requires motion) | **No** | No |
| Cardo Ride (ex-Riser) | Yes + fell-behind alert | **Alert only, no number** | PRO |
| Pack Ride | Yes, tail-end flag | Unclear | Public profiles |
| EatSleepRIDE | Yes | **No** | Yes |
| Sena / Cardo hardware | Yes (Wave app) | **No** | No |
| onX Offroad | Yes | **No** | No |
| Polarsteps | Solo only | **No** | Yes |
| WhatsApp / Google Maps / Find My / Glympse | Raw dots | **No** | Glympse only |

Nobody answers *"Ravi is 4.2 km / 7 minutes behind you on the route."* It is an along-route projection problem the category has not bothered to solve.

**Two primitives are unclaimed, and Pack Mode claims both:**

1. **Route-relative gap** — signed distance and time along the shared polyline, not straight-line distance.
2. **Status with intent** — *why* a rider stopped, not just *that* they stopped. Cardo ships a fell-behind alert with no reason attached. Nobody ships intent.

### 3.4 Monetization Position

**Pack Mode is free forever, including the share link and unlimited group size.**

This is a hard constraint, not a launch promo. Every competitor gates group features (Cardo caps free PackRide at 30 minutes; REVER gates share links to PRO). Gating the acquisition loop to protect revenue that does not yet exist is the single most predictable way to kill it.

Revenue remains where the v2 PRD already places it: dispatch, roadside assistance, and premium safety services with real marginal cost — the Life360 pattern.

---

## 4. Product Vision

**One-liner:** Ride together without losing anyone — and if someone does go down, the pack knows before the next regroup.

**North Star Metric (Pack Mode):** Ride-to-retention conversion — % of riders who join a pack ride via link and still have RoadPack active with tracking enabled 30 days later.

Secondary: **Detection latency for a silent dropout** — seconds between a rider's anomalous stop and the pack being notified. Target < 90s. Baseline today (social protocol): bounded by next regroup, commonly 10–25 minutes.

### 4.1 Design Principles (Pack Mode specific)

These extend, and do not replace, the six v2 design principles.

1. **The link is the product.** Joining must require no install, no account, and no app store round trip. Every convoy app that died assumed all participants would install first.
2. **Silence is still the signal.** Manual status covers the boring stops. Automatic status covers the one that matters. A rider who cannot tap is the rider the system exists for.
3. **Never display a number you do not trust.** An off-route or stale rider shows a state, not a distance. A confidently wrong gap is worse than no gap, because the pack acts on it.
4. **Degrade loudly.** When connectivity drops, the UI must say so. A stale dot the pack trusts is the primary safety hazard of this feature.
5. **The pack is not surveillance.** Positions are visible only during an active ride, links expire, and any rider can leave and be removed from the view immediately.

---

## 5. Users

### 5.1 Primary Persona — The Ride Leader

Organises weekend group rides for 6–20 riders. Currently carries the entire coordination burden: pre-ride briefing, route sharing, headcounts at every stop, deciding when to wait. Owns a WhatsApp group he uses as a de facto coordination tool and finds it inadequate mid-ride.

**He is the installer.** Product decisions optimise for his ability to bring 8 people in with one message.

### 5.2 Secondary Persona — The Pulled-In Rider

Joins because the leader sent a link. Has no independent interest in a safety app and will not create an account before Saturday. **Must reach a useful state from a cold link tap.** This rider is the entire acquisition thesis; every point of friction on this path is a direct conversion loss.

### 5.3 Tertiary Persona — The Sweep

Rides last by assignment. Structurally cannot see behind himself and currently absorbs the anxiety of the whole group's tail. Pack Mode's dropout detection is aimed most directly at his job.

### 5.4 Non-User — The Observer

Family member following a long-distance ride from home. Read-only web view, no install. Explicitly served by the same share link with reduced precision. Listed here to prevent the viewer path being designed as an afterthought.

---

## 6. Requirements

Priority: **P0** = required for first shippable Pack Mode. **P1** = required for the loop to actually close. **P2** = deferred.

### 6.1 Ride Lifecycle

| ID | Priority | Requirement |
|---|---|---|
| PM-01 | P0 | A ride leader can create a pack ride from a circle of type `convoy`, or ad hoc without a pre-existing circle. |
| PM-02 | P0 | Creating a ride requires a destination; the shared route is resolved and frozen at creation. |
| PM-03 | P0 | The ride generates a share link with a 128-bit unguessable token. |
| PM-04 | P0 | Riders join via link, notification, or in-app circle invite. |
| PM-05 | P0 | The leader can start the ride; the ride transitions `draft -> active`. |
| PM-06 | P0 | Any member may leave at any time; their position is immediately removed from all views. |
| PM-07 | P0 | The ride ends when the leader ends it, all members arrive, or after a hard timeout (default 12h). |
| PM-08 | P1 | The leader can edit destination or route while the ride is `draft`. |
| PM-09 | P1 | Roles are assignable: `leader`, `sweep`, `rider`. Default sweep = last to join. |
| PM-10 | P2 | Waypoint / regroup-point planning before start. |

### 6.2 Route-Relative Positioning

| ID | Priority | Requirement |
|---|---|---|
| PM-20 | P0 | Each member's position is projected onto the shared route as a distance-along-route value. |
| PM-21 | P0 | The UI shows, for every member, signed gap from the viewer in **both km and minutes**. |
| PM-22 | P0 | Ordering is by route progress — the pack is presented as a sequence, not a scatter of pins. |
| PM-23 | P0 | A member further than a threshold from the route is marked `off_route` and **their gap is suppressed**, not estimated. |
| PM-24 | P0 | A member whose position is older than a staleness threshold is visually marked stale and their gap is suppressed. |
| PM-25 | P1 | Time gaps are derived from the leader's actual breadcrumb history, so they absorb real traffic conditions. |
| PM-26 | P1 | "You are now last on route" state surfaced to the rider and to the sweep. |
| PM-27 | P2 | Turn-by-turn navigation to another member's live position. |

### 6.3 Status Broadcast

| ID | Priority | Requirement |
|---|---|---|
| PM-30 | P0 | A rider can set a status from a fixed set: `riding`, `refueling`, `break`, `wrong_turn`, `waiting`, `stopped`, `done`. |
| PM-31 | P0 | Status changes push to all ride members and are visible without leaving navigation. |
| PM-32 | P0 | Status setting must be operable in ≤2 taps, glove-compatible, with large hit targets. |
| PM-33 | P1 | An optional short free-text note may accompany a status. |
| PM-34 | P1 | Status auto-clears back to `riding` when the rider resumes motion. |
| PM-35 | P2 | Voice-triggered status setting. |

### 6.4 Automatic Status — The Safety Seam

| ID | Priority | Requirement |
|---|---|---|
| PM-40 | **P0** | When RoadPack's crash detection engine registers an impact for a rider in an active pack ride, the system writes an incident status on their behalf and notifies the pack **immediately**, without waiting for the standard cascade countdown to complete. |
| PM-41 | **P0** | A rider stationary beyond a threshold without having set a status is flagged `unexplained_stop` to the pack. |
| PM-42 | P0 | Pack notification of a suspected incident must not suppress, delay, or replace the existing emergency cascade to the rider's emergency contacts. The two run in parallel. |
| PM-43 | P0 | Automatic statuses are visually distinct from manual ones and are never presented as rider-confirmed. |
| PM-44 | P1 | A rider who goes unreachable (no position, no network) beyond a threshold is flagged `unreachable` — distinct from `stopped`. |
| PM-45 | P1 | The nearest pack member to a flagged rider is identified and offered one-tap navigate-back. |

> **PM-40 through PM-45 are the reason this document exists.** Without them Pack Mode is a commodity pack map. With them it is a capability no competitor in the category can reach, because none of them have a crash detection engine, and Google's design assumes a conscious rider with a free hand.

### 6.5 The No-Install Viewer

| ID | Priority | Requirement |
|---|---|---|
| PM-50 | P0 | Tapping a share link in any mobile browser renders a live pack view with **no install and no account**. |
| PM-51 | P0 | The viewer shows route, member positions, ordering, gaps, and statuses. |
| PM-52 | P0 | The viewer prompts to install only *after* delivering value, never as a gate. |
| PM-53 | P0 | Link-only viewers receive coarsened position precision relative to authenticated members. |
| PM-54 | P1 | A link viewer can upgrade to full participant in-place by installing and claiming their slot. |
| PM-55 | P1 | The leader can see viewer count and revoke the link, ending all anonymous access. |

### 6.6 Connectivity Behaviour

| ID | Priority | Requirement |
|---|---|---|
| PM-60 | P0 | Loss of connectivity must be surfaced explicitly in the UI within the staleness threshold. |
| PM-61 | P0 | Positions recorded while offline are queued and synced on reconnect, backfilling the track rather than being discarded. |
| PM-62 | P0 | The rider's own navigation continues to function with no connectivity. |
| PM-63 | P1 | Last-known position and status for every member persist and display with an explicit timestamp when the pack goes dark. |
| PM-64 | P2 | Peer-to-peer proximity detection between nearby pack members without any network. |

> **PM-60 through PM-64 are the competitive moat in India.** Route research found ~85 km of continuous zero-coverage on the Gramphu–Losar stretch, non-local prepaid SIMs deactivated at the Ladakh border, and all high passes dead. Every competitor — including Wolfes Club and the defunct Traeser — assumes connectivity. RoadPack's offline-first principle already forces the correct architecture.

### 6.7 Privacy and Abuse

| ID | Priority | Requirement |
|---|---|---|
| PM-70 | P0 | Position sharing is scoped to the active ride only, and terminates when the ride ends. |
| PM-71 | P0 | Share tokens expire — at ride end, or at a hard TTL, whichever is first. |
| PM-72 | P0 | Leaving a ride removes the member's live position from all views immediately. |
| PM-73 | P0 | Riders are shown who can currently see them, including anonymous link viewers. |
| PM-74 | P0 | No covert participation. A member cannot be in a ride without their device indicating it. |
| PM-75 | P1 | Rides involving members under 18 inherit the existing DPDPA consent constraints from the v2 PRD. |

---

## 7. Key Flows

### 7.1 Leader Creates a Ride

1. Set destination.
2. Choose **Ride Together** (surfaces from an existing convoy circle, or ad hoc).
3. Add members from circles, or skip.
4. Share link — WhatsApp is the expected channel and should be the first-class share target for India.
5. Watch riders join in a lobby state.
6. **Start.**

### 7.2 Pulled-In Rider Joins (The Critical Path)

1. Taps link in WhatsApp.
2. Browser opens live pack view immediately. **Value delivered before any ask.**
3. Prompt: *join as a rider* (install) or *keep watching* (stay in browser).
4. If installing: return to the ride and claim their slot without re-entering the link.

**Every additional step on this path is a direct conversion loss.** This flow is the acquisition thesis in its entirety and should be instrumented at each transition.

### 7.3 John Stops for Fuel

1. John taps `refueling`, 2 taps, gloves on.
2. Pack receives it mid-navigation without leaving the map.
3. Riders ahead see John's gap growing but with a known reason and make an informed wait/continue decision.
4. John resumes; status auto-clears to `riding`.

### 7.4 John Goes Down (Same Mechanism, No Taps)

1. Crash detection registers impact. John taps nothing.
2. Pack sees `possible incident` on John within the staleness threshold — visually distinct from any manual status.
3. Nearest member is identified and offered navigate-back.
4. **In parallel**, the existing emergency cascade fires to John's emergency contacts, unchanged and unblocked.

Steps 1–2 are the same write to the same field as 7.3. That is the merge, expressed in one table column.

---

## 8. Success Metrics

**Acquisition**
- Riders joining per ride created (target: viral coefficient > 1.0 — the loop is self-sustaining only above this)
- Link-tap → install conversion rate
- % of installs originating from a pack ride link vs. all other sources

**Retention (the actual test of the thesis)**
- D30 retention of link-acquired riders **with tracking enabled** — bare app presence does not count
- % of link-acquired riders who complete a solo commute trip within 7 days

**Product**
- Silent-dropout detection latency (target < 90s)
- False `unexplained_stop` rate — must stay low enough that the pack does not learn to ignore it
- % of ride-time where gap numbers are suppressed due to staleness or off-route

**Anti-metrics (watch for harm)**
- Rides where a stale position caused a wrong wait/continue decision
- Battery complaints attributable to pack rides
- Any evidence of Pack Mode being used for non-consensual tracking

---

## 9. Risks

| Risk | Severity | Mitigation |
|---|---|---|
| **The pain is real but socially solved.** Riders may not adopt a tool for a problem lead/sweep already handles. Research found **zero** verbatim "I wish an app did this" for pack position. | **High** | Lead the value proposition on dropout detection, not on the map. Instrument whether status broadcast or gap display drives usage — be willing to learn the map is decorative. |
| **Connectivity kills it on the marquee routes.** Ladakh/Spiti is where the culture and the marketing photos live, and it is where a server-relayed map fails. | **High** | PM-60..64. Ship staleness honesty before shipping polish. Never let the product lie about a position. |
| **Cold start still bites** if the link path has any friction. | **High** | PM-50..54 are P0 for a reason. No-install viewer or the loop does not exist. |
| **Google ships it.** Patent granted 2024, nothing shipped in 2 years. Could change. | Medium | Their design assumes connectivity and a conscious rider. Compete on offline honesty and automatic status, not on the map. |
| **Patent exposure** — US12018949B2 may read on this. | Medium | **Requires patent counsel review before any public launch.** Open item, not resolved by this document. |
| **Scope cost to a solo builder.** Convoy wants connectivity, safety wants offline. | Medium | The engine is shared; the surfaces are not. Ship P0 only, resist the video's full feature set. |
| **Battery.** Pack rides push position more aggressively than commute tracking. | Medium | Batch position sync. Instrument on target budget-Android hardware, not flagships. |
| **India willingness-to-pay is unevidenced.** No research support exists for any price point. | Low (for this doc) | Pack Mode is free by design, so this risk lands on the revenue tier, not here. |

---

## 10. Out of Scope (v1)

- Turn-by-turn navigation to a moving member (PM-27)
- Voice / intercom features — Sena and Cardo own this, and it is hardware
- Peer-to-peer offline mesh (PM-64)
- Waypoint and regroup-point planning (PM-10)
- Ride recording, social feed, route sharing, achievements — the entire REVER/Calimoto surface area
- Any paid Pack Mode tier, ever

---

## 11. Open Questions

1. **Patent review.** Does US12018949B2 read on this implementation? Needs counsel. Blocking for public launch, not for build.
2. **Route source.** Which provider supplies the shared route polyline at ride creation, and what does it cost at scale? See TRD §4.
3. **Off-route threshold.** Is 150 m correct for Indian divided highways with wide medians and parallel service lanes? Empirical, needs road testing.
4. **Does the map matter?** If usage data shows riders use status broadcast and ignore gap numbers, the product should follow the data.
5. **Indian rider voice is unverified.** All primary quotes in §2 are US/UK riders — Reddit, Team-BHP, and xBhp were inaccessible to automated research. **A human should validate §2.2–2.3 against Indian riding groups before P0 scope is locked.**

---

## 12. Appendix — Research Provenance

Competitive and market findings in §2 and §3 come from a 7-agent research sweep run August 10, 2026. Confidence varies by claim; the following are explicitly **unverified**:

- Reddit was inaccessible to all agents. r/motorcycles, r/indianbikes, and r/googlemaps are a complete blind spot.
- Group size caps and battery figures are unpublished by nearly every competitor and would require hands-on testing.
- The Ladakh/Spiti "50–70% of a riding day without usable data" figure is an estimate derived from qualitative route descriptions, not a measured statistic.
- Traeser (2018, India — shipped essentially the v1 RoadPack spec and vanished) could not be confirmed dead. Its store reviews would be a free post-mortem.

Verified with high confidence: competitor feature matrices, acquisition outcomes, Google patent grant, Google Maps current sharing limits, and named route dead zones.
