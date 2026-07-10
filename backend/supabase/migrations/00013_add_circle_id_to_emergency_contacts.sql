-- RoadPack v2: add circle_id FK to emergency_contacts for circle-based EC sync

ALTER TABLE emergency_contacts
  ADD COLUMN circle_id UUID REFERENCES circles(id) ON DELETE SET NULL;

CREATE INDEX idx_emergency_contacts_circle ON emergency_contacts(circle_id)
  WHERE circle_id IS NOT NULL;
