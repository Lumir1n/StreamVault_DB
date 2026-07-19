-- =============================================================
-- CONTENT LAYER — REVIEW VOTES (Reputation System)
-- Table: review_votes
-- Users vote +1 or -1 on track_ratings rows.
-- Actual reputation is maintained by update_review_reputation() RPC
-- because RLS prevents users from updating other users' rows.
-- =============================================================

CREATE TABLE public.review_votes (
    id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    rating_id  UUID        NOT NULL REFERENCES public.track_ratings(id) ON DELETE CASCADE,
    vote       SMALLINT    NOT NULL CHECK (vote IN (-1, 1)),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- One vote per (user, review)
    CONSTRAINT uq_review_votes_user_rating UNIQUE (user_id, rating_id)
);

CREATE INDEX idx_review_votes_rating ON public.review_votes (rating_id);
CREATE INDEX idx_review_votes_user   ON public.review_votes (user_id);

ALTER TABLE public.review_votes ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE public.review_votes IS
    'Community up/downvotes on track reviews. vote IN (-1, 1). '
    'After insert/update, call update_review_reputation(rating_id) to sync track_ratings.reputation.';
COMMENT ON COLUMN public.review_votes.vote IS
    '+1 = upvote, -1 = downvote. Upsert on (user_id, rating_id) to change vote.';
