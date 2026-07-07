# RoadPack v2 — Product Requirements Document

**Document Version:** 2.0 (Enhanced)
**Date:** July 7, 2026
**Author:** Praseeth / Claude
**Status:** Draft for Review
**Classification:** Internal
**Supersedes:** v1.0 (July 7, 2026)

## Document Control

| Version | Date | Changes |
|---|---|---|
| 1.0 | 2026-07-07 | Initial draft |
| 2.0 | 2026-07-07 | Added: goals & non-goals, assumptions/constraints register (incl. Google Play SMS policy, DPDPA minor-consent, ERSS API reality), requirement IDs with MoSCoW priorities and acceptance criteria, degraded-operation matrix, anti-abuse & safeguarding design, crash-detection testing methodology, legal & liability section, unit economics, phase exit criteria, expanded data model (consent, audit, devices), glossary. Corrected: client-side SMS architecture, 112 integration claims, licensing costs, MVP timeline. |

---

## 1. Executive Summary

RoadPack v2 is an India-first road safety platform that combines real-time commute tracking, automatic crash detection, family safety circles, and group ride coordination into a single mobile application. It is designed to work within the constraints of Indian road infrastructure — patchy connectivity, two-wheeler dominance, underfunded emergency services, and the cultural dynamics of how Indian families, institutions, and communities respond to road emergencies.

The original RoadPack (2024) was a convoy tracking app for bikers — live map, group ride coordination, Firebase + Flutter. v2 retains the convoy DNA but pivots the core mission from recreational group tracking to saving lives on Indian roads.

India reports the highest number of road accident deaths of any country globally. Official figures document over 1.77 lakh deaths in 2024, with real numbers estimated at nearly double. Two-wheeler riders account for ~45% of all fatalities, and the 18–45 age group accounts for ~66.5% of victims — students, daily commuters, young professionals. Only ~20% of accident victims reach medical care within the golden hour, and ambulance coverage in many regions is as low as 1 per 80,000–100,000 people. *(Figures from MoRTH annual reports and press coverage; verify and cite the specific report editions before any external use of this document.)*

The core thesis: **if the app knows where you are, where you're going, and who cares about you, it can close the gap between a crash and the moment help arrives — even when the victim can't call for help themselves.**

What v2 of this document adds beyond the product idea: an honest constraints register (platform policy, regulatory, and telecom realities that shape the architecture), testable requirements, a safety-case mindset (degraded modes, false negatives, liability), and safeguards against the ways location products get misused.

---

## 2. Problem Statement

### 2.1 The Incident That Reignited This Project

On July 6, 2026, Rahul S., a 7th-semester Mechanical Engineering student, died on the spot in a road accident at Peruvamuzhy, near Muvattupuzha, while commuting to college. His co-passenger Julian sustained injuries and was admitted to MOSC Medical College. The college learned about it through a phone call, suspended classes, and sent buses home.

This is not an outlier. This happens 480+ times a day across India.

### 2.2 The Systemic Failures

**Failure 1: Nobody knew in real-time.** Rahul's family, friends, and college had no automated awareness that he was in trouble. The information propagated through phone calls — minutes to hours after the event.

**Failure 2: Emergency response depends on the victim calling.** India's 112 ERSS handles 8+ lakh calls daily, but as stated by the ERSS Commissioner for Maharashtra: "We only help the people who can call us." Unconscious victims can't dial.

**Failure 3: Bystanders hesitate.** Despite the Good Samaritan protections (Section 134A, Motor Vehicles Act as amended in 2019), most bystanders at Indian accident scenes don't know they're legally protected, don't know who to call, and don't know which hospital is closest.

**Failure 4: No product serves this market.** Life360, OtoZen, FamiSafe, and GeoZilla are designed primarily for Western markets — US emergency numbers, assumptions about LTE coverage, car-centric crash detection, subscription pricing in USD. Google Pixel's crash detection works in India but is limited to Pixel phones. There is no India-native, two-wheeler-aware, offline-resilient safety platform that works on a ₹10,000 Android phone over Jio's network on a Kerala state highway.

### 2.3 The Opportunity

- 260 million registered two-wheelers in India
- 750 million smartphone users, majority Android, majority budget devices
- A large share of mobile usage in rural/highway corridors occurs on degraded (2G/3G) or no data connectivity
- Zero dominant player in the Indian road safety app space
- Government actively seeking technology solutions (MoRTH Crash Data Portal / iRAD-eDAR, state road safety authorities such as KRSA, PM RAHAT-style schemes)
- Supreme Court and MoRTH pressure on golden-hour compliance — creating institutional demand for solutions

### 2.4 What the Product Cannot Fix (Honesty Clause)

RoadPack shortens the *awareness gap* — the time between an incident and the first human knowing. It does not dispatch ambulances, does not guarantee detection of every crash, and does not replace 112. Every design, marketing, and legal decision in this document flows from stating that boundary clearly rather than implying more than the product can deliver. See §14 (Legal & Liability).

---

## 3. Goals and Non-Goals

### 3.1 Goals

| ID | Goal | Measure |
|---|---|---|
| G1 | Reduce time-to-first-human-aware after an incident | North Star: < 2 minutes (vs. 15–45 min phone-call chain today) |
| G2 | Work reliably on budget Android + degraded networks | All critical paths function offline / SMS-only |
| G3 | Be trusted enough to stay installed | Day-30 retention > 40%, battery complaints < 10% |
| G4 | Be safe to use — no new harms | Zero tolerated covert-tracking pathways; incident-gated PII exposure |
| G5 | Preserve the original convoy community | Convoy features fully carried forward and upgraded |

### 3.2 Non-Goals (Explicitly Out of Scope)

- **Not an ambulance dispatch service.** RoadPack alerts humans and surfaces 112/108; it does not itself dispatch responders.
- **Not a navigation app.** No turn-by-turn routing; map is for situational awareness.
- **Not a driver-behavior scoring/insurance telematics product at launch.** Safety score is informational; insurance integration is Phase 3+, opt-in, and never affects free safety features.
- **Not a parental surveillance tool.** No covert mode, no stealth tracking, no keystroke/app monitoring. See §9 (Anti-Abuse).
- **Not iOS-first.** Android-first; iOS follows in Phase 4 with a *reduced* feature set dictated by platform constraints (§4.2).
- **No dashcam / video recording at launch.**

---

## 4. Assumptions, Dependencies & Constraints

This section exists because several v1 features assumed capabilities that platforms and regulators do not actually permit. Each constraint below has a design consequence noted inline.

### 4.1 Platform Policy Constraints (Android / Google Play)

| # | Constraint | Consequence for RoadPack |
|---|---|---|
| C1 | **Google Play restricts `SEND_SMS` / `READ_SMS` permissions** to default SMS handler apps, with a narrow exception process. An app that silently sends SMS from the device will be rejected or removed. | The device→server "location over SMS" uplink in v1 must be redesigned: (a) apply for the Play emergency/safety exception with documentation, (b) fall back to *user-initiated* SMS intents (pre-filled message, user taps send), and/or (c) offer a sideloaded/OEM-partner build with full SMS capability for institutional deployments. **All emergency alerts to contacts are dispatched server-side (MSG91/Exotel) and are unaffected.** The gap is only the uplink when the *victim's* phone has zero data. |
| C2 | **Background location on Android requires `ACCESS_BACKGROUND_LOCATION`**, a Play policy review, prominent disclosure, and in-app rationale. Approval is granted for safety use cases but the review adds 2–4 weeks. | Bake the disclosure flow into onboarding; budget review time into Phase 1 schedule; prepare the Play policy declaration early. |
| C3 | **OEM battery killers** (MIUI, ColorOS, FunTouch, One UI) aggressively kill background services regardless of permissions. | Foreground service with persistent notification during active commute; per-OEM guidance flows; measure "tracking survival rate" as a first-class metric (§16). |
| C4 | **Lock-screen UI:** apps cannot arbitrarily draw over the lock screen. | Bystander mode uses: (a) foreground-service notification with emergency actions, (b) full-screen intent during an *active incident* (permitted for emergencies), (c) user-set lock-screen wallpaper/widget with QR as an opt-in. Not a persistent always-on takeover. |
| C5 | **Apps cannot programmatically place a call to 112** without user confirmation (`CALL_PHONE` to emergency numbers is restricted). | All 112 interactions are one-tap *dial intents* (user confirms). Automated voice calls go to *emergency contacts* via cloud telephony (Exotel), which is server-side and unrestricted. |

### 4.2 iOS Constraints (for Phase 4 planning)

- No app-initiated SMS without user interaction; no volume-button trigger interception; no lock-screen widgets with arbitrary actions (Live Activities are the closest analogue); background location is workable but stricter. **iOS parity is therefore explicitly "reduced parity": server-side cascade, circles, live map, SOS, and commute intelligence port cleanly; hardware triggers and bystander lock-screen mode do not.** Document this now so "iOS feature parity" in the roadmap is not over-promised.

### 4.3 Regulatory & Telecom Constraints (India)

