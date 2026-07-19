-- =============================================================
-- ACTIVITY LAYER
-- Tables: favorite_tracks, favorite_artists, track_history
-- Tracks user listening behavior and preferences
-- =============================================================


-- -------------------------------------------------------------
-- TABLE: favorite_tracks
-- Tracks a user has listened to / explicitly saved.
-- play_count is incremented via RPC increment_track_play_count.
-- UPSERT pattern: ON CONFLICT (user_id, track_id) DO UPDATE SET play_count++
-- -------------------------------------------------------------

CREATE TABLE public.favorite_tracks (
    id                UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id           UUID         NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    track_id          TEXT         NOT NULL,   -- External track ID (Audius or custom_tracks.id)
    track_title       TEXT         NOT NULL,
    track_artist      TEXT         NOT NULL,
    track_cover_url   TEXT,
    track_preview_url TEXT,
    play_count        INTEGER      NOT NULL DEFAULT 0,
    added_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_favorite_tracks_user_track UNIQUE (user_id, track_id)
);

CREATE INDEX idx_favorite_tracks_user_id     ON public.favorite_tracks (user_id);
CREATE INDEX idx_favorite_tracks_play_count  ON public.favorite_tracks (user_id, play_count DESC);

ALTER TABLE public.favorite_tracks ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE public.favorite_tracks IS
    'Tracks saved or listened to by users. play_count updated atomically via RPC.';


-- -------------------------------------------------------------
-- TABLE: favorite_artists
-- Artists a user has engaged with.
-- Mirrors favorite_tracks design for artists.
-- -------------------------------------------------------------

CREATE TABLE public.favorite_artists (
    id               UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          UUID         NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    artist_id        TEXT         NOT NULL,   -- External artist ID (Audius or custom_artists.id)
    artist_name      TEXT         NOT NULL,
    artist_image_url TEXT,
    play_count       INTEGER      NOT NULL DEFAULT 0,
    added_at         TIMESTAMPTZ  NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_favorite_artists_user_artist UNIQUE (user_id, artist_id)
);

CREATE INDEX idx_favorite_artists_user_id    ON public.favorite_artists (user_id);
CREATE INDEX idx_favorite_artists_play_count ON public.favorite_artists (user_id, play_count DESC);

ALTER TABLE public.favorite_artists ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE public.favorite_artists IS
    'Artists engaged with by users. play_count updated atomically via RPC.';


-- -------------------------------------------------------------
-- TABLE: track_history
-- Append-only log of playback events.
-- Not deduplicated — each listen creates a new row.
-- -------------------------------------------------------------

CREATE TABLE public.track_history (
    id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID         NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    track_id        TEXT         NOT NULL,
    track_title     TEXT         NOT NULL,
    track_artist    TEXT         NOT NULL,
    track_artist_id TEXT,
    played_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_track_history_user_played ON public.track_history (user_id, played_at DESC);

ALTER TABLE public.track_history ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE public.track_history IS
    'Append-only playback log. One row per listen event. Used for history feed and personalization.';
