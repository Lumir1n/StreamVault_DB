-- =============================================================
-- ADMIN CONTENT LAYER
-- Tables: custom_artists, custom_tracks
-- Platform-managed content uploaded via admin panel.
-- Separate from third-party API content — stored in Supabase Storage.
-- =============================================================


-- -------------------------------------------------------------
-- TABLE: custom_artists
-- Artists created and managed by platform administrators.
-- Avatar and cover images stored in 'admin-uploads' Storage bucket.
-- -------------------------------------------------------------

CREATE TABLE public.custom_artists (
    id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    name        TEXT         NOT NULL CHECK (char_length(name) > 0),
    bio         TEXT,
    genre       TEXT,
    location    TEXT,
    avatar_url  TEXT,        -- Path: admin-uploads/artists/avatar_<timestamp>.<ext>
    cover_url   TEXT,        -- Path: admin-uploads/artists/cover_<timestamp>.<ext>
    is_verified BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_custom_artists_name ON public.custom_artists (LOWER(name));

ALTER TABLE public.custom_artists ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE public.custom_artists IS
    'Platform-managed artists (not from external API). '
    'Managed via admin panel. Searchable alongside external artists.';
COMMENT ON COLUMN public.custom_artists.is_verified IS
    'Admin-granted verification badge.';


-- -------------------------------------------------------------
-- TABLE: custom_tracks
-- Audio tracks uploaded by administrators.
-- Audio and cover files stored in 'admin-uploads' Storage bucket.
-- Searchable via ilike on title; shown alongside external tracks.
-- -------------------------------------------------------------

CREATE TABLE public.custom_tracks (
    id           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    artist_id    UUID         REFERENCES public.custom_artists(id) ON DELETE SET NULL,
    title        TEXT         NOT NULL CHECK (char_length(title) > 0),
    genre        TEXT,
    duration     INTEGER      CHECK (duration > 0),   -- Duration in seconds
    audio_url    TEXT,        -- Path: admin-uploads/tracks/audio_<timestamp>.<ext>
    cover_url    TEXT,        -- Path: admin-uploads/tracks/cover_<timestamp>.<ext>
    play_count   INTEGER      NOT NULL DEFAULT 0 CHECK (play_count >= 0),
    is_published BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_custom_tracks_artist    ON public.custom_tracks (artist_id);
CREATE INDEX idx_custom_tracks_title     ON public.custom_tracks (LOWER(title));
CREATE INDEX idx_custom_tracks_published ON public.custom_tracks (is_published) WHERE is_published = TRUE;

ALTER TABLE public.custom_tracks ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE public.custom_tracks IS
    'Platform-managed audio tracks. audio_url and cover_url point to Supabase Storage objects. '
    'Only is_published=TRUE tracks appear in search results.';
COMMENT ON COLUMN public.custom_tracks.audio_url IS
    'Public URL from Supabase Storage (admin-uploads bucket). '
    'Filename sanitized to <timestamp>.<ext> to avoid Cyrillic/special-char Storage key errors.';
