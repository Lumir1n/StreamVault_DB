-- =============================================================
-- TABLE: artist_profiles
-- Local cache of external artist data for improved query
-- performance. Avoids repeated API calls for artist metadata.
--
-- Cache invalidation: updated via cached_at timestamp.
-- If cached_at is older than threshold, application refreshes
-- from external API and updates this row.
-- =============================================================

CREATE TABLE public.artist_profiles (
    id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    artist_id      TEXT        NOT NULL UNIQUE,  -- External API artist ID
    artist_name    TEXT        NOT NULL,
    bio            TEXT,
    location       TEXT,
    avatar_url     TEXT,
    cover_url      TEXT,
    follower_count INTEGER     NOT NULL DEFAULT 0,
    track_count    INTEGER     NOT NULL DEFAULT 0,
    is_verified    BOOLEAN     NOT NULL DEFAULT FALSE,
    cached_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_artist_profiles_artist_id ON public.artist_profiles (artist_id);
CREATE INDEX idx_artist_profiles_cached_at ON public.artist_profiles (cached_at);

ALTER TABLE public.artist_profiles ENABLE ROW LEVEL SECURITY;

-- Public read — anyone can access cached artist info
CREATE POLICY "artist_profiles_public_read"
    ON public.artist_profiles FOR SELECT
    USING (TRUE);

COMMENT ON TABLE public.artist_profiles IS
    'Local cache of external artist metadata. '
    'Reduces API calls for frequently accessed artist data. '
    'cached_at determines when a refresh is needed.';
COMMENT ON COLUMN public.artist_profiles.artist_id IS
    'Unique identifier from the external music API.';
COMMENT ON COLUMN public.artist_profiles.cached_at IS
    'Timestamp of last cache refresh. Application refreshes if stale.';
