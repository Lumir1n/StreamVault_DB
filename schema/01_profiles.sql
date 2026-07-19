-- =============================================================
-- TABLE: profiles
-- One-to-one extension of auth.users
-- Stores public user data: display name, avatar, bio, visibility
-- =============================================================

CREATE TABLE public.profiles (
    id             UUID         PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username       TEXT         NOT NULL,
    email          TEXT         NOT NULL,
    bio            TEXT,
    favorite_genre TEXT,
    avatar_url     TEXT,
    is_public      BOOLEAN      NOT NULL DEFAULT TRUE,
    is_banned      BOOLEAN      NOT NULL DEFAULT FALSE,
    ban_reason     TEXT,
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_profiles_username ON public.profiles (username);
CREATE INDEX idx_profiles_is_public ON public.profiles (is_public) WHERE is_public = TRUE;

-- Updated_at auto-update trigger
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Enable RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE public.profiles IS
    'User profiles — one per auth.users row. Contains display data and account status.';
COMMENT ON COLUMN public.profiles.is_public IS
    'Controls whether other users can view this profile.';
COMMENT ON COLUMN public.profiles.is_banned IS
    'Set to TRUE by admin when a ban is active.';
