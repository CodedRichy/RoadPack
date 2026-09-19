-- Hospital seed data for the Ernakulam / Muvattupuzha pilot (FR-111, FR-114).
--
-- ============================== UNVERIFIED ==============================
-- EVERY ROW BELOW IS UNVERIFIED.
--   * verified_at IS NULL on purpose. FR-111 requires a manual verification
--     pass (physical/telephone check of casualty department, entrance
--     coordinates and emergency number) before launch, and FR-114's staleness
--     controls exist so unverified rows are surfaced as unverified in the UI.
--   * Coordinates are approximate facility centroids, not casualty-entrance
--     pins. A bystander sent to the wrong gate loses minutes.
--   * NO PHONE NUMBERS ARE SEEDED. An unverified casualty number costs more
--     time than it saves. Phones get added by the verification pass only.
-- Do not flip verified_at without a named human and a date on the sweep.
-- =======================================================================
--
-- Mirrored on device by app/lib/features/bystander/services/hospital_seed.dart
-- (the offline floor for a phone that has never synced). Keep the two in step:
-- same ids, same coordinates.

INSERT INTO hospitals
  (id, name, location, address, phone, type, trauma_level, has_emergency,
   state, district, verified_at, source)
VALUES
  ('a1f0e1d0-0001-4000-8000-000000000001',
   'Government Medical College, Ernakulam (Kalamassery)',
   ST_SetSRID(ST_MakePoint(76.3225, 10.0637), 4326)::geography,
   'Kalamassery, Ernakulam', NULL, 'medical_college', NULL, true,
   'Kerala', 'Ernakulam', NULL, 'pilot_seed_unverified'),

  ('a1f0e1d0-0001-4000-8000-000000000002',
   'General Hospital Ernakulam',
   ST_SetSRID(ST_MakePoint(76.2810, 9.9739), 4326)::geography,
   'Hospital Road, Ernakulam, Kochi', NULL, 'district', NULL, true,
   'Kerala', 'Ernakulam', NULL, 'pilot_seed_unverified'),

  ('a1f0e1d0-0001-4000-8000-000000000003',
   'Government Hospital Muvattupuzha',
   ST_SetSRID(ST_MakePoint(76.5790, 9.9770), 4326)::geography,
   'Muvattupuzha, Ernakulam', NULL, 'district', NULL, true,
   'Kerala', 'Ernakulam', NULL, 'pilot_seed_unverified'),

  ('a1f0e1d0-0001-4000-8000-000000000004',
   'Amrita Institute of Medical Sciences',
   ST_SetSRID(ST_MakePoint(76.2917, 10.0264), 4326)::geography,
   'Ponekkara, Edappally, Kochi', NULL, 'private', NULL, true,
   'Kerala', 'Ernakulam', NULL, 'pilot_seed_unverified'),

  ('a1f0e1d0-0001-4000-8000-000000000005',
   'Lourdes Hospital',
   ST_SetSRID(ST_MakePoint(76.2836, 9.9950), 4326)::geography,
   'Pachalam, Kochi', NULL, 'private', NULL, true,
   'Kerala', 'Ernakulam', NULL, 'pilot_seed_unverified'),

  ('a1f0e1d0-0001-4000-8000-000000000006',
   'Lisie Hospital',
   ST_SetSRID(ST_MakePoint(76.2930, 9.9905), 4326)::geography,
   'Kaloor, Kochi', NULL, 'private', NULL, true,
   'Kerala', 'Ernakulam', NULL, 'pilot_seed_unverified'),

  ('a1f0e1d0-0001-4000-8000-000000000007',
   'Rajagiri Hospital',
   ST_SetSRID(ST_MakePoint(76.3560, 10.0870), 4326)::geography,
   'Chunangamvely, Aluva', NULL, 'private', NULL, true,
   'Kerala', 'Ernakulam', NULL, 'pilot_seed_unverified'),

  ('a1f0e1d0-0001-4000-8000-000000000008',
   'Little Flower Hospital',
   ST_SetSRID(ST_MakePoint(76.3860, 10.2050), 4326)::geography,
   'Angamaly, Ernakulam', NULL, 'private', NULL, true,
   'Kerala', 'Ernakulam', NULL, 'pilot_seed_unverified')
ON CONFLICT (id) DO NOTHING;

-- Verification sweep checklist (FR-114), per row, before launch:
--   1. Casualty department open 24x7?  -> has_emergency
--   2. Trauma capability of the casualty (imaging, ortho, neuro on call)
--      -> trauma_level  (leave NULL rather than guess)
--   3. Casualty landline, dialled and answered -> phone
--   4. GPS pin dropped at the casualty entrance -> location
--   5. Set verified_at = now() and source = 'manual_verified_<initials>_<date>'
