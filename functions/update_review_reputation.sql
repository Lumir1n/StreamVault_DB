-- =============================================================
-- FUNCTION: update_review_reputation
-- Recalculates and stores the reputation of a review.
--
-- WHY SECURITY DEFINER?
-- RLS policy on track_ratings allows UPDATE only to the row owner
-- (user_id = auth.uid()). When User B votes on User A's review,
-- the reputation field on User A's row needs to be updated.
-- A normal PATCH would be silently blocked by RLS (0 rows updated).
-- This SECURITY DEFINER function runs with owner privileges,
-- safely performing ONLY the controlled SUM → UPDATE operation.
-- =============================================================

CREATE OR REPLACE FUNCTION public.update_review_reputation(
    p_rating_id UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_reputation INTEGER;
BEGIN
    -- Calculate total vote sum for this review
    SELECT COALESCE(SUM(vote), 0)
    INTO   v_reputation
    FROM   public.review_votes
    WHERE  rating_id = p_rating_id;

    -- Update reputation on the review row
    UPDATE public.track_ratings
    SET    reputation = v_reputation
    WHERE  id = p_rating_id;
END;
$$;

-- Allow authenticated users to call this function
-- (they call it after casting their vote)
REVOKE ALL ON FUNCTION public.update_review_reputation(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_review_reputation(UUID) TO authenticated;

COMMENT ON FUNCTION public.update_review_reputation(UUID) IS
    'Recalculates SUM(vote) from review_votes and writes to track_ratings.reputation. '
    'Uses SECURITY DEFINER to bypass RLS — a user cannot UPDATE another user''s row normally.';
