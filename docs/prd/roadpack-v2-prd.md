# RoadPack v2 — Product Requirements Document

**Document Version:** 1.0  
**Date:** July 7, 2026  
**Author:** Praseeth / Claude  
**Status:** Draft for Review  
**Classification:** Internal

---

## 1. Executive Summary

RoadPack v2 is an India-first road safety platform that combines real-time commute tracking, automatic crash detection, family safety circles, and group ride coordination into a single mobile application. It is designed to work within the constraints of Indian road infrastructure — patchy connectivity, two-wheeler dominance, underfunded emergency services, and the cultural dynamics of how Indian families, institutions, and communities respond to road emergencies.

The original RoadPack (2024) was a convoy tracking app for bikers — live map, group ride coordination, Firebase + Flutter. v2 retains the convoy DNA but pivots the core mission from recreational group tracking to saving lives on Indian roads.

India reports the highest number of road accident deaths of any country globally. Official figures document over 1.77 lakh deaths in 2024, with real numbers estimated at nearly double. Two-wheeler riders account for 45% of all fatalities, and the 18-45 age group accounts for 66.5% of victims — students, daily commuters, young professionals. Only 20% of accident victims reach medical care within the golden hour, and ambulance coverage in many regions is as low as 1 per 80,000-100,000 people.

The core thesis: **if the app knows where you are, where you're going, and who cares about you, it can close the gap between a crash and the moment help arrives — even when the victim can't call for help themselves.**

---

## 2. Problem Statement

### 2.1 The Incident That Reignited This Project

On July 6, 2026, Rahul S., a 7th-semester Mechanical Engineering student, died on the spot in a road accident at Peruvamuzhy, near Muvattupuzha, while commuting to college. His co-passenger Julian sustained injuries and was admitted to MOSC Medical College. The college learned about it through a phone call, suspended classes, and sent buses home.

This is not an outlier. This happens 480+ times a day across India.

### 2.2 The Systemic Failures

**Failure 1: Nobody knew in real-time.** Rahul's family, friends, and college had no automated awareness that he was in trouble. The information propagated through phone calls — minutes to hours after the event.

**Failure 2: Emergency response depends on the victim calling.** India's 112 ERSS handles 8+ lakh calls daily, but as stated by the ERSS Commissioner for Maharashtra: "We only help the people who can call us." Unconscious victims can't dial.

**Failure 3: Bystanders hesitate.** Despite the Good Samaritan Law (Motor Vehicles Amendment Act, 2019), most bystanders at Indian accident scenes don't know they're legally protected, don't know who to call, and don't know which hospital is closest.

**Failure 4: No product serves this market.** Life360, OtoZen, FamiSafe, and GeoZilla are designed for Western markets — US emergency numbers, assumptions about LTE coverage, car-centric crash detection, subscription pricing in USD. Google Pixel's crash detection now works in India but is limited to expensive Pixel phones. There is no India-native, two-wheeler-aware, offline-resilient safety platform that works on a ₹10,000 Android phone over Jio's network on a Kerala state highway.

### 2.3 The Opportunity

- 260 million registered two-wheelers in India
- 750 million smartphone users, majority Android, majority budget devices
- 40% of mobile usage in critical zones occurs on 2G or no data
- Zero dominant player in the Indian road safety app space
- Government actively seeking technology solutions (MoRTH Crash Data Portal, KRSA model, PM RAHAT scheme)
- Supreme Court mandating golden hour compliance — creating institutional pressure for solutions

---

## 3. Product Vision

**One-liner:** RoadPack is your road companion that watches your back — so you reach home safe, and if you don't, the people who love you know immediately.

**North Star Metric:** Minutes saved between incident and first alert reaching an emergency contact.

**Design Principles:**

1. **Silence is the signal.** The app's most important feature is detecting when something goes wrong, not requiring the user to tell it. A phone that stops moving on a highway is more informative than a panic button the user can't reach.

2. **Offline-first, always.** Every critical path — crash detection, alert dispatch, emergency info display — must work without data connectivity. SMS is the fallback, not an afterthought.

3. **Low-end device, low battery drain.** If it kills the battery on a Redmi Note by noon, students will uninstall it. Aggressive optimization for background location with intelligent duty cycling.

4. **Community, not surveillance.** The app should feel like a group of friends watching out for each other, not a tracking tool. Privacy controls must be granular and defaulted to the most restrictive useful setting.

5. **India-native.** Regional languages, 112 ERSS integration, awareness of Indian road types (NH, SH, district roads, ghat roads), hospital databases, legal context (Good Samaritan Law display for bystanders).

---

## 4. Target Users

### 4.1 Primary Personas

**Persona 1: The College Commuter (Rahul)**
- Age 18-24, commutes daily on a two-wheeler (bike or scooter)
- Budget Android phone (₹8,000-₹15,000), prepaid Jio/Airtel SIM
- Routes are predictable (home → college → home), timing is semi-regular
- Parents worry but don't want to "track" — they want to know he arrived safely
- Rides in groups sometimes, solo most days
- Connectivity: urban areas fine, stretches between towns are patchy

