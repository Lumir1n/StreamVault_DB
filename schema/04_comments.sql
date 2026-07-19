-- =============================================================
-- CONTENT LAYER — COMMENTS
-- Table: track_comments
-- Free-text comments on tracks (up to 100 chars in app).
-- Not deduplicated — users can comment multiple times.
-- =============================================================

CREATE TABLE public.track_comments (
    id               UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          UUID         NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    audius_track_id  TEXT         NOT NULL,
    track_title      TEXT         NOT NULL,
    track_artist     TEXT         NOT NULL,
    track_cover_url  TEXT,

    comment          TEXT         NOT NULL CHECK (char_length(comment) > 0),

    -- Denormalized for feed performance
    username         TEXT,
    user_avatar_url  TEXT,

    created_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_track_comments_track   ON public.track_comments (audius_track_id, created_at DESC);
CREATE INDEX idx_track_comments_user    ON public.track_comments (user_id, created_at DESC);

ALTER TABLE public.track_comments ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE public.track_comments IS
    'Free-text comments on tracks. Multiple comments per user allowed. Not a threaded reply system.';
