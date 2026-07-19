-- =============================================================
-- CONTENT LAYER — RATINGS
-- Table: track_ratings
-- 5-criteria structured music rating system + optional review text.
-- One rating per user per track (UNIQUE user_id + audius_track_id).
-- reputation field is maintained by update_review_reputation() RPC.
-- =============================================================

CREATE TABLE public.track_ratings (
    id               UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          UUID         NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    audius_track_id  TEXT         NOT NULL,   -- External track identifier
    track_title      TEXT         NOT NULL,
    track_artist     TEXT         NOT NULL,
    track_cover_url  TEXT,

    -- 5 scoring dimensions (each 1–10)
    rhyme_score      SMALLINT     CHECK (rhyme_score BETWEEN 1 AND 10),
    imagery_score    SMALLINT     CHECK (imagery_score BETWEEN 1 AND 10),
    structure_score  SMALLINT     CHECK (structure_score BETWEEN 1 AND 10),
    charisma_score   SMALLINT     CHECK (charisma_score BETWEEN 1 AND 10),
    atmosphere_score SMALLINT     CHECK (atmosphere_score BETWEEN 1 AND 10),

    -- Computed average (stored for query performance)
    overall_score    NUMERIC(4,2) GENERATED ALWAYS AS (
        CASE
            WHEN rhyme_score IS NOT NULL
             AND imagery_score IS NOT NULL
             AND structure_score IS NOT NULL
             AND charisma_score IS NOT NULL
             AND atmosphere_score IS NOT NULL
            THEN (rhyme_score + imagery_score + structure_score + charisma_score + atmosphere_score) / 5.0
            ELSE NULL
        END
    ) STORED,

    review           TEXT,        -- Optional long-form review text

    -- Denormalized for feed performance (avoids JOIN to profiles)
    username         TEXT,
    user_avatar_url  TEXT,

    -- Community reputation (maintained by update_review_reputation RPC)
    reputation       INTEGER      NOT NULL DEFAULT 0,

    created_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_track_ratings_user_track UNIQUE (user_id, audius_track_id)
);

-- Indexes
CREATE INDEX idx_track_ratings_track    ON public.track_ratings (audius_track_id);
CREATE INDEX idx_track_ratings_user     ON public.track_ratings (user_id);
CREATE INDEX idx_track_ratings_rep      ON public.track_ratings (reputation DESC) WHERE review IS NOT NULL;
CREATE INDEX idx_track_ratings_score    ON public.track_ratings (overall_score DESC NULLS LAST);

-- Updated_at trigger
CREATE TRIGGER trg_track_ratings_updated_at
    BEFORE UPDATE ON public.track_ratings
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.track_ratings ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE public.track_ratings IS
    'Per-user track ratings across 5 criteria. One row per (user, track). overall_score is a generated computed column.';
COMMENT ON COLUMN public.track_ratings.overall_score IS
    'Auto-computed average of all 5 criteria scores. NULL if any criterion is missing.';
COMMENT ON COLUMN public.track_ratings.reputation IS
    'Community-voted reputation. Maintained by SECURITY DEFINER function update_review_reputation().';
COMMENT ON COLUMN public.track_ratings.username IS
    'Denormalized from profiles for read performance. Not auto-synced on username change.';