**Persona 2: The Worried Parent (Rahul's Mother)**
- Age 40-55, may or may not be technically proficient
- Wants a simple dashboard: "Has my child reached college? Are they safe?"
- Doesn't want to constantly check — wants to be alerted only when something is wrong
- Needs the app to work in Malayalam/Hindi/Tamil, not just English
- May not have a smartphone herself (feature phone SMS fallback critical)

**Persona 3: The Group Rider (Weekend Biker)**
- Age 22-35, rides in groups on weekends, sometimes long-distance
- Wants convoy coordination — who's ahead, who's behind, who stopped
- Values safety features as an add-on to the group ride experience
- This is the original RoadPack user, now with safety upgrades

**Persona 4: The Institutional Admin (College Transport Officer)**
- Manages awareness of student commute safety
- Wants aggregate dashboards — not individual tracking, but alerts when a student in their circle hasn't arrived
- Compliance and liability considerations for the institution
- Could be a college, corporate office, or fleet of delivery riders

### 4.2 Secondary Personas

- **Elderly family member** being tracked passively by children (falls, non-arrival)
- **Solo female commuter** wanting a safety layer with SOS to trusted contacts
- **Delivery rider / gig worker** whose employer wants safety monitoring
- **Tourist / pilgrim** on unfamiliar roads (Sabarimala, Leh-Manali, etc.)

---

## 5. Feature Specification

### 5.1 Feature Map Overview

Features are organized into five layers, from foundational to advanced:

- **Layer 0 — Identity & Circles:** User accounts, family/group circles, permissions
- **Layer 1 — Live Tracking & Commute Intelligence:** Real-time location, route learning, ETA
- **Layer 2 — Safety & Detection:** Crash detection, inactivity alerts, SOS
- **Layer 3 — Alert & Response:** Multi-channel notification, bystander UI, emergency info
- **Layer 4 — Convoy & Group Rides:** Evolved RoadPack convoy features
- **Layer 5 — Institutional & Analytics:** Dashboards, aggregate safety insights, API

---

### 5.2 Layer 0 — Identity & Circles

#### 5.2.1 User Onboarding

- Phone number OTP authentication (primary — mirrors how India identifies people)
- Optional email link for account recovery
- Minimal onboarding: name, phone, one emergency contact (enforced before app use)
- Language selection: English, Hindi, Malayalam, Tamil, Kannada, Telugu, Marathi, Bengali (Phase 1: English + Hindi + Malayalam)
- Permissions walkthrough: location (always), motion sensors, notification, SMS (explain why each matters in plain language)
- No signup wall for the bystander/emergency screen (see 5.4.4)

#### 5.2.2 Safety Circles

A circle is a group of people who share location and safety status with each other. Conceptually similar to Life360's circles but designed around Indian social structures.

**Circle Types:**

| Type | Description | Example | Max Members |
|---|---|---|---|
| Family | Core family unit, highest trust | Parents + children | 15 |
| Friends | Peer group, selective sharing | College friend group | 25 |
| Commute | Route-based, institutional | "MEC Muvattupuzha — S7 ME" | 100 |
| Convoy | Temporary, ride-specific | "Munnar Weekend Ride" | 50 |

**Circle Permissions Matrix:**

| Permission | Family | Friends | Commute | Convoy |
|---|---|---|---|---|
| Live location (continuous) | ✓ | Configurable | During commute only | During ride only |
| Crash/SOS alerts | ✓ | ✓ | ✓ | ✓ |
| Arrival/departure notifications | ✓ | Configurable | ✓ | N/A |
| Speed visibility | Configurable | ✗ | ✗ | ✓ |
| Location history (24h) | ✓ | ✗ | ✗ | ✗ |
| Battery level | ✓ | ✗ | ✗ | ✓ |

**Circle Management:**
- Create circle → share invite link (WhatsApp-native share, since that's how India shares everything)
- Role-based: Admin (can add/remove, configure alerts), Member, Observer (can see, can't share own location — for feature phone parents receiving SMS only)
- Leave circle anytime, with confirmation
- Circle-level mute (don't receive non-emergency notifications for X hours)

#### 5.2.3 Emergency Profile

Every user must configure before the app becomes active:

- **Emergency Contacts:** Minimum 1, maximum 5, ordered by priority. Each contact has: name, phone, relationship, preferred alert method (app push → SMS → phone call cascade)
- **Medical Info (optional but prompted):** Blood group, known allergies, medications, medical conditions, insurance details
- **Vehicle Info (optional):** Vehicle type (bike/scooter/car/auto), registration number, color
- **ICE (In Case of Emergency) Card:** Auto-generated digital card combining the above, accessible from lock screen widget and bystander QR scan

---

### 5.3 Layer 1 — Live Tracking & Commute Intelligence

#### 5.3.1 Background Location Engine

This is the most critical technical component. It must balance accuracy, battery life, and reliability on low-end devices.

**Duty Cycling Strategy:**

| State | GPS Interval | Accuracy | Battery Impact | Trigger |
|---|---|---|---|---|
| Stationary | Off (cell-tower only) | ~500m | Negligible | No motion detected for 5 min |
| Walking | 30 seconds | ~50m | Low | Activity recognition: on_foot |
| Riding (commute) | 5 seconds | ~10m | Medium | Activity recognition: in_vehicle, on known route |
| Riding (convoy) | 2 seconds | ~5m | Higher | User activated convoy mode |
| SOS / Crash alert active | 1 second | ~3m | Maximum | Crash detected or SOS triggered |

**Activity Recognition:**
- Use device accelerometer + gyroscope for on-device activity classification (stationary / walking / riding)
- No cloud dependency for activity recognition — must work offline
- Transition events (started riding, stopped moving) are logged locally and synced when connectivity available

**Battery Optimization:**
- Target: <5% battery drain per hour in commute mode on a Snapdragon 680-class device
- Geofence-based wake: define geofences around home, college/office, known waypoints — use OS-level geofence triggers (cheaper than continuous GPS)
- Adaptive interval: if the user is on a straight highway, reduce GPS frequency; if on a ghat road with turns, increase it
- User-visible battery impact indicator in settings ("RoadPack used 8% battery today")

#### 5.3.2 Commute Intelligence

The app learns the user's daily patterns and uses deviations as safety signals.

**Route Learning:**
- After 3-5 repetitions of the same commute, the app recognizes it as a "known route"
- Known routes have: expected start time (±window), expected duration, expected arrival time, waypoints
- User can manually define routes or let the system learn them
- Multiple routes supported (home→college, home→gym, college→library)

**Arrival Prediction & Alerts:**
- "Rahul usually reaches college by 8:15 AM. It's 8:30 and he hasn't arrived." → alert to Family circle
- Configurable alert delay: 10 min / 15 min / 30 min after expected arrival (default: 15 min)
- Alert escalation: first alert is a gentle push notification ("Rahul hasn't arrived yet — everything okay?"); if no response in 5 minutes, escalate to SMS + call cascade
- "I'm running late" one-tap dismissal from the user if they see the check-in prompt
- Weekend/holiday awareness — don't alert on days when the commute isn't expected (auto-detect or manual calendar)

#### 5.3.3 Live Map

- Real-time position of circle members on map
- Map style: clean, minimal, dark mode default (easier on eyes while riding)
- Tap a member to see: current speed, heading, battery %, last update time, ETA to next known destination
- Traffic layer overlay (Google Maps / Mappls / OpenStreetMap depending on coverage)
- Offline map tiles: pre-download map for known routes and a 5km buffer around them (critical for areas with no data)

---

### 5.4 Layer 2 — Safety & Detection

#### 5.4.1 Crash Detection Engine

The hardest and most important technical challenge. Must work on-device, in real-time, with minimal false positives.

**Sensor Fusion Approach:**

Inputs:
- Accelerometer (impact force, sudden deceleration)
- Gyroscope (tumble/roll detection)  
- Barometer (altitude change — falling off a bridge or embankment)
- GPS (speed at moment of impact, sudden stop)
- Microphone (optional — impact sound signature, only if user opts in)
- Activity recognition state (was the user riding?)

**Detection Logic (on-device, TensorFlow Lite model):**

Phase 1 (Rule-based MVP):
- Trigger if: deceleration > 4g AND (speed was > 20 km/h in last 10 seconds) AND (device orientation changed > 90° within 2 seconds)
- Filter out: known rough road segments (pothole database, crowd-sourced), speed bump zones, phone drops (no prior vehicle speed)

Phase 2 (ML-based):
- Train on: public crash sensor datasets + synthetic data + crowd-sourced real-world data from RoadPack users (with consent)
- Two-wheeler-specific model: different impact signatures from cars (lower mass, different fall patterns, more frequent low-speed drops that aren't crashes)
- Continuous model improvement via federated learning (model updates without raw data leaving device)

**False Positive Mitigation (critical for adoption):**

A crash detection system that cries wolf is worse than no system at all. Users will disable it.

- **30-second countdown after detection:** "We detected a possible crash. Are you okay? Tap to cancel." Loud alarm sound, full-screen UI, large cancel button
- **If no response in 30 seconds:** escalate to emergency alert sequence
- **If cancelled:** log the false positive with sensor data (opt-in) for model improvement, ask "What happened?" (dropped phone / pothole / speed bump / other) — this builds the training dataset
- **Sensitivity settings:** Low (fewer alerts, may miss minor crashes), Medium (default), High (more sensitive, more false positives — for concerned parents to set on child's device)
- **Contextual suppression:** if user is in a known parking area or within 50m of their home/office geofence, suppress low-confidence detections

#### 5.4.2 SOS — Manual Emergency Trigger

For situations where the user is conscious but in danger.

**Trigger Methods:**
- **In-app SOS button:** large, red, accessible from any screen. Long-press (2 seconds) to activate — prevents accidental triggers
- **Hardware trigger:** volume button sequence (press volume-up 5 times rapidly) — works with screen off, inspired by Android/iOS built-in emergency SOS
- **Voice trigger (Phase 2):** "RoadPack emergency" — wake word detection on-device, works offline
- **Widget:** home screen widget with one-tap SOS

**SOS Activation Sequence:**
1. 5-second countdown with cancel option (shorter than crash detection because user intentionally triggered)
2. Capture: GPS coordinates, speed, heading, timestamp, 10-second audio recording (opt-in), photo from front/rear camera (opt-in)
3. Dispatch alerts (see Layer 3)
4. Begin continuous location streaming to emergency contacts
5. Display bystander information screen (if someone else picks up the phone)

#### 5.4.3 Inactivity Detection

The "silent signal" — the app notices something is wrong because the user went quiet.

**Scenarios:**

| Scenario | Detection | Response |
|---|---|---|
| Phone stops moving on a road | No GPS change for 3+ min, last known speed > 15 km/h, not near a known stop | Vibrate + "Are you stopped? Tap to confirm you're okay" |
| Commute interrupted | Significant deviation from known route + stopped | Gentle check-in notification |
| Didn't start commute | User usually leaves by 7:30, hasn't moved by 8:00 on a weekday | Soft alert to self only: "Did you skip today?" with one-tap "Yes, not going" |
| Phone unreachable | No location update received by server for 15+ min during active commute | Alert to circle: "We lost contact with [name] at [last known location]" |

#### 5.4.4 Bystander Mode

If someone finds an accident victim's phone, the app should help them help.

**Lock Screen Widget / Always-On Display:**
- "EMERGENCY — Scan QR or Swipe to Help" persistent on lock screen during active commute
- QR code encodes: user's name, blood group, emergency contacts (phone numbers), medical conditions, nearest hospital with trauma center
- Swiping opens a full-screen bystander interface WITHOUT unlocking the phone:
  - "This person may need help"
  - One-tap call 112
  - One-tap call emergency contact 1
  - Nearest hospital with directions
  - Good Samaritan Law notice: "You are legally protected for helping. (Motor Vehicles Amendment Act, 2019, Section 134A)"
  - Basic first-aid guidance: "Do not move the person. Check breathing. Apply pressure to bleeding."

---

### 5.5 Layer 3 — Alert & Response

#### 5.5.1 Multi-Channel Alert Cascade

When a crash is detected, SOS triggered, or critical inactivity detected, alerts must reach the right people through whatever channel works.

**Cascade Order (per contact):**

1. **Push notification** (app) — instant, requires data + app installed
2. **SMS** — 5-second delay after push, sent regardless (doesn't require data or app on recipient's end)
3. **Automated phone call** — 30-second delay after SMS, with TTS message: "This is an emergency alert from RoadPack. [Name] may have been in an accident at [location]. Their last known position was [address]. Please check on them or call 112."
4. **WhatsApp message via Business API (Phase 2)** — parallel to SMS, since many Indians check WhatsApp before SMS

**Alert Content:**
```
🚨 EMERGENCY ALERT — RoadPack
[Name] may have been in an accident.

📍 Location: [Address / Landmark]
🗺️ Map: [Google Maps link to coordinates]
🕐 Time: [Timestamp]
🚗 Speed at incident: [X] km/h
🏥 Nearest hospital: [Name], [Distance], [Phone]

Call 112 for emergency services.
Call [Name]'s phone: [Number]
```

**SMS Format (for feature phone recipients):**
```
ROADPACK ALERT: [Name] accident at [Location]. 
Map: [short URL]. Hospital: [Name] [Phone]. 
Call 112. Call [Name]: [Number]
```

#### 5.5.2 Emergency Services Integration

- **112 ERSS:** One-tap call to 112 from within the app, with automatic location sharing where the API supports it
- **Hospital Finder:** Pre-cached database of hospitals with trauma/emergency services, sourced from NHA (National Health Authority) and state health department databases
  - Distance + estimated travel time from incident location
  - Type: PHC / CHC / District Hospital / Medical College / Private Hospital
  - Trauma center availability (Level I, II, III)
  - Phone numbers (verified, periodically updated)
- **Ambulance integration (Phase 2):** API integration with state ambulance services (108/102) where available — Kerala has GVK EMRI 108 coverage
- **Police station finder:** nearest police station with phone number (for FIR, as legally required under MV Act)

#### 5.5.3 Incident Timeline

Once an alert is triggered, the app creates a real-time incident timeline visible to all circle members:

- 7:32 AM — Crash detected at Peruvamuzhy, Muvattupuzha-Thodupuzha road
- 7:32 AM — 30-second countdown started
- 7:33 AM — No response. Emergency alerts dispatched.
- 7:33 AM — Push notification sent to [Mother], [Father], [Friend]
- 7:33 AM — SMS sent to [Mother] +91-XXXXX
- 7:34 AM — Automated call initiated to [Mother]
- 7:35 AM — [Father] opened alert in app
- 7:38 AM — [Mother] acknowledged alert via SMS reply

This provides a clear audit trail and reduces the chaos of "who knows what" that currently happens through fragmented WhatsApp messages and phone calls.

---

### 5.6 Layer 4 — Convoy & Group Rides

This is the evolved original RoadPack, now integrated into the safety platform.

#### 5.6.1 Convoy Creation & Management

- Create a convoy with a name, date/time, route (start → waypoints → destination)
- Share join link via WhatsApp / QR code
- Convoy roles: Lead (sets pace, route visible to all), Sweep (tail rider, confirms everyone is ahead), Rider
- Real-time map showing all convoy members with position, speed, heading
- "Regrouping point" markers — lead can drop a pin where the group should wait
- Estimated spacing between riders (distance/time gap to rider ahead and behind)

#### 5.6.2 Convoy Safety Features

- **Rider down alert:** if any convoy member triggers crash detection, entire convoy is alerted immediately with location
- **Straggler detection:** if a rider falls more than X km behind the sweep rider, alert the lead
- **Fuel/rest stop voting:** quick poll for the group to decide stops
- **Weather alerts:** if the route passes through an area with rain/fog warnings, alert the convoy
- **Speed governor awareness:** optional display of speed limits on the current road segment

#### 5.6.3 Post-Ride Summary

- Route map with elevation profile
- Distance, duration, average/max speed
- Safety score (based on speed compliance, smooth riding, no near-miss events)
- Shareable ride card for social media

---

### 5.7 Layer 5 — Institutional & Analytics

#### 5.7.1 Institutional Dashboard (Web App)

For colleges, companies, fleet operators:

- **Student/Employee safety overview:** aggregate view of active commuters, arrived, in-transit, alerts
- **No individual tracking** — institution sees: "[32 of 45 students in S7 ME have arrived]", not "Rahul is at coordinates X,Y"
- **Alert escalation:** if a student triggers an alert and their emergency contacts don't respond within 10 minutes, escalate to institutional admin
- **Historical analytics:** commute patterns (anonymized), peak risk hours, most common routes, incident reports
- **Compliance reports:** for institutional safety audits

#### 5.7.2 Anonymized Road Safety Data

With user consent, anonymized and aggregated data from RoadPack users can contribute to:

- **Black spot identification:** roads/intersections where crash detections and hard-braking events cluster
- **Road condition reporting:** crowd-sourced pothole and hazard marking
- **Speed pattern analysis:** where do riders consistently exceed safe speeds?
- **Data sharing with KRSA / MoRTH:** contribute to India's road safety intelligence (this also creates institutional goodwill and potential government partnership)

#### 5.7.3 API (Phase 3)

RESTful API for third-party integrations:
- Insurance companies (usage-based insurance, claim verification)
- Fleet management systems
- Emergency service providers
- Smart city platforms

---

## 6. Tech Stack Recommendation

### 6.1 Why Not Pure Firebase Again

The original RoadPack used Firebase (Auth + Firestore + Realtime DB). For a safety-critical app with continuous location writes from potentially millions of users, pure Firebase has three problems:

1. **Cost:** Firestore charges per read/write. Continuous location updates from 100K users at 5-second intervals = 1.7 million writes per minute. This becomes financially unsustainable.
2. **Geospatial limitations:** Firestore doesn't natively support geospatial queries (find nearest hospital, find users within radius). You'd need GeoFirestore workarounds that are hacky and expensive.
3. **Server-side logic:** Crash alert routing, cascade logic, SMS/call dispatch, and institutional dashboards need real backend logic, not just Cloud Functions bolted on.

### 6.2 Recommended Stack

#### Client (Mobile App)
| Component | Choice | Rationale |
|---|---|---|
| Framework | **Flutter 3.x** | You know it, it's mature, single codebase for Android + iOS, strong background service support |
| State Management | **Riverpod** | More scalable than Provider for complex app state, good for dependency injection |
| Local DB | **Drift (SQLite)** | Offline-first storage for routes, contacts, cached maps, queued alerts |
| Background Location | **flutter_background_geolocation** (Transistor Software) | Best-in-class background location for Flutter, handles battery optimization, activity recognition, geofencing |
| On-Device ML | **TFLite via tflite_flutter** | Crash detection model runs locally, no cloud dependency |
| Maps | **Google Maps Flutter** (primary) + **Mappls** (fallback for India-specific coverage) | Google for general use, Mappls has better Indian address/landmark data |
| Offline Maps | **Mapbox GL** or pre-cached tile bundles | For offline route display in no-connectivity zones |

#### Backend
| Component | Choice | Rationale |
|---|---|---|
| Primary Backend | **Supabase** (self-hosted or cloud) | PostgreSQL + PostGIS for geospatial, Row Level Security, Realtime subscriptions, Edge Functions, Auth |
| Database | **PostgreSQL 16 + PostGIS** | Native geospatial indexing, spatial queries (nearest hospital, users in radius), time-series location data |
| Realtime | **Supabase Realtime** (WebSocket) | Live location streaming to circle members, incident timeline updates |
| Push Notifications | **Firebase Cloud Messaging (FCM)** | Most reliable push delivery on Android in India, even on MIUI/ColorOS/FunTouchOS with aggressive battery optimization |
| SMS Gateway | **MSG91** or **Twilio** | MSG91 is India-native, better DLT compliance, cheaper for Indian numbers. Twilio as international fallback |
| Voice Calls (automated) | **Exotel** or **Knowlarity** | India-native cloud telephony for automated emergency calls with TTS |
| File Storage | **Supabase Storage** (S3-compatible) | Incident media (audio clips, photos) |
| Task Queue | **BullMQ + Redis** | Alert cascade orchestration (push → wait 5s → SMS → wait 30s → call), retry logic |
| API Gateway | **Node.js (Fastify)** on Supabase Edge Functions or self-hosted | Alert routing, cascade logic, institutional API |

#### Infrastructure
| Component | Choice | Rationale |
|---|---|---|
| Hosting | **AWS Mumbai (ap-south-1)** or **DigitalOcean Bangalore** | Low latency for Indian users, data residency compliance |
| CDN | **Cloudflare** | Edge caching for map tiles, static assets |
| Monitoring | **Sentry** (app crashes) + **Grafana/Prometheus** (backend) | Reliability monitoring for a safety-critical system |
| CI/CD | **GitHub Actions** → **Fastlane** (mobile) | Automated build, test, deploy pipeline |

#### Key Architecture Decision: Location Data Flow

```
User's Phone (GPS)
    │
    ├──► Local SQLite (always — offline buffer)
    │
    ├──► Supabase Realtime (when online — live to circle members)
    │         │
    │         └──► PostGIS table (location_history)
    │
    └──► SMS fallback (if no data for 5+ min during active commute)
              │
              └──► Backend receives SMS → processes as location update
```

Crash detection happens entirely on-device. The backend only gets involved when an alert needs to be dispatched.

---

## 7. Data Model (Core Entities)

### 7.1 Users

```sql
users (
    id              UUID PRIMARY KEY,
    phone           VARCHAR(15) UNIQUE NOT NULL,
    name            VARCHAR(100) NOT NULL,
    language        VARCHAR(5) DEFAULT 'en',
    blood_group     VARCHAR(5),
    medical_notes   TEXT,              -- encrypted at rest
    vehicle_type    VARCHAR(20),
    vehicle_reg     VARCHAR(20),
    crash_sensitivity VARCHAR(10) DEFAULT 'medium',
    created_at      TIMESTAMPTZ,
    last_seen_at    TIMESTAMPTZ
)
```

### 7.2 Circles

```sql
circles (
    id              UUID PRIMARY KEY,
    name            VARCHAR(100) NOT NULL,
    type            VARCHAR(20) NOT NULL,  -- family / friends / commute / convoy
    created_by      UUID REFERENCES users,
    invite_code     VARCHAR(12) UNIQUE,
    max_members     INT,
    settings        JSONB,                 -- alert preferences, permissions
    created_at      TIMESTAMPTZ,
    expires_at      TIMESTAMPTZ            -- for convoy type, auto-cleanup
)

circle_members (
    circle_id       UUID REFERENCES circles,
    user_id         UUID REFERENCES users,
    role            VARCHAR(20),           -- admin / member / observer
    permissions     JSONB,                 -- override circle-level defaults
    joined_at       TIMESTAMPTZ,
    PRIMARY KEY (circle_id, user_id)
)
```

### 7.3 Emergency Contacts

```sql
emergency_contacts (
    id              UUID PRIMARY KEY,
    user_id         UUID REFERENCES users,
    name            VARCHAR(100) NOT NULL,
    phone           VARCHAR(15) NOT NULL,
    relationship    VARCHAR(30),
    priority        INT,                   -- 1 = first to be called
    alert_method    VARCHAR(20)[] DEFAULT '{push,sms,call}',
    is_app_user     BOOLEAN DEFAULT false,
    app_user_id     UUID REFERENCES users  -- if they also have the app
)
```

### 7.4 Location History

```sql
-- Partitioned by date for performance
location_history (
    id              BIGSERIAL,
    user_id         UUID NOT NULL,
    point           GEOGRAPHY(POINT, 4326) NOT NULL, -- PostGIS
    speed           REAL,                  -- km/h
    heading         REAL,                  -- degrees
    accuracy        REAL,                  -- meters
    altitude        REAL,
    battery_level   SMALLINT,
    activity        VARCHAR(20),           -- stationary / walking / riding
    source          VARCHAR(10),           -- gps / network / fused
    recorded_at     TIMESTAMPTZ NOT NULL,
    synced_at       TIMESTAMPTZ,
    PRIMARY KEY (id, recorded_at)
) PARTITION BY RANGE (recorded_at);
```

### 7.5 Known Routes

```sql
known_routes (
    id              UUID PRIMARY KEY,
    user_id         UUID REFERENCES users,
    name            VARCHAR(100),          -- "Home → College"
    origin          GEOGRAPHY(POINT, 4326),
    destination     GEOGRAPHY(POINT, 4326),
    route_geometry  GEOGRAPHY(LINESTRING, 4326),
    typical_start   TIME,
    typical_duration INTERVAL,
    days_active     INT[],                 -- [1,2,3,4,5] = weekdays
    confidence      REAL,                  -- 0-1, based on repetition count
    repetition_count INT,
    last_traveled   TIMESTAMPTZ
)
```

### 7.6 Incidents

```sql
incidents (
    id              UUID PRIMARY KEY,
    user_id         UUID REFERENCES users,
    type            VARCHAR(20) NOT NULL,  -- crash_detected / sos / inactivity / non_arrival
    severity        VARCHAR(10),           -- low / medium / high / critical
    location        GEOGRAPHY(POINT, 4326),
    speed_at_event  REAL,
    sensor_data     JSONB,                 -- accelerometer/gyro readings at time of detection
    status          VARCHAR(20),           -- detected / countdown / cancelled / dispatched / acknowledged / resolved
    cancelled_reason VARCHAR(50),          -- pothole / speed_bump / phone_drop / false_alarm
    media           JSONB,                 -- references to audio/photo captures
    created_at      TIMESTAMPTZ,
    resolved_at     TIMESTAMPTZ
)

incident_alerts (
    id              UUID PRIMARY KEY,
    incident_id     UUID REFERENCES incidents,
    contact_id      UUID,                  -- emergency_contact or circle_member
    channel         VARCHAR(10),           -- push / sms / call / whatsapp
    status          VARCHAR(20),           -- queued / sent / delivered / read / failed
    sent_at         TIMESTAMPTZ,
    delivered_at    TIMESTAMPTZ,
    acknowledged_at TIMESTAMPTZ,
    error           TEXT
)
```

### 7.7 Hospitals & Emergency Services

```sql
hospitals (
    id              UUID PRIMARY KEY,
    name            VARCHAR(200) NOT NULL,
    location        GEOGRAPHY(POINT, 4326),
    address         TEXT,
    phone           VARCHAR(15)[],
    type            VARCHAR(30),           -- phc / chc / district / medical_college / private
    trauma_level    VARCHAR(10),           -- level_1 / level_2 / level_3 / none
    has_emergency   BOOLEAN DEFAULT true,
    state           VARCHAR(50),
    district        VARCHAR(50),
    verified_at     TIMESTAMPTZ,
    source          VARCHAR(50)            -- nha / state_health / manual / crowd_sourced
)

-- Spatial index for fast nearest-hospital queries
CREATE INDEX idx_hospitals_location ON hospitals USING GIST (location);
```

---

## 8. Non-Functional Requirements

### 8.1 Performance

| Metric | Target |
|---|---|
| Crash detection to first alert dispatched | < 35 seconds (30s countdown + 5s processing) |
| Location update to circle visibility | < 2 seconds (on LTE), < 10 seconds (on 3G) |
| App cold start to usable | < 3 seconds on Snapdragon 680 |
| Background battery drain | < 5% per hour in commute mode |
| Offline buffer capacity | 24 hours of location data |
| SMS alert delivery | < 10 seconds (via MSG91 priority route) |

### 8.2 Reliability

- **Uptime target:** 99.9% for alert dispatch pipeline (backend)
- **Crash detection must work offline:** on-device, no server dependency
- **SMS fallback must work in 2G zones:** alert dispatch path: data push → SMS → automated call. At least one must succeed.
- **Queue resilience:** alerts that fail to dispatch must retry with exponential backoff, with a hard upper limit (don't call someone 50 times)
- **Data sync:** offline-buffered location data must sync without loss when connectivity returns, with conflict resolution (server timestamp wins)

### 8.3 Privacy & Security

- **Location data encryption:** AES-256 at rest, TLS 1.3 in transit
- **Location history retention:** 7 days by default, user-configurable (1 day to 30 days), auto-purge after retention period
- **No location data sold or shared with third parties** — ever. This is a brand promise. (Life360's history of selling location data is a competitive vulnerability to exploit.)
- **Anonymized aggregate data only** shared with road safety authorities, with explicit user opt-in
- **Right to delete:** user can delete all their data (GDPR-style) with one action
- **Circle permissions are granular:** users control exactly what each circle sees
- **Institutional dashboards never show individual location** — aggregate counts only
- **Emergency profile data stored on-device** primarily, server-copy encrypted and accessible only during active incident
- **Compliance:** India's Digital Personal Data Protection Act (DPDPA) 2023, IT Act 2000

### 8.4 Accessibility

- Minimum font size 14sp in safety-critical UI (SOS button, countdown, bystander screen)
- High contrast mode for bystander screen (readable in direct sunlight)
- Haptic feedback on all safety interactions
- Screen reader support for visually impaired users
- Simple language — no jargon in any user-facing text

---

## 9. Monetization Strategy

### 9.1 Core Principle

**Safety features are never paywalled.** Crash detection, SOS, emergency alerts, and basic circle tracking are free, forever. Paywalling safety is both morally wrong and commercially stupid — it limits the network effect that makes the app valuable.

### 9.2 Revenue Streams

| Stream | Description | Timeline |
|---|---|---|
| **Freemium (Individuals)** | Free: 2 circles, 3 emergency contacts, 7-day history, basic crash detection. Premium (₹99/month or ₹799/year): unlimited circles, 10 contacts, 30-day history, advanced crash sensitivity, ride analytics, priority SMS alerts | Launch |
| **Institutional Subscriptions** | College/corporate dashboard, bulk onboarding, admin controls, aggregate analytics. ₹5,000-₹25,000/month based on user count | Phase 2 |
| **Insurance Partnerships** | Usage-based insurance integration — safer riders get lower premiums. Revenue share with insurance providers on policy referrals | Phase 3 |
| **Anonymized Data Licensing** | Road condition data, traffic pattern data, black spot data to government agencies, urban planners, automotive companies. Only anonymized + aggregated, only with user consent | Phase 3 |
| **Hardware Accessories (Phase 4)** | Bluetooth crash detection beacon for bikes (more accurate than phone-only), smart helmet integration, handlebar-mounted SOS button | Phase 4 |

---

## 10. Competitive Positioning

| Feature | RoadPack v2 | Life360 | Google Personal Safety | Apple Crash Detection | HelpQR |
|---|---|---|---|---|---|
| India-native | ✓ | ✗ (US-centric) | Partial (Pixel only) | ✗ (iPhone only) | ✓ |
| Two-wheeler crash detection | ✓ (purpose-built) | ✗ (car-only) | Partial (car-tuned) | ✗ (car-tuned) | ✗ (no crash detection) |
| Works on ₹10K Android | ✓ | ✓ | ✗ (Pixel only) | ✗ (iPhone only) | ✓ |
| Offline / SMS fallback | ✓ | ✗ | ✗ | Limited | ✓ (SMS) |
| Group ride / convoy | ✓ | ✗ | ✗ | ✗ | ✗ |
| Bystander activation (QR) | ✓ | ✗ | ✗ | Medical ID (limited) | ✓ (core feature) |
| Institutional dashboard | ✓ | ✗ | ✗ | ✗ | ✗ |
| Regional Indian languages | ✓ | ✗ | Partial | Partial | ✗ |
| 112 ERSS integration | ✓ | ✗ | ✗ | ✗ | ✓ |
| Commute intelligence | ✓ | Partial (places) | ✗ | ✗ | ✗ |
| Price | Free core + ₹99/mo premium | Free + $8-25/mo | Free (Pixel only) | Free (iPhone only) | Free |

**Positioning Statement:** RoadPack is the safety layer that Indian roads don't have — built for two-wheelers, built for ₹10K phones, built for patchy connectivity, built for the reality that when someone crashes on a Kerala highway at 7 AM, the system should know before anyone has to make a phone call.

---

## 11. Phased Rollout

### Phase 1 — MVP (Weeks 1-10)

**Goal:** Ship the thing that would have mattered on July 6, 2026.

Core deliverables:
- Phone OTP auth + user profile + emergency contacts (minimum 1)
- Family circle (create, invite via link, join)
- Background location tracking with duty cycling
- Live map showing circle members
- Known route learning (auto-detect after 3 trips)
- Non-arrival alert ("Rahul hasn't arrived — is everything okay?")
- Manual SOS button with 5-second countdown
- Multi-channel alert cascade: push → SMS → automated call
- SMS alert format for feature phone recipients
- Emergency profile + ICE card
- Lock screen bystander widget with QR code
- Nearest hospital finder (pre-loaded database, offline-capable)
- Languages: English + Malayalam + Hindi

**Tech scope:** Flutter app, Supabase backend, PostGIS, FCM, MSG91 SMS, Exotel for voice, basic admin panel.

**Target users:** Pilot with 50-100 users in Ernakulam/Muvattupuzha area — college students and their families.

### Phase 2 — Detection & Convoy (Weeks 11-20)

- Rule-based crash detection (accelerometer + gyroscope + GPS)
- 30-second countdown + cancel flow
- False positive reporting + data collection
- Inactivity detection ("phone stopped moving on a road")
- Convoy mode (create, join, live map, rider positions)
- Convoy safety (rider down alert, straggler detection)
- Friends circle type
- Commute circle type (institutional)
- Additional languages: Tamil, Kannada, Telugu
- Ride summary + safety score
- Battery optimization pass (target <5%/hour)

### Phase 3 — Intelligence & Scale (Weeks 21-32)

- ML-based crash detection model (TFLite, trained on Phase 2 data)
- Institutional dashboard (web app)
- WhatsApp Business API alert channel
- Road condition crowd-sourcing (potholes, hazards)
- Black spot identification + alerts when approaching known dangerous segments
- Weather-aware alerts
- Insurance partnership API
- Anonymized data export for road safety authorities
- Marathi, Bengali, Gujarati language support

### Phase 4 — Ecosystem (Weeks 33+)

- Voice-activated SOS
- Bluetooth crash detection beacon (hardware)
- Smart helmet integration (partnership)
- Integration with state ambulance services (108/102 API)
- Federated learning for crash model improvement
- API for third-party integrations
- iOS feature parity (Android-first given India's market)

---

## 12. Risks & Mitigations

| Risk | Severity | Mitigation |
|---|---|---|
| **False positive crash alerts** erode trust and cause alert fatigue | Critical | Conservative thresholds, 30s countdown, sensitivity settings, continuous model improvement from user feedback |
| **Battery drain** causes uninstalls | High | Aggressive duty cycling, geofence-based wake, transparent battery usage display, continuous optimization |
| **Background location killed by OEM battery optimization** (MIUI, ColorOS, Samsung) | High | In-app guidance for disabling battery optimization per OEM, dontkillmyapp.com-style walkthroughs, autostart permission requests |
| **SMS costs at scale** without revenue | Medium | Freemium model funds SMS costs, premium users get priority SMS, rate-limit SMS to genuine emergencies only |
| **Privacy backlash** ("tracking app" stigma) | Medium | Privacy-first defaults, transparent data policy, no data selling (ever), user controls front-and-center, marketing as "safety" not "tracking" |
| **Hospital database goes stale** | Medium | Periodic verification, crowd-sourced corrections, flag for "last verified" date |
| **Regulatory (DPDPA compliance)** | Medium | Privacy-by-design architecture, consent management, data deletion capability, DPO appointment if scale demands |
| **Competition from Google/Apple** adding better crash detection to all phones | Low-Medium | Differentiation through community features (circles, convoy), India-specific intelligence, institutional layer, and two-wheeler focus that big tech won't prioritize |

---

## 13. Success Metrics

### 13.1 North Star

**Minutes saved between incident and first human aware.** Currently estimated at 15-45 minutes (phone call chain). Target: under 2 minutes (automated alert + SMS).

### 13.2 Phase 1 Metrics

| Metric | Target (3 months post-launch) |
|---|---|
| Registered users | 1,000 |
| Daily active commuters (tracking enabled) | 300 |
| Active circles | 200 |
| SOS alerts triggered (real) | Tracking only (no target — fewer is better) |
| Non-arrival alerts that led to user check-in | Track response rate |
| Average alert-to-acknowledgment time | < 5 minutes |
| App retention (Day 30) | > 40% |
| Battery drain complaints | < 10% of users |
| False positive rate (crash detection) | < 5% once Phase 2 launches |

### 13.3 Impact Metrics (12-month horizon)

- Number of real incidents where RoadPack alert was the first notification to family
- Time delta between incident and first responder arrival (compared to regional average)
- User testimonials / documented cases where the app made a difference
- Institutional adoption (number of colleges/companies using commute circles)
- Road safety data contributions (black spots identified, shared with authorities)

---

## 14. Open Questions for Praseeth

1. **Branding:** Is "RoadPack" the final name, or should v2 have a new identity given the pivot from convoy tracker to safety platform? Names to consider: SafeRide, ReachSafe, GuardRoad, or keep RoadPack with a new tagline.

2. **Pilot geography:** Starting in Ernakulam district makes sense given proximity and the Muvattupuzha context. But should we target a specific college or community for the initial 50-100 users?

3. **Revenue timing:** Do you want to ship freemium from day one, or go fully free during the pilot/growth phase and add monetization later?

4. **Open source?** The original RoadPack was on GitHub. Should v2 be open source (builds trust, community contributions, aligns with the "saving lives" mission) or proprietary (protects IP, allows monetization flexibility)?

5. **Hardware ambitions:** The Bluetooth crash beacon / smart helmet integration in Phase 4 — is this something you want to explore seriously, or keep it as a future possibility?

6. **Government partnership:** Should we actively pursue KRSA (Kerala Road Safety Authority) integration from the start, or prove the product first and approach them later?

---

*This document is a living spec. It will evolve as development begins and user feedback shapes the product. The core mission doesn't change: fewer families should have to receive the message that arrived on July 6, 2026.*