| # | Constraint | Consequence |
|---|---|---|
| C6 | **DPDPA 2023 — children.** Processing a minor's (<18) personal data requires *verifiable parental consent*, and tracking/behavioural monitoring of children is prohibited (subject to exemptions the government may notify for safety purposes — none confirmed as of this writing). A large fraction of "college commuter" persona users are 17. | **Age gate at signup.** Under-18 flow requires verifiable parental consent (parent completes consent via their own verified phone/OTP + declaration); the parent is auto-added as circle admin. Track DPDPA rule notifications — if safety-app exemptions are notified, relax accordingly. Legal review before pilot. This is a launch blocker, not a nice-to-have. |
| C7 | **TRAI DLT registration.** All A2P SMS templates must be pre-registered on DLT platforms; sender IDs and templates take days–weeks to approve; transactional/service-implicit category needed for emergency SMS to avoid promotional throttling and NDNC blocking. | Register entity, headers, and all alert templates (including variable placeholders) during Phase 1 week 1–2. Emergency SMS templates go in the *service-implicit/transactional* category. Keep templates stable; template changes re-trigger approval. |
| C8 | **112 ERSS has no public third-party app API.** Android's Emergency Location Service (ELS) operates at OS level; state ERSS integrations are via MoUs, not open APIs. | v1's "automatic location sharing where the API supports it" is rewritten: RoadPack provides one-tap dial to 112 + on-screen coordinates/address the caller can read out + (Phase 3) pursue a formal MoU with Kerala ERSS/KRSA for a data-sharing pilot. No claim of automatic 112 data push until an MoU exists. |
| C9 | **DPDPA generally** — consent records, purpose limitation, data principal rights (access, correction, erasure, grievance), breach notification to the Data Protection Board. | Consent ledger in the data model (§12.8), privacy dashboard in-app, deletion pipeline, appoint a grievance officer; DPO when scale/notification demands. |
| C10 | **Telemedicine/first-aid content** shown to bystanders must be generic, sourced from recognized guidelines (e.g., basic "do not move, check breathing, control bleeding"), and carry a "not medical advice" notice. | Content reviewed by a medical advisor before Phase 1 ship. |

### 4.4 Commercial Dependencies

| Dependency | Note |
|---|---|
| `flutter_background_geolocation` (Transistor) | **Commercial license** — per-app fee (order of a few hundred USD, one-time per major version, per platform). Budget it; evaluate open alternatives (`geolocator` + custom foreground service) as fallback if licensing terms change. |
| Mapbox offline tiles | Priced per tile request / MAU at scale; for pre-cached corridor tiles, evaluate **OpenStreetMap + self-hosted tile bundles (Protomaps/PMTiles)** as the zero-marginal-cost option for offline packs, with Google Maps for online display. |
| MSG91 / Exotel | DLT-dependent (C7). Negotiate priority routes for emergency traffic; contractually confirm delivery SLAs. |
| Hospital data (NHA / state health dept) | Public datasets are incomplete and go stale; assume a manual verification effort for the pilot district (Ernakulam) and crowd-sourced corrections thereafter. |

### 4.5 Assumptions to Validate in Pilot

- A1: Students will keep always-on location enabled for a safety benefit (validate: tracking opt-out rate < 20%).
- A2: Parents without smartphones can act on SMS alerts (validate: SMS acknowledgment flow comprehension in Malayalam).
- A3: Rule-based crash detection can reach < 5% false-positive *alert dispatch* rate (post-countdown) on two-wheelers (validate in Phase 2 field trial).
- A4: A phone survives a two-wheeler crash intact often enough to be the sensor (literature suggests body/pocket-carried phones usually survive; handlebar-mounted phones are at higher risk — measure in pilot; the Phase 4 beacon exists because this assumption is imperfect).

---

## 5. Product Vision

**One-liner:** RoadPack is your road companion that watches your back — so you reach home safe, and if you don't, the people who love you know immediately.

**North Star Metric:** Minutes between incident and first alert reaching an emergency contact. **Measurement definition:** timestamp delta between `incidents.created_at` and the first `incident_alerts.delivered_at` (any channel), reported as median and p95 across real (non-cancelled) incidents. Today's baseline (phone-call chain) is estimated at 15–45 minutes; target < 2 minutes.

**Design Principles:**

1. **Silence is the signal.** The app's most important feature is detecting when something goes wrong, not requiring the user to tell it. A phone that stops moving on a highway is more informative than a panic button the user can't reach.
2. **Offline-first, always.** Every critical path — crash detection, alert dispatch, emergency info display — must work without data connectivity, degrading gracefully (see the degraded-operation matrix, §10).
3. **Low-end device, low battery drain.** If it kills the battery on a Redmi Note by noon, students will uninstall it. Aggressive optimization for background location with intelligent duty cycling.
4. **Community, not surveillance.** The app should feel like a group of friends watching out for each other, not a tracking tool. Privacy controls are granular, defaulted to the most restrictive useful setting, and *covert tracking is architecturally impossible* (§9).
5. **India-native.** Regional languages, 112 awareness, Indian road types (NH, SH, district roads, ghat roads), hospital databases, legal context (Good Samaritan notice for bystanders).
6. **Never over-claim.** The product, its marketing, and its UI never imply guaranteed detection or guaranteed rescue. Trust in a safety product is destroyed by one broken promise.

---

## 6. Target Users

### 6.1 Primary Personas

**Persona 1: The College Commuter (Rahul)**
- Age 17–24 (note: under-18s trigger the DPDPA parental-consent flow, C6), commutes daily on a two-wheeler
- Budget Android phone (₹8,000–₹15,000), prepaid Jio/Airtel SIM
- Routes predictable (home → college → home), timing semi-regular
- Parents worry but don't want to "track" — they want to know he arrived safely
- Rides in groups sometimes, solo most days
- Connectivity: urban areas fine, stretches between towns are patchy

