-- =============================================================
-- LEGACY TABLES
-- These tables exist in the production database for backwards
-- compatibility. They predate the current UUID-based schema
-- and use integer primary keys with sequential IDs.
--
-- NOTE: New features should NOT use these tables.
-- They are retained for historical data only.
-- =============================================================


-- -------------------------------------------------------------
-- TABLE: users (LEGACY)
-- Original user table before migration to Supabase Auth.
-- Replaced by: profiles (references auth.users)
-- Status: Retained for historical data
-- -------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.users (
    id            SERIAL       PRIMARY KEY,
    username      VARCHAR      NOT NULL UNIQUE,
    email         VARCHAR      NOT NULL UNIQUE,
    password_hash VARCHAR      NOT NULL,
    created_at    TIMESTAMP    DEFAULT NOW()
);

COMMENT ON TABLE public.users IS
    '[LEGACY] Original user table. Superseded by profiles + Supabase Auth.';


-- -------------------------------------------------------------
-- TABLE: tracks (LEGACY)
-- Original track table before integration with external API.
-- Replaced by: favorite_tracks, custom_tracks
-- Status: Retained for historical data
-- -------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.tracks (
    id         SERIAL    PRIMARY KEY,
    title      VARCHAR   NOT NULL,
    artist     VARCHAR   NOT NULL,
    genre      VARCHAR,
    audio_url  TEXT      NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

COMMENT ON TABLE public.tracks IS
    '[LEGACY] Original tracks table. Superseded by custom_tracks and external API integration.';


-- -------------------------------------------------------------
-- TABLE: ratings (LEGACY)
-- Original ratings table with integer FKs to legacy users/tracks.
-- Replaced by: track_ratings (UUID-based, 5-criteria scoring)
-- Status: Retained for historical data
-- -------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.ratings (
    id               SERIAL    PRIMARY KEY,
    user_id          INTEGER   REFERENCES public.users(id),
    track_id         INTEGER   REFERENCES public.tracks(id),
    rhyme_score      INTEGER   CHECK (rhyme_score    BETWEEN 1 AND 10),
    imagery_score    INTEGER   CHECK (imagery_score  BETWEEN 1 AND 10),
    structure_score  INTEGER   CHECK (structure_score BETWEEN 1 AND 10),
    rhythm_score     INTEGER   CHECK (rhythm_score   BETWEEN 1 AND 10),
    atmosphere_score INTEGER   CHECK (atmosphere_score BETWEEN 1 AND 10),
    comment          TEXT,
    created_at       TIMESTAMP DEFAULT NOW(),
    -- Extended fields added during migration
    audius_track_id  TEXT,
    track_title      TEXT,
    track_artist     TEXT,
    track_cover_url  TEXT,
    review           TEXT
);

COMMENT ON TABLE public.ratings IS
    '[LEGACY] Original ratings table with integer PKs. '
    'Superseded by track_ratings which uses UUID keys and 5-criteria scoring with generated overall_score.';
