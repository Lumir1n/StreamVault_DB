-- =============================================================
-- RLS POLICIES: Moderation Layer
-- reports, content_strikes, user_bans, ban_appeals
-- custom_artists, custom_tracks (public read)
-- =============================================================

-- ── reports ───────────────────────────────────────────────────

-- Users can only see their own reports; admin uses service_role
CREATE POLICY "reports_insert_own"
    ON public.reports FOR INSERT
    WITH CHECK (auth.uid() = reporter_id);

CREATE POLICY "reports_select_own"
    ON public.reports FOR SELECT
    USING (auth.uid() = reporter_id);


-- ── content_strikes ───────────────────────────────────────────

-- Users can see their own strikes
CREATE POLICY "content_strikes_select_own"
    ON public.content_strikes FOR SELECT
    USING (auth.uid() = user_id);


-- ── user_bans ─────────────────────────────────────────────────

-- Users can read their own ban status
CREATE POLICY "user_bans_select_own"
    ON public.user_bans FOR SELECT
    USING (auth.uid() = user_id);


-- ── ban_appeals ───────────────────────────────────────────────

CREATE POLICY "ban_appeals_insert_own"
    ON public.ban_appeals FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "ban_appeals_select_own"
    ON public.ban_appeals FOR SELECT
    USING (auth.uid() = user_id);


-- ── custom_artists / custom_tracks (public read) ──────────────

CREATE POLICY "custom_artists_public_read"
    ON public.custom_artists FOR SELECT
    USING (TRUE);

CREATE POLICY "custom_artists_service_write"
    ON public.custom_artists FOR ALL
    USING (auth.role() = 'service_role');

CREATE POLICY "custom_tracks_public_read"
    ON public.custom_tracks FOR SELECT
    USING (is_published = TRUE);

CREATE POLICY "custom_tracks_service_write"
    ON public.custom_tracks FOR ALL
    USING (auth.role() = 'service_role');
