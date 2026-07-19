-- =============================================================
-- PLAYLISTS LAYER
-- Tables: playlists, playlist_tracks, playlist_likes
-- Supports user-created playlists (normal + synthesis type)
-- and community likes.
-- =============================================================


-- -------------------------------------------------------------
-- TABLE: playlists
-- A user-owned ordered collection of tracks.
-- is_synthesis=TRUE marks collaborative playlists from synthesis sessions.
-- synthesis_code links to synthesis_sessions.invite_code.
-- likes_count is maintained by increment/decrement RPC functions.
-- -------------------------------------------------------------

CREATE TABLE public.playlists (
    id               UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          UUID         NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    name             TEXT         NOT NULL CHECK (char_length(name) > 0),
    description      TEXT,
    cover_url        TEXT,
    track_count      INTEGER      NOT NULL DEFAULT 0 CHECK (track_count >= 0),
    is_public        BOOLEAN      NOT NULL DEFAULT FALSE,
    is_synthesis     BOOLEAN      NOT NULL DEFAULT FALSE,
    synthesis_code   TEXT,
    likes_count      INTEGER      NOT NULL DEFAULT 0 CHECK (likes_count >= 0),

    -- Denormalized creator info for list views
    username         TEXT,
    user_avatar_url  TEXT,

    created_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_playlists_user_id    ON public.playlists (user_id);
CREATE INDEX idx_playlists_public     ON public.playlists (is_public, likes_count DESC) WHERE is_public = TRUE;
CREATE INDEX idx_playlists_synthesis  ON public.playlists (synthesis_code) WHERE synthesis_code IS NOT NULL;

ALTER TABLE public.playlists ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE public.playlists IS
    'User playlists — both regular and synthesis (collaborative). '
    'track_count and likes_count are denormalized counters maintained by application logic.';
COMMENT ON COLUMN public.playlists.is_synthesis IS
    'TRUE for playlists generated from a synthesis session (collaborative between 2 users).';


-- -------------------------------------------------------------
-- TABLE: playlist_tracks
-- Ordered tracks within a playlist.
-- track_id references external Audius track IDs or custom_tracks.id.
-- UNIQUE (playlist_id, track_id) to prevent duplicates.
-- -------------------------------------------------------------

CREATE TABLE public.playlist_tracks (
    id                UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    playlist_id       UUID         NOT NULL REFERENCES public.playlists(id) ON DELETE CASCADE,
    track_id          TEXT         NOT NULL,
    track_title       TEXT         NOT NULL,
    track_artist      TEXT         NOT NULL,
    track_cover_url   TEXT,
    track_preview_url TEXT,
    position          INTEGER      NOT NULL DEFAULT 0,
    added_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    added_by_username TEXT,
    added_by_avatar   TEXT,

    CONSTRAINT uq_playlist_tracks_playlist_track UNIQUE (playlist_id, track_id)
);

CREATE INDEX idx_playlist_tracks_playlist ON public.playlist_tracks (playlist_id, position ASC, added_at ASC);

ALTER TABLE public.playlist_tracks ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE public.playlist_tracks IS
    'Tracks belonging to a playlist. Ordered by position then added_at. '
    'UNIQUE (playlist_id, track_id) prevents duplicate tracks.';


-- -------------------------------------------------------------
-- TABLE: playlist_likes
-- Many-to-many: users ↔ playlists (likes)
-- likes_count on playlists is kept in sync by RPC functions.
-- -------------------------------------------------------------

CREATE TABLE public.playlist_likes (
    id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID         NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    playlist_id UUID         NOT NULL REFERENCES public.playlists(id) ON DELETE CASCADE,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_playlist_likes_user_playlist UNIQUE (user_id, playlist_id)
);

CREATE INDEX idx_playlist_likes_user    ON public.playlist_likes (user_id);
CREATE INDEX idx_playlist_likes_playlist ON public.playlist_likes (playlist_id);

ALTER TABLE public.playlist_likes ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE public.playlist_likes IS
    'Playlist likes (favourites). One like per (user, playlist). '
    'Mutating this table should trigger increment/decrement_playlist_likes RPC.';