**Persona 2: The Worried Parent (Rahul's Mother)**
- Age 40–55, may or may not be technically proficient
- Wants a simple answer: "Has my child reached college? Are they safe?"
- Doesn't want to constantly check — wants to be alerted only when something is wrong
- Needs Malayalam/Hindi/Tamil, not just English
- May not have a smartphone (feature-phone SMS fallback critical — the **Observer** role, §7.2)

**Persona 3: The Group Rider (Weekend Biker)**
- Age 22–35, rides in groups on weekends, sometimes long-distance
- Wants convoy coordination — who's ahead, who's behind, who stopped
- Values safety features as an add-on to the group ride experience
- This is the original RoadPack user, now with safety upgrades

**Persona 4: The Institutional Admin (College Transport Officer)**
- Manages awareness of student commute safety
- Wants aggregate dashboards — alerts when a student in their circle hasn't arrived, not individual tracking
- Compliance and liability considerations for the institution
- Could be a college, corporate office, or delivery fleet

### 6.2 Secondary Personas

- **Elderly family member** passively covered by children (falls, non-arrival)
- **Solo female commuter** wanting a safety layer with SOS to trusted contacts
- **Delivery rider / gig worker** whose employer wants safety monitoring (consent rules apply — §9.3)
- **Tourist / pilgrim** on unfamiliar roads (Sabarimala, Leh–Manali, etc.)
- **The Bystander** — not a user at all; a stranger at a crash scene who interacts with the victim's phone for 90 seconds. Design for them explicitly (§7.5.4).

### 6.3 Anti-Persona (Design Against)

- **The Coercive Tracker** — a partner, relative, or employer who wants to monitor someone covertly or under duress. Every sharing feature must be visible to the person being tracked, revocable without notification-suppression tricks, and auditable. See §9.

---
## 7. Feature Specification

Features are organized into six layers. **Every requirement now carries an ID and a MoSCoW priority** (M = Must for MVP, S = Should, C = Could, W = Won't-for-now), so the phased rollout (§15) can trace to requirements and QA can trace to acceptance criteria.

- **Layer 0 — Identity & Circles:** accounts, family/group circles, permissions, consent
- **Layer 1 — Live Tracking & Commute Intelligence:** real-time location, route learning, ETA
- **Layer 2 — Safety & Detection:** crash detection, inactivity alerts, SOS
- **Layer 3 — Alert & Response:** multi-channel notification, bystander UI, emergency info
- **Layer 4 — Convoy & Group Rides:** evolved RoadPack convoy features
- **Layer 5 — Institutional & Analytics:** dashboards, aggregate safety insights, API

### 7.1 Layer 0 — Identity & Circles

#### 7.1.1 User Onboarding

| ID | Requirement | Priority |
|---|---|---|
| FR-001 | Phone number OTP authentication (primary identity) | M |
| FR-002 | Optional email link for account recovery | S |
| FR-003 | **Age gate**: date-of-birth capture; under-18 users routed to verifiable parental-consent flow (parent verifies own phone via OTP + consents; parent auto-added as Family circle admin) | M |
| FR-004 | Minimal onboarding: name, phone, ≥1 emergency contact enforced before tracking activates | M |
| FR-005 | Language selection: Phase 1 English + Hindi + Malayalam; Phase 2 Tamil, Kannada, Telugu; Phase 3 Marathi, Bengali, Gujarati | M (Phase 1 set) |
| FR-006 | Permissions walkthrough with plain-language rationale per permission (location-always, motion, notifications), including the Play-mandated prominent disclosure for background location (C2) | M |
| FR-007 | Bystander/emergency screen requires no signup (§7.5.4) | M |

**Acceptance criteria (FR-003):** an account with DOB < 18 years cannot enable location tracking until a parental-consent record exists (§12.8); consent record stores parent identity, method, timestamp; consent is revocable, and revocation disables tracking within 24 h.

#### 7.1.2 Safety Circles

A circle is a group of people who share location and safety status with each other. Conceptually similar to Life360's circles but designed around Indian social structures.

**Circle Types:**

| Type | Description | Example | Max Members |
|---|---|---|---|
| Family | Core family unit, highest trust | Parents + children | 15 |
| Friends | Peer group, selective sharing | College friend group | 25 |
| Commute | Route-based, institutional | "MEC Muvattupuzha — S7 ME" | 100 |
| Convoy | Temporary, ride-specific | "Munnar Weekend Ride" | 50 |

**Circle Permissions Matrix (defaults; member can restrict further, never be forced looser):**

| Permission | Family | Friends | Commute | Convoy |
|---|---|---|---|---|
| Live location (continuous) | ✓ | Configurable | During commute only | During ride only |
| Crash/SOS alerts | ✓ | ✓ | ✓ | ✓ |
| Arrival/departure notifications | ✓ | Configurable | ✓ | N/A |
| Speed visibility | Configurable | ✗ | ✗ | ✓ |
| Location history (24h) | ✓ | ✗ | ✗ | ✗ |
| Battery level | ✓ | ✗ | ✗ | ✓ |

| ID | Requirement | Priority |
|---|---|---|
| FR-010 | Create circle → share invite link (WhatsApp-native share) | M |
| FR-011 | Roles: Admin, Member, **Observer** (receives alerts/SMS, never shares own location — for feature-phone parents) | M (Observer: M) |
| FR-012 | Leave circle anytime with confirmation; leaving notifies the circle (no silent membership) | M |
| FR-013 | Circle-level mute for non-emergency notifications (X hours); emergency alerts are never mutable | M |
| FR-014 | **Sharing transparency:** a permanent "Who can see me" screen lists every circle, every member, and exactly what each can see; a recurring (monthly) in-app reminder summarizes active sharing | M |
| FR-015 | Joining a Commute (institutional) circle requires explicit member opt-in with a plain-language summary of what the institution sees (aggregates only) | M |

#### 7.1.3 Emergency Profile

| ID | Requirement | Priority |
|---|---|---|
| FR-020 | Emergency contacts: min 1, max 5, priority-ordered; each with name, phone, relationship, alert-method cascade preference | M |
| FR-021 | Medical info (optional, prompted): blood group, allergies, medications, conditions, insurance | S |
| FR-022 | Vehicle info (optional): type, registration, color | C |
| FR-023 | ICE card auto-generated from the above; exposed via bystander mode **only during an active incident or active commute (user-configurable)** — never a static always-scannable QR (privacy: prevents casual PII harvesting) | M |
| FR-024 | Emergency contacts receive a one-time SMS informing them they've been listed, with opt-out — required for consent hygiene and to pre-verify numbers before an emergency | M |

### 7.2 Layer 1 — Live Tracking & Commute Intelligence

#### 7.2.1 Background Location Engine

The most critical technical component: balance accuracy, battery, and reliability on low-end devices.

**Duty Cycling Strategy:**

| State | GPS Interval | Accuracy | Battery Impact | Trigger |
|---|---|---|---|---|
| Stationary | Off (cell/geofence only) | ~500m | Negligible | No motion 5 min |
| Walking | 30 s | ~50m | Low | Activity: on_foot |
| Riding (commute) | 5 s | ~10m | Medium | Activity: in_vehicle on known route |
| Riding (convoy) | 2 s | ~5m | Higher | User-activated convoy mode |
| SOS / incident active | 1 s | ~3m | Maximum | Crash detected or SOS |

| ID | Requirement | Priority |
|---|---|---|
| FR-030 | On-device activity recognition (stationary/walking/riding) from accelerometer + gyroscope; no cloud dependency | M |
| FR-031 | Duty-cycled GPS per state table; foreground service with persistent notification during active tracking (C3) | M |
| FR-032 | Geofence-based wake around home/college/waypoints using OS geofencing | M |
| FR-033 | Adaptive interval: reduce frequency on straight highway segments, increase on ghat/turn-dense segments | S |
| FR-034 | Battery target: < 5%/hour in commute mode on Snapdragon 680-class device (measurement protocol: 1-hour scripted ride loop, screen off, airplane-mode variants; tracked per release) | M |
| FR-035 | User-visible battery attribution ("RoadPack used 8% today") | S |
| FR-036 | Per-OEM battery-optimization guidance flows (MIUI/ColorOS/One UI), dontkillmyapp-style; **tracking survival rate** instrumented (heartbeat gap analysis) | M |

#### 7.2.2 Commute Intelligence

| ID | Requirement | Priority |
|---|---|---|
| FR-040 | Route learning: after 3–5 repetitions, a commute becomes a "known route" (origin, destination, geometry, typical start ±window, typical duration, active days) | M |
| FR-041 | Manual route definition supported; multiple routes per user | M |
| FR-042 | Non-arrival alert: expected-arrival + configurable delay (10/15/30 min, default 15) → notify Family circle | M |
| FR-043 | Escalation: first a gentle push to the *user* ("Everything okay?"); no response in 5 min → alert circle via push, then SMS/call cascade | M |
| FR-044 | One-tap "I'm running late" dismissal (snoozes alerts 30/60 min) | M |
| FR-045 | Holiday/weekend awareness (day-of-week pattern + one-tap "not going today" + optional academic calendar import) | S |

**Acceptance criteria (FR-042/043):** with a simulated known route (typical arrival 08:15, delay 15 min), no location at destination by 08:30 triggers user check-in; no user response by 08:35 dispatches circle push and SMS to priority-1 contact; all events appear on the incident timeline; a false alarm cancelled by the user suppresses re-alerts for that commute instance.

#### 7.2.3 Live Map

| ID | Requirement | Priority |
|---|---|---|
| FR-050 | Real-time positions of circle members; tap member → speed, heading, battery %, last-update age, ETA | M |
| FR-051 | Dark-mode-default, minimal map style | S |
| FR-052 | Offline map tiles pre-downloaded for known routes + 5 km buffer (self-hosted OSM/PMTiles bundles preferred for cost — §4.4) | M |
| FR-053 | Stale-position honesty: positions older than 60 s are visually greyed with "last seen X min ago" — never present stale data as live | M |

### 7.3 Layer 2 — Safety & Detection

#### 7.3.1 Crash Detection Engine

The hardest and most important technical challenge. Must run on-device, in real time, with a false-positive rate low enough to preserve trust — and with its *false-negative* limits stated honestly (§14).

**Sensor Fusion Inputs:** accelerometer (impact/deceleration), gyroscope (tumble/roll), barometer (falls from elevation), GPS (speed at impact, sudden stop), microphone (opt-in impact sound signature), activity state (was the user riding?).

**Detection Logic (on-device):**

*Phase A (Rule-based MVP):*
- Trigger if: peak acceleration > threshold (initial 4g, tuned in field trials — pocket-carried vs handlebar-mounted phones see very different signatures; mount position captured in onboarding) AND speed > 20 km/h within last 10 s AND orientation change > 90° within 2 s
- Suppress: known rough segments (crowd-sourced pothole DB), speed-bump zones, phone-drop signatures (no prior vehicle speed), within 50 m of home/office geofence at low confidence

*Phase B (ML, TFLite):*
- Train on public crash sensor datasets + synthetic augmentation + consented real-world RoadPack data (especially cancelled-detection labels)
- Two-wheeler-specific model: lower vehicle mass, tumble patterns, frequent low-speed drops that are not crashes
- Federated learning for model improvement without raw data leaving the device (Phase 4)

| ID | Requirement | Priority |
|---|---|---|
| FR-060 | Rule-based on-device detection per above; fully offline | M (Phase 2) |
| FR-061 | 30-second full-screen countdown with loud alarm and large cancel; works over lock screen via full-screen intent (C4) | M (Phase 2) |
| FR-062 | Cancelled detections logged (opt-in sensor snapshot) with reason picker (pothole/speed bump/phone drop/other) — the labelled training set | M (Phase 2) |
| FR-063 | Sensitivity settings: Low / Medium (default) / High; High selectable only by the device owner, not remotely by a circle admin (anti-coercion) | M (Phase 2) |
| FR-064 | ML model (TFLite) replacing/augmenting rules | S (Phase 3) |
| FR-065 | **Known-limitations disclosure** in-app: detection can miss crashes (phone destroyed, unusual signatures, phone not on person); shown at feature activation and in marketing claims review | M |

**Acceptance criteria (FR-060/061):** on the replay test harness (§13.4), the rule engine fires on ≥ 90% of labelled crash traces in the validation set and on < 1% of labelled normal-riding traces; countdown cancellation prevents any external alert; countdown expiry dispatches the cascade within 5 s.

#### 7.3.2 SOS — Manual Emergency Trigger

| ID | Requirement | Priority |
|---|---|---|
| FR-070 | In-app SOS button, accessible from every screen; long-press 2 s to arm (accidental-trigger prevention) | M |
| FR-071 | 5-second cancellable countdown (shorter than crash flow — intent is explicit) | M |
| FR-072 | On dispatch: capture GPS, speed, heading, timestamp; opt-in 10 s audio and camera capture | M (capture: S) |
| FR-073 | Continuous 1 s location streaming to emergency contacts until resolved | M |
| FR-074 | Home-screen widget one-tap SOS | S |
| FR-075 | Hardware trigger: volume-up ×5 while app/service alive (best-effort on Android; documented as unavailable on iOS) | S |
| FR-076 | Voice trigger ("RoadPack emergency"), on-device wake word | C (Phase 4) |

#### 7.3.3 Inactivity Detection — the Silent Signal

| Scenario | Detection | Response | ID / Priority |
|---|---|---|---|
| Phone stops moving on a road | No GPS change 3+ min, last speed > 15 km/h, not near a known stop | Vibrate + "Are you stopped? Tap to confirm you're okay"; no response in 2 min → treat as low-confidence incident, notify circle | FR-080 / M (Phase 2) |
| Commute interrupted | Significant deviation from known route + stopped | Gentle check-in notification | FR-081 / S |
| Didn't start commute | Usually departs 7:30; no movement by 8:00 on an active day | Soft self-only prompt: "Skipping today?" one-tap yes | FR-082 / S |
| Phone unreachable | No server heartbeat 15+ min during active commute | Circle alert: "Lost contact with [name] at [last known location]" — worded as *lost contact*, never implying a crash | FR-083 / M (Phase 2) |

#### 7.3.4 Bystander Mode

If someone finds an accident victim's phone, the app should help them help — within what the platform allows (C4).

| ID | Requirement | Priority |
|---|---|---|
| FR-090 | During an **active incident**, the phone shows a full-screen (over lock screen) bystander interface: "This person may need help" | M (Phase 2; Phase 1 ships notification-action variant) |
| FR-091 | Bystander actions, no unlock required: one-tap dial 112 (user-confirmed dial intent, C5); one-tap dial emergency contact 1; nearest trauma-capable hospital with directions | M |
| FR-092 | Good Samaritan notice: "You are legally protected for helping (Section 134A, Motor Vehicles Act)" in local language + English | M |
| FR-093 | Basic first-aid guidance (medically reviewed, C10): do not move the person; check breathing; apply pressure to bleeding; "not medical advice" notice | M |
| FR-094 | ICE QR (blood group, contacts, conditions) exposed **only** during active incident or, if the user opts in, during active commute — never permanently (FR-023) | M |
| FR-095 | Optional printed/laminated helmet-sticker QR linking to a *server-held* ICE page that activates only during incidents — covers the destroyed-phone case | C (Phase 3) |

### 7.4 Layer 3 — Alert & Response

#### 7.4.1 Multi-Channel Alert Cascade (server-side)

All emergency alerts to contacts are dispatched **server-side** — the victim's phone needs to get one small incident packet to the backend (data, or the constrained SMS uplink per C1), and the cloud does the rest. This is deliberate: the weakest link should never be the victim's phone plan.

**Cascade per contact (orchestrated by the queue, §11):**
1. **Push** (if contact has the app) — instant
2. **SMS** — +5 s, sent regardless of push outcome (DLT transactional template, C7)
3. **Automated voice call** — +30 s after SMS, TTS in the contact's language: "This is an emergency alert from RoadPack. [Name] may have been in an accident at [location]. Please check on them or call 112."
4. **WhatsApp Business API** — parallel to SMS (Phase 3)

| ID | Requirement | Priority |
|---|---|---|
| FR-100 | Cascade engine with per-channel status tracking (queued/sent/delivered/read/failed) and retries with exponential backoff + hard caps | M |
| FR-101 | **Acknowledgment loop:** any contact can acknowledge via app tap, SMS reply (e.g., "OK"), or IVR keypress during the automated call; first acknowledgment is broadcast to all channels ("[Father] has seen the alert") | M |
| FR-102 | **Terminal escalation:** if *no* contact acknowledges within 10 min, re-run cascade at next-priority contacts, alert all circles, and (institutional users) escalate to institution admin; final state surfaces prominent "Call 112 now" guidance to every recipient — the cascade must never dead-end silently | M |
| FR-103 | Alert content includes: name, location (address/landmark + maps link), time, speed at incident, nearest hospital (name/distance/phone), victim's number, 112 guidance — phrased as "**may** have been in an accident" | M |
| FR-104 | Feature-phone SMS format ≤ 2 SMS segments, tested in Malayalam/Hindi transliteration | M |

**Alert content (app/push/WhatsApp):**
```
🚨 EMERGENCY ALERT — RoadPack
[Name] may have been in an accident.

📍 Location: [Address / Landmark]
🗺️ Map: [link]
🕐 Time: [Timestamp]
🚗 Speed at incident: [X] km/h
🏥 Nearest hospital: [Name], [Distance], [Phone]

Call 112 for emergency services.
Call [Name]: [Number]
Reply OK to confirm you've seen this.
```

**SMS format (feature phones):**
```
ROADPACK ALERT: [Name] accident at [Location].
Map: [short URL]. Hospital: [Name] [Phone].
Call 112. Call [Name]: [Number]. Reply OK.
```

#### 7.4.2 Emergency Services Integration

| ID | Requirement | Priority |
|---|---|---|
| FR-110 | One-tap dial to 112 with on-screen readable coordinates + nearest landmark (no automatic data push claim — C8) | M |
| FR-111 | Hospital finder: pre-cached offline database (NHA + state health data + manual verification for pilot district) with type (PHC/CHC/District/Medical College/Private), trauma level, verified phone, distance and ETA from incident | M |
| FR-112 | Police station finder (FIR requirements under MV Act) | S |
| FR-113 | 108/102 ambulance integration via state APIs/MoU where available (Kerala: GVK EMRI) | C (Phase 4, MoU-dependent) |
| FR-114 | Hospital data staleness controls: "last verified" surfaced, crowd-flagging of wrong numbers, quarterly verification sweep for pilot geography | M |

#### 7.4.3 Incident Timeline

Every alert produces a real-time, shared, timestamped timeline visible to all circle members (and exportable):

```
7:32 AM — Crash detected at Peruvamuzhy, Muvattupuzha–Thodupuzha road
7:32 AM — 30-second countdown started
7:33 AM — No response. Emergency alerts dispatched.
7:33 AM — Push sent to [Mother], [Father], [Friend]
7:33 AM — SMS sent to [Mother]
7:34 AM — Automated call to [Mother]
7:35 AM — [Father] opened alert in app
7:38 AM — [Mother] acknowledged via SMS reply
```

| ID | Requirement | Priority |
|---|---|---|
| FR-120 | Timeline auto-generated from incident + alert events; live-updating; reduces the "who knows what" chaos of fragmented calls | M |
| FR-121 | Timeline export (PDF/share) for FIR/insurance/institutional records | S |

### 7.5 Layer 4 — Convoy & Group Rides

The evolved original RoadPack, integrated into the safety platform.

| ID | Requirement | Priority |
|---|---|---|
| FR-130 | Convoy creation: name, date/time, route (start → waypoints → destination); join via WhatsApp link/QR; auto-expiry after ride | M (Phase 2) |
| FR-131 | Roles: Lead (sets pace/route), Sweep (tail confirmation), Rider | M (Phase 2) |
| FR-132 | Live convoy map: positions, speed, heading, spacing to rider ahead/behind | M (Phase 2) |
| FR-133 | Regrouping-point pins by Lead | S |
| FR-134 | **Rider-down alert:** any member's crash detection alerts the whole convoy immediately with location — often the fastest responders are 200 m behind | M (Phase 2) |
| FR-135 | Straggler detection: rider > X km behind sweep → alert Lead | S |
| FR-136 | Fuel/rest-stop voting | C |
| FR-137 | Weather alerts along route (rain/fog) | C (Phase 3) |
| FR-138 | Speed-limit display for current segment | C |
| FR-139 | Post-ride summary: route map, elevation, distance, duration, avg/max speed, safety score (informational only — see Non-Goals), shareable ride card | S |

### 7.6 Layer 5 — Institutional & Analytics

| ID | Requirement | Priority |
|---|---|---|
| FR-150 | Web dashboard for institutions: aggregate commuter status ("32 of 45 in S7 ME have arrived"), **never individual coordinates** | M (Phase 3) |
| FR-151 | Institutional escalation: emergency-contact non-response 10 min → institution admin alerted (with the member's prior consent, FR-015) | M (Phase 3) |
| FR-152 | Anonymized historical analytics: commute patterns, peak risk hours, common routes, incident summaries | S |
| FR-153 | Compliance/audit reports for institutional safety audits | S |
| FR-154 | Black-spot identification from clustered crash detections + hard-braking events; approaching-black-spot rider alerts | S (Phase 3) |
| FR-155 | Road-condition crowd-sourcing (potholes, hazards) — doubles as crash-detection suppression data | S (Phase 3) |
| FR-156 | Anonymized, aggregated, opt-in data sharing with KRSA/MoRTH (institutional goodwill + partnership path) | S (Phase 3) |
| FR-157 | REST API for third parties: insurance (opt-in), fleet systems, emergency providers, smart-city platforms | C (Phase 4) |

---

## 8. Critical User Journeys (End-to-End)

Written as testable scenarios; QA and demo scripts derive from these.

**J1 — The Journey That Motivated the Product.** Rahul, 20, commutes 7:10 AM on a known route. At 7:32 his phone registers 5.2g deceleration at 52 km/h with a 140° orientation change. Full-screen countdown blares for 30 s; no response. Incident packet reaches the backend over a 2G data sliver. Server cascade: push to father (app user), SMS to mother's feature phone (Malayalam transliteration), automated Malayalam voice call to mother at +35 s. Father acknowledges in-app at 7:35. Timeline shows every step. A bystander picks up the phone: full-screen bystander UI — dials 112, sees MOSC Medical College 4.2 km with phone number, sees Good Samaritan notice. **Elapsed time from impact to first family awareness: under 3 minutes.**

**J2 — The False Positive.** Priya's phone flies off her scooter's cup holder over a speed bump at 28 km/h. Countdown fires; she pulls over and cancels at second 12, tags "phone drop." No alert leaves the device. The labelled trace uploads that night on Wi-Fi (she opted in), improving the model. Her trust is intact because *nobody was alarmed*.

**J3 — The Silent Non-Arrival.** Arun's known arrival is 8:15. At 8:30 he hasn't arrived (bike breakdown, phone in bag, no crash). His phone prompts him first — he taps "I'm running late." Family sees a calm "Arun is running late" note instead of an emergency. No cry-wolf.

**J4 — The Feature-Phone Mother.** Leela owns a ₹1,500 Nokia. She is an Observer in the Family circle: she receives arrival SMS daily ("Rahul reached college 8:12"), and in an emergency receives the SMS + automated Malayalam voice call, and can acknowledge by replying OK. She never installs anything.

**J5 — The Coercion Attempt.** A controlling partner adds his girlfriend to a Family circle and sets her crash sensitivity to High remotely. He cannot: sensitivity is device-owner-only (FR-063). She sees him listed in "Who can see me" (FR-014), gets the monthly sharing summary, and leaves the circle; he is notified she left (no silent membership, FR-012) but cannot re-add her without a fresh invite acceptance. She can also report the circle. The product refuses to be a stalking tool.

**J6 — Rider Down in a Convoy.** On a 14-bike Munnar ride, rider #9 low-sides on a wet hairpin. His crash detection fires; after countdown, every convoy member gets a rider-down alert with a pin. Riders #10–11, ninety seconds behind, are first on scene. The sweep marks the incident acknowledged; the family cascade proceeds in parallel.

---

## 9. Anti-Abuse & Safeguarding Design

Location products cause real harm when misused. These are product requirements, not policies.

| ID | Requirement |
|---|---|
| SG-01 | **No covert mode, ever.** Tracking is always visible: persistent notification during active tracking; "Who can see me" screen (FR-014); monthly sharing summaries. Rejecting stealth is a stated brand position. |
| SG-02 | Being added to any circle requires the addee's explicit acceptance. No one can be placed in a circle by someone else unilaterally (parental-consent minors' Family circle is the sole, disclosed exception). |
| SG-03 | Leaving is always possible and takes effect immediately; the app never offers "prevent member from leaving." |
| SG-04 | Remote configuration of another member's device settings (sensitivity, tracking intervals) is not possible (FR-063 generalized). |
| SG-05 | Employer/gig-work deployments (secondary persona) require the worker's individual in-app consent, visible tracking windows (shift-bounded), and the same aggregate-only dashboard rules as colleges. |
| SG-06 | In-app reporting for coercion/abuse concerns with a documented support runbook; safety-relevant reports reviewed within 24 h. |
| SG-07 | Data minimization: default 7-day location history (configurable 1–30), auto-purge; incident data retained longer only for the incident record itself. |
| SG-08 | Bystander/ICE PII exposure is incident-gated (FR-023/FR-094). |

---

## 10. Degraded-Operation Matrix

A safety product must define exactly what still works when things fail. This matrix is normative — each cell is a requirement.

| Condition | Crash detection | Alert to contacts | Live map to circle | Bystander mode | Hospital finder |
|---|---|---|---|---|---|
| Full data (4G/5G) | ✓ on-device | ✓ full cascade | ✓ realtime | ✓ | ✓ online + cache |
| Degraded data (2G/3G) | ✓ | ✓ (packet is tiny; cascade is server-side) | Delayed, stale-marked (FR-053) | ✓ | ✓ cached |
| **No data, SMS possible** | ✓ | Constrained uplink: Play-exception build sends automated SMS to backend longcode; standard build presents **one-tap user-confirmed SMS** during countdown/SOS; if user unconscious and no exception build → alert fails upstream, mitigated by FR-083 (server-side lost-contact detection during active commute) | ✗ (last known position shown, stale-marked) | ✓ (fully offline) | ✓ (offline DB) |
| No connectivity at all (dead zone) | ✓ (queues incident locally) | Deferred until any connectivity; meanwhile FR-083 lost-contact alert fires from the server side after 15 min | Last-known only | ✓ | ✓ |
| Phone destroyed in crash | ✗ (known limitation, FR-065) | FR-083 lost-contact path is the only signal; Phase 4 beacon addresses directly | Last-known | Helmet-sticker QR (FR-095) | n/a |
| Battery < 10% | Reduced duty cycle; circle notified of low battery (Family permission) | ✓ | Reduced frequency | ✓ | ✓ |
| App killed by OEM | ✗ until relaunch | FR-083 catches prolonged silence during an expected commute | ✗ | ✗ | n/a |

Design consequence made explicit: **server-side lost-contact detection (FR-083) is the universal backstop** for every failure mode where the phone cannot speak. It must therefore be Phase 2, not a nice-to-have.

---
## 11. Tech Stack & Architecture

### 11.1 Why Not Pure Firebase Again

The original RoadPack used Firebase (Auth + Firestore + Realtime DB). For a safety-critical app with continuous location writes from potentially millions of users, pure Firebase has three problems:

1. **Cost:** Firestore charges per read/write. Continuous location updates from 100K users at 5-second intervals ≈ 1.2 million writes per minute. Financially unsustainable.
2. **Geospatial limitations:** no native geospatial queries (nearest hospital, users within radius); GeoFirestore workarounds are hacky and expensive.
3. **Server-side logic:** cascade orchestration, SMS/call dispatch, acknowledgment loops, and institutional dashboards need a real backend, not Cloud Functions bolted on.

### 11.2 Recommended Stack

#### Client (Mobile App)
| Component | Choice | Rationale |
|---|---|---|
| Framework | **Flutter 3.x** | Known stack, mature, single codebase, strong background-service support |
| State Management | **Riverpod** | Scales better than Provider; good DI |
| Local DB | **Drift (SQLite)** | Offline-first storage: routes, contacts, cached maps metadata, queued incidents/locations |
| Background Location | **flutter_background_geolocation** (Transistor) — *commercial license, budgeted (§4.4)*; fallback plan: geolocator + custom foreground service | Best-in-class background location, activity recognition, geofencing, battery handling |
| On-Device ML | **TFLite via tflite_flutter** | Crash model runs locally, zero cloud dependency |
| Maps (online) | **Google Maps Flutter** primary + **Mappls** fallback | Mappls has stronger Indian address/landmark data |
| Maps (offline) | **Self-hosted OSM tile bundles (PMTiles/Protomaps)** | Zero marginal cost for pre-cached route corridors; Mapbox only if the DX gap justifies its per-MAU pricing |

#### Backend
| Component | Choice | Rationale |
|---|---|---|
| Primary Backend | **Supabase** (self-hosted or cloud) | Postgres + PostGIS, RLS, Realtime, Edge Functions, Auth |
| Database | **PostgreSQL 16 + PostGIS** | Native geospatial indexing; nearest-hospital and radius queries; partitioned time-series location data |
| Realtime | **Supabase Realtime** (WebSocket) | Live location streaming, incident timeline updates |
| Push | **FCM** | Most reliable Android push in India, even on aggressive OEM skins |
| SMS | **MSG91** (India-native, DLT-compliant, cheaper) + Twilio international fallback; **inbound longcode/shortcode** for SMS acknowledgments (FR-101) and the exception-build SMS uplink | DLT templates registered week 1–2 (C7) |
| Voice (automated) | **Exotel** or Knowlarity | India-native cloud telephony, TTS, IVR keypress capture for acknowledgments |
| Storage | **Supabase Storage** (S3-compatible) | Incident media |
| Task Queue | **BullMQ + Redis** | Cascade orchestration (push → +5s SMS → +30s call), retries, backoff, hard caps |
| API layer | **Node.js (Fastify)**, self-hosted alongside Supabase | Alert routing, acknowledgment webhooks (MSG91/Exotel callbacks), institutional API |

#### Infrastructure
| Component | Choice | Rationale |
|---|---|---|
| Hosting | **AWS Mumbai (ap-south-1)** or DigitalOcean Bangalore | Latency + data residency |
| CDN | **Cloudflare** | Map tiles, static assets |
| Monitoring | **Sentry** (app) + **Grafana/Prometheus** (backend) + **synthetic canary**: a scripted fake incident runs hourly through the full cascade against test numbers; alerting pages on-call if any channel fails | You cannot discover the alert pipeline is broken *during* a real crash |
| CI/CD | GitHub Actions → Fastlane | Automated build/test/deploy |

### 11.3 Key Architecture Decision: Location & Incident Data Flow

```
User's Phone (GPS + sensors)
    │
    ├──► Local SQLite (always — offline buffer, 24h capacity)
    │
    ├──► Supabase Realtime (when online — live to circle members)
    │         └──► PostGIS location_history (partitioned)
    │
    ├──► Incident packet (crash/SOS) ──► Backend ──► BullMQ cascade
    │        (tiny payload — designed to squeeze through 2G)         │
    │                                                                ├─► FCM push
    │                                                                ├─► MSG91 SMS (DLT template)
    │                                                                ├─► Exotel TTS call + IVR ack
    │                                                                └─► WhatsApp (Phase 3)
    │
    └──► SMS uplink (no-data fallback):
             exception build: automated SMS → longcode → backend parses as incident
             standard build: user-confirmed one-tap SMS (C1)
         Backstop for unconscious-user + no-data: server-side lost-contact (FR-083)
```

Crash detection is entirely on-device. The backend's job begins when an alert needs the world.

### 11.4 Incident Packet Design (2G-survivable)

The single most important payload in the system. Target < 300 bytes: user id, incident type, lat/lon (fixed-point), speed, heading, confidence, timestamp, battery. Retried aggressively across transports (HTTPS → plain TCP keepalive channel if HTTPS handshake fails on hostile networks → SMS uplink). Everything else (sensor snapshots, media) syncs later.

---

## 12. Data Model (Core Entities)

### 12.1 Users

```sql
users (
    id                UUID PRIMARY KEY,
    phone             VARCHAR(15) UNIQUE NOT NULL,
    name              VARCHAR(100) NOT NULL,
    date_of_birth     DATE NOT NULL,               -- age gate (FR-003)
    language          VARCHAR(5) DEFAULT 'en',
    blood_group       VARCHAR(5),
    medical_notes     TEXT,                        -- encrypted at rest (app-layer)
    vehicle_type      VARCHAR(20),
    vehicle_reg       VARCHAR(20),
    phone_mount       VARCHAR(20),                 -- pocket / handlebar / bag (crash-model feature)
    crash_sensitivity VARCHAR(10) DEFAULT 'medium',
    is_minor          BOOLEAN GENERATED ALWAYS AS (date_of_birth > now() - interval '18 years') STORED,
    created_at        TIMESTAMPTZ,
    last_seen_at      TIMESTAMPTZ
)
```

### 12.2 Circles

```sql
circles (
    id           UUID PRIMARY KEY,
    name         VARCHAR(100) NOT NULL,
    type         VARCHAR(20) NOT NULL,   -- family / friends / commute / convoy
    created_by   UUID REFERENCES users,
    invite_code  VARCHAR(12) UNIQUE,
    max_members  INT,
    settings     JSONB,                  -- alert prefs, default permissions
    created_at   TIMESTAMPTZ,
    expires_at   TIMESTAMPTZ             -- convoy auto-cleanup
)

circle_members (
    circle_id    UUID REFERENCES circles,
    user_id      UUID REFERENCES users,
    role         VARCHAR(20),            -- admin / member / observer
    permissions  JSONB,                  -- member-side restrictions only (never loosened remotely, SG-04)
    accepted_at  TIMESTAMPTZ NOT NULL,   -- explicit acceptance (SG-02)
    joined_at    TIMESTAMPTZ,
    PRIMARY KEY (circle_id, user_id)
)
```

### 12.3 Emergency Contacts

```sql
emergency_contacts (
    id           UUID PRIMARY KEY,
    user_id      UUID REFERENCES users,
    name         VARCHAR(100) NOT NULL,
    phone        VARCHAR(15) NOT NULL,
    relationship VARCHAR(30),
    priority     INT,                    -- 1 = first
    alert_method VARCHAR(20)[] DEFAULT '{push,sms,call}',
    notified_at  TIMESTAMPTZ,            -- one-time "you've been listed" SMS (FR-024)
    opted_out    BOOLEAN DEFAULT false,
    is_app_user  BOOLEAN DEFAULT false,
    app_user_id  UUID REFERENCES users
)
```

### 12.4 Location History

```sql
-- Partitioned by day; retention job enforces user's window (SG-07)
location_history (
    id            BIGSERIAL,
    user_id       UUID NOT NULL,
    point         GEOGRAPHY(POINT, 4326) NOT NULL,
    speed         REAL, heading REAL, accuracy REAL, altitude REAL,
    battery_level SMALLINT,
    activity      VARCHAR(20),           -- stationary / walking / riding
    source        VARCHAR(10),           -- gps / network / fused
    recorded_at   TIMESTAMPTZ NOT NULL,
    synced_at     TIMESTAMPTZ,
    PRIMARY KEY (id, recorded_at)
) PARTITION BY RANGE (recorded_at);
```

### 12.5 Known Routes

```sql
known_routes (
    id               UUID PRIMARY KEY,
    user_id          UUID REFERENCES users,
    name             VARCHAR(100),
    origin           GEOGRAPHY(POINT, 4326),
    destination      GEOGRAPHY(POINT, 4326),
    route_geometry   GEOGRAPHY(LINESTRING, 4326),
    typical_start    TIME,
    typical_duration INTERVAL,
    days_active      INT[],
    confidence       REAL,
    repetition_count INT,
    last_traveled    TIMESTAMPTZ
)
```

### 12.6 Incidents & Alerts

```sql
incidents (
    id               UUID PRIMARY KEY,
    user_id          UUID REFERENCES users,
    type             VARCHAR(20) NOT NULL,  -- crash_detected / sos / inactivity / non_arrival / lost_contact
    severity         VARCHAR(10),
    confidence       REAL,                  -- detection confidence (for lost_contact/inactivity wording)
    location         GEOGRAPHY(POINT, 4326),
    speed_at_event   REAL,
    sensor_data      JSONB,
    status           VARCHAR(20),           -- detected / countdown / cancelled / dispatched / acknowledged / escalated / resolved
    cancelled_reason VARCHAR(50),           -- pothole / speed_bump / phone_drop / false_alarm
    media            JSONB,
    created_at       TIMESTAMPTZ,
    first_ack_at     TIMESTAMPTZ,           -- North Star numerator
    resolved_at      TIMESTAMPTZ
)

incident_alerts (
    id              UUID PRIMARY KEY,
    incident_id     UUID REFERENCES incidents,
    contact_id      UUID,
    channel         VARCHAR(10),   -- push / sms / call / whatsapp
    status          VARCHAR(20),   -- queued / sent / delivered / read / failed
    sent_at         TIMESTAMPTZ,
    delivered_at    TIMESTAMPTZ,
    acknowledged_at TIMESTAMPTZ,
    ack_method      VARCHAR(10),   -- app / sms_reply / ivr
    error           TEXT
)
```

### 12.7 Hospitals & Emergency Services

```sql
hospitals (
    id            UUID PRIMARY KEY,
    name          VARCHAR(200) NOT NULL,
    location      GEOGRAPHY(POINT, 4326),
    address       TEXT,
    phone         VARCHAR(15)[],
    type          VARCHAR(30),      -- phc / chc / district / medical_college / private
    trauma_level  VARCHAR(10),
    has_emergency BOOLEAN DEFAULT true,
    state         VARCHAR(50), district VARCHAR(50),
    verified_at   TIMESTAMPTZ,
    flag_count    INT DEFAULT 0,    -- crowd-flagged wrong data (FR-114)
    source        VARCHAR(50)
);
CREATE INDEX idx_hospitals_location ON hospitals USING GIST (location);
```

### 12.8 Consent, Devices & Audit (new in v2)

```sql
consents (
    id            UUID PRIMARY KEY,
    user_id       UUID REFERENCES users,
    consent_type  VARCHAR(40) NOT NULL,   -- tracking / data_sharing_anon / sensor_upload / parental / institutional_circle / audio_capture
    granted_by    UUID REFERENCES users,  -- parent for minors (FR-003)
    method        VARCHAR(20),            -- in_app / otp_verified / paper
    granted_at    TIMESTAMPTZ NOT NULL,
    revoked_at    TIMESTAMPTZ,
    version       VARCHAR(10)             -- consent-text version (DPDPA evidence, C9)
)

devices (
    id             UUID PRIMARY KEY,
    user_id        UUID REFERENCES users,
    fcm_token      TEXT,
    oem            VARCHAR(30), os_version VARCHAR(20), app_version VARCHAR(20),
    battery_opt_disabled BOOLEAN,         -- did the user complete the OEM walkthrough (FR-036)
    last_heartbeat TIMESTAMPTZ            -- drives FR-083 lost-contact detection
)

audit_log (
    id          BIGSERIAL PRIMARY KEY,
    actor_id    UUID, subject_id UUID,
    action      VARCHAR(50),              -- circle_join / circle_leave / permission_change / data_export / data_delete / sensitivity_change
    detail      JSONB,
    created_at  TIMESTAMPTZ
)  -- backs SG-01..SG-06 and DPDPA data-principal rights
```

---

## 13. Non-Functional Requirements

### 13.1 Performance

| Metric | Target |
|---|---|
| Crash detection → first alert dispatched | < 40 s (30 s countdown + ≤ 10 s packet + dispatch) |
| Incident packet delivery on 2G | < 8 s p95 (packet < 300 bytes, §11.4) |
| Location update → circle visibility | < 2 s (LTE), < 10 s (3G) |
| App cold start → usable | < 3 s on Snapdragon 680 |
| Background battery drain | < 5%/hour commute mode (protocol per FR-034) |
| Offline location buffer | 24 h |
| SMS alert delivery | < 10 s (MSG91 priority transactional route) |
| Automated call connect | < 45 s from dispatch |

### 13.2 Reliability

- **Uptime:** 99.9% for the alert dispatch pipeline; the pipeline is the product.
- **Synthetic canary:** hourly fake incident exercised end-to-end (push + SMS + call to test numbers); any channel failure pages on-call (§11.2). A safety system whose failures are discovered by victims has already failed.
- **Crash detection works offline:** on-device, zero server dependency.
- **At-least-one-channel guarantee:** cascade design ensures data-push, SMS, and voice are independent failure domains (different vendors, different networks).
- **Queue resilience:** exponential backoff with hard caps (never call someone 50 times); dead-letter queue with human review.
- **Sync integrity:** offline-buffered locations sync without loss; server timestamp wins on conflict; incident packets are idempotent (client-generated UUID).

### 13.3 Privacy & Security

- AES-256 at rest (field-level for medical notes), TLS 1.3 in transit; Supabase RLS as defense-in-depth so a leaked anon key exposes nothing cross-user.
- Location retention: 7-day default, 1–30 configurable, auto-purge (SG-07).
- **No location data sold or shared with third parties — ever.** Brand promise; Life360's data-selling history is a competitive vulnerability to exploit loudly.
- Anonymized aggregates only to road-safety authorities, explicit opt-in, k-anonymity floor (no aggregate published from < 20 users / < 50 trips).
- Right to access/correct/delete (DPDPA): one-action full deletion; grievance officer named in-app (C9).
- Institutional dashboards mathematically cannot render individual positions (aggregate queries only at the API layer, not merely hidden UI).
- Threat model maintained as a living doc: covered adversaries include abusive circle member (§9), stolen phone (ICE gating), server breach (RLS + field encryption), SMS spoofing of the acknowledgment longcode (sender verification + incident-scoped ack codes).

### 13.4 Testing & Validation Strategy (new in v2 — how you QA a crash detector)

1. **Sensor replay harness:** record raw sensor streams (accel/gyro/baro/GPS) from rides; unit-test the detection engine by replaying labelled traces. Every model/rule change runs the full corpus in CI. Detection quality is a regression-tested number, not a vibe.
2. **Lab surrogates:** phone-drop rigs, bicycle/scooter low-speed drop tests with instrumented dummies or weighted sleds for impact signatures; barometer tests on stairwells/overpasses.
3. **Field trial (Phase 2):** 50–100 pilot riders in shadow mode — detection runs and logs but does not alert externally for the first 2 weeks; compare against self-reported events; graduate to live alerts when false-positive dispatch rate < 5% and shadow recall on reported events ≥ target.
4. **Cascade chaos testing:** deliberately fail MSG91/Exotel/FCM in staging; verify channel independence and terminal escalation (FR-102).
5. **OEM matrix:** physical test devices covering Xiaomi/Redmi (MIUI), Realme/Oppo (ColorOS), Vivo (FunTouch), Samsung (One UI) — the tracking-survival metric per OEM gates each release.
6. **Language QA:** every alert string reviewed by native speakers; SMS segment counts verified per language.

### 13.5 Accessibility

- Minimum 14sp fonts in safety-critical UI (SOS, countdown, bystander screen); bystander screen high-contrast and sunlight-readable.
- Haptics on all safety interactions; full screen-reader support; countdown alarm audible over helmet/traffic noise (tested at 85 dB ambient).
- Plain language everywhere; no jargon in user-facing text.

---

## 14. Legal, Liability & Trust (new in v2)

A product that families rely on in life-and-death moments carries obligations v1 did not address.

1. **The false-negative problem.** Some crashes will not be detected (phone destroyed, atypical signature, app killed by OEM). The gravest reputational and legal scenario is a family believing "the app would have told us." Mitigations: FR-065 in-product limitation disclosure; marketing claims never say "detects crashes," always "can detect many crashes"; terms of service state the app supplements, never replaces, 112 and personal vigilance.
2. **Terms of Service & disclaimers** drafted with Indian counsel before pilot: no warranty of detection or delivery; not a medical device; not an emergency service; limitation of liability to the extent Indian consumer law permits (noting consumer-protection limits on such clauses — get real legal advice, this document is not it).
3. **Alert wording discipline:** every automated message says "**may** have been in an accident." The system reports signals, not conclusions.
4. **Incident data as evidence:** timelines and location data may be sought for FIRs, insurance, or litigation. Define a lawful-request policy (respond only to valid legal process), user notification where lawful, and the export feature (FR-121) so users control their own records first.
5. **Medical content review** (C10) and Good Samaritan text verified against current Section 134A language.
6. **Insurance partnerships (Phase 3)** must be opt-in, with an explicit wall: safety-feature behavior and data never feed premium decisions without separate consent; being uninsurable must never degrade safety features.
7. **DPDPA program:** consent ledger (§12.8), privacy notice in all supported languages, grievance officer, breach-notification runbook, DPO when scale demands.

---

## 15. Monetization Strategy

### 15.1 Core Principle

**Safety features are never paywalled.** Crash detection, SOS, emergency alerts, and basic circle tracking are free, forever. Paywalling safety is both morally wrong and commercially stupid — it caps the network effect that makes the app valuable.

### 15.2 Revenue Streams

| Stream | Description | Timeline |
|---|---|---|
| **Freemium (individuals)** | Free: 2 circles, 3 emergency contacts, 7-day history, crash detection, SOS, full cascade. Premium (₹99/mo or ₹799/yr): unlimited circles, 5 contacts + extended cascade, 30-day history, ride analytics, convoy extras | Launch (or post-pilot — Open Question Q3) |
| **Institutional subscriptions** | College/corporate dashboard, bulk onboarding, admin controls, aggregate analytics. ₹5,000–₹25,000/mo by seat count | Phase 3 |
| **Insurance partnerships** | Opt-in usage-based programs; referral revenue share. Firewalled from safety features (§14.6) | Phase 3 |
| **Anonymized data licensing** | Road-condition, black-spot, traffic-pattern aggregates to government/urban planners/automotive. Opt-in, k-anonymized (§13.3) | Phase 3 |
| **Hardware accessories** | BLE crash beacon (solves the destroyed-phone false negative), smart-helmet integration, handlebar SOS button | Phase 4 |

### 15.3 Unit Economics Sanity Check (new in v2)

Per real incident, worst case: ~5 contacts × (1 SMS ≈ ₹0.15–0.25 DLT transactional + 1 automated call ≈ ₹0.35–0.60/min ≈ ₹1) ≈ **₹6–8 per incident** — negligible. The real cost drivers are *routine* SMS: arrival notifications to feature-phone Observers (1–2 SMS/day/observer ≈ ₹10–15/month/observer) and OTPs. Controls: arrival SMS is a configurable digest for free tier (or premium perk), push-first for app users, and per-user monthly SMS budget alarms. Voice-call spend is capped by the cascade's hard retry limits. Conclusion: freemium can plausibly carry emergency traffic for free users; the routine-SMS budget is the line item to watch from day one.

---

## 16. Competitive Positioning

| Feature | RoadPack v2 | Life360 | Google Personal Safety | Apple Crash Detection | HelpQR |
|---|---|---|---|---|---|
| India-native | ✓ | ✗ (US-centric) | Partial (Pixel only) | ✗ (iPhone only) | ✓ |
| Two-wheeler crash detection | ✓ (purpose-built) | ✗ | Partial (car-tuned) | ✗ (car-tuned) | ✗ |
| Works on ₹10K Android | ✓ | ✓ | ✗ | ✗ | ✓ |
| Offline / SMS fallback | ✓ (server-side cascade + offline detection) | ✗ | ✗ | Limited | ✓ (SMS) |
| Group ride / convoy | ✓ | ✗ | ✗ | ✗ | ✗ |
| Bystander activation | ✓ (incident-gated) | ✗ | ✗ | Medical ID (limited) | ✓ (core feature) |
| Institutional dashboard | ✓ | ✗ | ✗ | ✗ | ✗ |
| Regional Indian languages | ✓ | ✗ | Partial | Partial | ✗ |
| Anti-stalking design | ✓ (no covert mode, §9) | Weak (history of data selling) | n/a | n/a | n/a |
| Commute intelligence | ✓ | Partial (places) | ✗ | ✗ | ✗ |
| Price | Free core + ₹99/mo premium | Free + $8–25/mo | Free (Pixel) | Free (iPhone) | Free |

**Positioning statement:** RoadPack is the safety layer Indian roads don't have — built for two-wheelers, for ₹10K phones, for patchy connectivity, and for the reality that when someone crashes on a Kerala highway at 7 AM, the system should know before anyone has to make a phone call.

**Moat honesty:** if Google ships two-wheeler-tuned crash detection to all Android phones, the detection feature commoditizes. The durable moats are the *circle/alert-cascade network* (feature-phone parents included), the institutional layer, the convoy community, and India-specific response intelligence (hospitals, languages, 112 workflow) — invest accordingly.

---

## 17. Phased Rollout

Each phase now has **exit criteria** — the phase is not done when the features ship; it's done when the criteria hold.

### Phase 0 — Compliance Runway (Weeks 1–3, parallel with Phase 1 start)
- DLT entity/header/template registration (C7); Play background-location declaration prep (C2); Play SMS-exception application drafted (C1); DPDPA counsel review of minor-consent flow (C6); ToS/privacy notice drafts (§14); medical review of first-aid content (C10).
- **Exit:** DLT templates approved; legal sign-off on consent flow and disclaimers.

### Phase 1 — MVP (Weeks 1–12)
**Goal:** ship the thing that would have mattered on July 6, 2026 — awareness and cascade, before automatic detection.

Deliverables: OTP auth + age gate + emergency contacts (FR-001..007, 020..024); Family circle + Observer role (FR-010..015); background tracking with duty cycling + OEM guidance (FR-030..036); live map + offline tiles (FR-050..053); route learning + non-arrival alerts (FR-040..045); manual SOS (FR-070..073); server-side cascade with acknowledgment + terminal escalation (FR-100..104); ICE card + notification-variant bystander mode (FR-090..094 Phase-1 form); offline hospital DB for Ernakulam, manually verified (FR-111, 114); English + Malayalam + Hindi; synthetic canary live.

**Deliberately excluded from MVP:** automatic crash detection (Phase 2 — it needs the field-trial rigor of §13.4; shipping a half-tuned detector in the MVP would burn trust exactly when the product needs it most).

**Pilot:** 50–100 users, Ernakulam/Muvattupuzha, college students + families.
**Exit criteria:** North Star measurable end-to-end on staged incidents (< 2 min median); cascade delivery ≥ 99% in canary over 2 weeks; tracking survival ≥ 90% on pilot OEM mix; D30 retention ≥ 40% in pilot; zero unresolved coercion reports.

### Phase 2 — Detection & Convoy (Weeks 13–24)
Rule-based crash detection with shadow-mode graduation (§13.4.3); countdown + cancel + false-positive labelling (FR-060..063, 065); inactivity + lost-contact backstop (FR-080, 083); full-screen bystander mode (FR-090); convoy mode + rider-down (FR-130..135); Friends + Commute circles; Tamil/Kannada/Telugu; battery optimization pass.
**Exit:** false-positive *dispatch* rate < 5%; shadow-mode recall ≥ 90% on labelled traces; convoy rider-down validated on ≥ 3 real group rides; battery ≤ 5%/hr verified per protocol.

### Phase 3 — Intelligence & Scale (Weeks 25–36)
ML detection model (FR-064); institutional dashboard + escalation (FR-150..153); WhatsApp channel; road-condition crowd-sourcing + black spots (FR-154..155); KRSA/MoRTH data sharing + ERSS MoU pursuit (C8); insurance API (firewalled, §14.6); helmet-sticker QR (FR-095); Marathi/Bengali/Gujarati.
**Exit:** ML model beats rules on the replay corpus at equal false-positive budget; ≥ 2 institutions live; one government data-sharing agreement signed or formally in progress.

### Phase 4 — Ecosystem (Weeks 37+)
Voice SOS; BLE crash beacon hardware; smart-helmet partnerships; 108/102 API integration where MoUs permit; federated learning; third-party API; iOS at *documented reduced parity* (§4.2).

---

## 18. Risks & Mitigations

| Risk | Severity | Mitigation |
|---|---|---|
| **Google Play rejects SMS uplink / background-location declaration** | Critical (new) | Phase 0 runway; server-side cascade unaffected; user-confirmed SMS intent fallback; exception application with safety documentation; institutional sideload channel as last resort |
| **DPDPA minor-consent rules block student onboarding** | Critical (new) | Age gate + parental-consent flow built into MVP; legal review pre-pilot; track exemption notifications |
| **False positives** erode trust, cause alert fatigue | Critical | Conservative thresholds, shadow-mode graduation, 30 s countdown, sensitivity settings, labelled-cancel feedback loop, regression-tested corpus |
| **False negatives** create liability and reputational catastrophe | Critical (new) | FR-065 disclosure, claim discipline (§14.1/14.3), lost-contact backstop (FR-083), Phase 4 beacon, ToS |
| **Battery drain** → uninstalls | High | Duty cycling, geofence wake, transparency (FR-035), release-gated battery protocol |
| **OEM battery killers** silently disable tracking | High | Foreground service, per-OEM walkthroughs, tracking-survival metric gates releases, FR-083 catches silent death during commutes |
| **Alert pipeline fails silently** | High (new) | Hourly synthetic canary, channel-independent vendors, dead-letter review, on-call |
| **SMS costs at scale** | Medium | Unit-economics controls (§15.3): digest arrival SMS, push-first, budget alarms, premium priority routes |
| **Privacy backlash / "tracking app" stigma** | Medium | Anti-abuse architecture (§9) as a marketed differentiator, privacy-first defaults, no-data-selling pledge |
| **Misuse for stalking/coercion** | High (new) | §9 in full: no covert mode, acceptance-required membership, visibility screens, device-owner-only settings, reporting runbook |
| **Hospital database staleness** | Medium | Verified pilot district, last-verified surfacing, crowd flags, quarterly sweeps |
| **Regulatory (DPDPA general)** | Medium | Consent ledger, privacy dashboard, deletion pipeline, grievance officer |
| **Google/Apple ship better universal crash detection** | Low-Medium | Moat shifts to network/cascade/institution/convoy layers (§16 moat honesty) |
| **Transistor licensing / vendor lock-in** | Low (new) | Budgeted license; documented fallback implementation path |
| **MVP timeline slip** (10 weeks was optimistic; now 12 + compliance runway) | Medium (new) | Crash detection consciously deferred to Phase 2; Phase 0 runs in parallel; scope guarded by MoSCoW priorities |

---

## 19. Success Metrics

### 19.1 North Star
**Minutes between incident and first human aware** — median and p95 of (`first alert delivered_at` − `incident created_at`) over real dispatched incidents; complemented by (`first_ack_at` − `created_at`) as the human-response measure. Baseline (phone-call chain): 15–45 min. Target: < 2 min to delivery, < 5 min to acknowledgment.

### 19.2 Phase 1 Metrics (3 months post-launch)

| Metric | Target |
|---|---|
| Registered users | 1,000 |
| Daily active commuters (tracking on) | 300 |
| Active circles | 200 |
| **Tracking survival rate** (heartbeat continuity during expected commutes) | > 90% |
| **Cascade delivery success** (≥ 1 channel delivered per dispatched alert) | > 99% |
| Alert-to-acknowledgment time | < 5 min median |
| Non-arrival alert precision (alerts that were real concerns / total) | tracked; tune delay windows |
| D30 retention | > 40% |
| Battery-drain complaints | < 10% of users |
| Tracking opt-out rate (A1 validation) | < 20% |

### 19.3 Phase 2+ Detection Metrics

| Metric | Target |
|---|---|
| False-positive **dispatch** rate (post-countdown alerts that were not real) | < 5% |
| Countdown-cancel rate (pre-dispatch false positives) | tracked; model-improvement input |
| Shadow-mode recall on self-reported incidents | ≥ 90% before live graduation |
| Replay-corpus recall / FP (CI-gated) | ≥ 90% / < 1% per release |

### 19.4 Impact Metrics (12-month horizon)
- Real incidents where RoadPack was the first notification to family (with consented case studies)
- Incident-to-first-responder time vs. regional baseline
- Institutional adoption count; black spots identified and shared with authorities
- Zero substantiated misuse-for-stalking cases (a safety metric, not just a PR one)

---

## 20. Open Questions for Praseeth

1. **Branding:** Is "RoadPack" the final name given the pivot from convoy tracker to safety platform? (SafeRide, ReachSafe, GuardRoad, or RoadPack + new tagline.)
2. **Pilot geography/partner:** Ernakulam district is set; which specific college or community anchors the first 50–100 users — and do we approach MOSC-adjacent institutions given the context, or is that too raw?
3. **Revenue timing:** freemium from day one, or fully free through pilot/growth with monetization later? (§15.3 suggests free-tier SMS costs are manageable either way.)
4. **Open source:** open (trust, contributions, mission alignment) vs proprietary (IP, monetization flexibility)? A middle path: open-source the on-device detection engine and replay harness (invites scrutiny where trust matters most), keep the backend/cascade proprietary.
5. **Play SMS exception vs. dual-build:** pursue the Play exception for automated SMS uplink, ship the user-confirmed-SMS standard build only, or maintain an institutional sideload build with full capability? (Affects Phase 0 scope.)
6. **Minor users:** given DPDPA friction, do we launch 18+ only for the pilot and add the parental-consent flow in Phase 2, or build it into MVP because 17-year-old students are core to the mission? (This document assumes MVP — confirm.)
7. **Hardware ambitions:** BLE beacon / smart helmet — serious Phase 4 commitment or optionality?
8. **Government partnership:** pursue KRSA from the start (credibility, data) or prove the product first?
9. **Who is the medical/legal advisor** for the first-aid content and ToS review — budget and identify before Phase 0.

---

## 21. Glossary

| Term | Meaning |
|---|---|
| Golden hour | The first hour after trauma, when treatment most affects survival |
| ERSS / 112 | Emergency Response Support System, India's unified emergency number |
| 108 / 102 | State ambulance services (emergency / patient transport) |
| DPDPA | Digital Personal Data Protection Act, 2023 (India) |
| DLT | Distributed Ledger Technology registration mandated by TRAI for A2P SMS |
| ELS | Android Emergency Location Service (OS-level location to emergency services) |
| KRSA / MoRTH | Kerala Road Safety Authority / Ministry of Road Transport & Highways |
| PHC / CHC | Primary / Community Health Centre |
| ICE | In Case of Emergency (profile/card) |
| Observer | Circle role that receives alerts (incl. SMS-only) but never shares location |
| Shadow mode | Detection runs and logs without triggering external alerts (validation phase) |
| Tracking survival rate | Fraction of expected commute time the background service stayed alive |
| Cascade | Ordered multi-channel alert sequence: push → SMS → automated call (→ WhatsApp) |
| MoSCoW | Must / Should / Could / Won't prioritization |

---

*This document is a living spec. It will evolve as development begins and user feedback shapes the product. The core mission doesn't change: fewer families should have to receive the message that arrived on July 6, 2026.*
