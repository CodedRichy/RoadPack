-- Allow NULL date_of_birth for users who haven't completed onboarding yet
-- Onboarding sets this field; its presence signals profile completion

ALTER TABLE users ALTER COLUMN date_of_birth DROP NOT NULL;
