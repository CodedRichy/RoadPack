import '../models/hospital.dart';

/// Bundled fallback hospital set for the Ernakulam / Muvattupuzha pilot.
///
/// Why this exists as well as the server table: a phone that has never
/// completed a sync must still be able to point a stranger at a casualty
/// department. The cache is authoritative once populated; this is the floor.
///
/// SOURCE OF TRUTH: `backend/supabase/seed/hospitals_ernakulam.sql`. Keep the
/// two in step -- same ids, same coordinates.
///
/// EVERY ROW IS UNVERIFIED. `verifiedAt` is null on purpose: coordinates are
/// approximate and no phone numbers are carried, because a wrong casualty
/// number costs more time than looking one up. FR-111 requires a physical
/// verification pass over this list before launch.
const kBundledHospitalSeed = <Hospital>[
  Hospital(
    id: 'ekm-govt-mc-kalamassery',
    name: 'Government Medical College, Ernakulam (Kalamassery)',
    lat: 10.0637,
    lng: 76.3225,
    type: HospitalType.medicalCollege,
    address: 'Kalamassery, Ernakulam',
    district: 'Ernakulam',
    source: 'pilot_seed_unverified',
  ),
  Hospital(
    id: 'ekm-general-hospital',
    name: 'General Hospital Ernakulam',
    lat: 9.9739,
    lng: 76.2810,
    type: HospitalType.district,
    address: 'Hospital Road, Ernakulam, Kochi',
    district: 'Ernakulam',
    source: 'pilot_seed_unverified',
  ),
  Hospital(
    id: 'ekm-muvattupuzha-govt',
    name: 'Government Hospital Muvattupuzha',
    lat: 9.9770,
    lng: 76.5790,
    type: HospitalType.district,
    address: 'Muvattupuzha, Ernakulam',
    district: 'Ernakulam',
    source: 'pilot_seed_unverified',
  ),
  Hospital(
    id: 'ekm-amrita-kochi',
    name: 'Amrita Institute of Medical Sciences',
    lat: 10.0264,
    lng: 76.2917,
    type: HospitalType.private,
    address: 'Ponekkara, Edappally, Kochi',
    district: 'Ernakulam',
    source: 'pilot_seed_unverified',
  ),
  Hospital(
    id: 'ekm-lourdes-kochi',
    name: 'Lourdes Hospital',
    lat: 9.9950,
    lng: 76.2836,
    type: HospitalType.private,
    address: 'Pachalam, Kochi',
    district: 'Ernakulam',
    source: 'pilot_seed_unverified',
  ),
  Hospital(
    id: 'ekm-lisie-kochi',
    name: 'Lisie Hospital',
    lat: 9.9905,
    lng: 76.2930,
    type: HospitalType.private,
    address: 'Kaloor, Kochi',
    district: 'Ernakulam',
    source: 'pilot_seed_unverified',
  ),
  Hospital(
    id: 'ekm-rajagiri-aluva',
    name: 'Rajagiri Hospital',
    lat: 10.0870,
    lng: 76.3560,
    type: HospitalType.private,
    address: 'Chunangamvely, Aluva',
    district: 'Ernakulam',
    source: 'pilot_seed_unverified',
  ),
  Hospital(
    id: 'ekm-little-flower-angamaly',
    name: 'Little Flower Hospital',
    lat: 10.2050,
    lng: 76.3860,
    type: HospitalType.private,
    address: 'Angamaly, Ernakulam',
    district: 'Ernakulam',
    source: 'pilot_seed_unverified',
  ),
];
