-- =============================================================
-- RLS POLICIES: Content Layer
-- track_ratings, track_comments, review_votes
-- =============================================================

-- ── track_ratings ────────────────────────────────────────────

-- Public can read all reviews (community feed)
CREATE POLICY "track_ratings_public_read"
    ON public.track_ratings FOR SELECT
    USING (TRUE);

-- Authenticated users can insert their own ratings
CREATE POLICY "track_ratings_insert_own"
    ON public.track_ratings FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Only the author can update their own rating
-- NOTE: reputation is updated via SECURITY DEFINER function, not direct UPDATE
CREATE POLICY "tr_update"
    ON public.track_ratings FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Only the author can delete their own rating
CREATE POLICY "tr_delete"
    ON public.track_ratings FOR DELETE
    USING (auth.uid() = user_id);


-- ── track_comments ────────────────────────────────────────────

-- Public can read all comments
CREATE POLICY "track_comments_public_read"
    ON public.track_comments FOR SELECT
    USING (TRUE);

-- Authenticated users can insert
CREATE POLICY "track_comments_insert"
    ON public.track_comments FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Only the author can delete their own comment
CREATE POLICY "track_comments_delete_own"
    ON public.track_comments FOR DELETE
    USING (auth.uid() = user_id);


-- ── review_votes ─────────────────────────────────────────────

-- Users can read all votes (needed to compute reputation)
CREATE POLICY "review_votes_read"
    ON public.review_votes FOR SELECT
    USING (auth.uid() = user_id);

-- Users can only insert/update their own votes
CREATE POLICY "review_votes_own"
    ON public.review_votes FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);
