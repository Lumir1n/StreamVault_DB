-- =============================================================
-- RLS POLICIES: Playlists Layer
-- playlists, playlist_tracks, playlist_likes
-- synthesis_sessions, synthesis_participants
-- =============================================================

-- ── playlists ─────────────────────────────────────────────────

-- Public playlists visible to everyone; private only to owner
CREATE POLICY "playlists_select"
    ON public.playlists FOR SELECT
    USING (is_public = TRUE OR auth.uid() = user_id);

CREATE POLICY "playlists_insert_own"
    ON public.playlists FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "playlists_update_own"
    ON public.playlists FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "playlists_delete_own"
    ON public.playlists FOR DELETE
    USING (auth.uid() = user_id);


-- ── playlist_tracks ───────────────────────────────────────────

-- Anyone who can see the playlist can see its tracks
CREATE POLICY "playlist_tracks_select"
    ON public.playlist_tracks FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.playlists pl
            WHERE pl.id = playlist_id
              AND (pl.is_public = TRUE OR pl.user_id = auth.uid())
        )
    );

CREATE POLICY "playlist_tracks_modify_own"
    ON public.playlist_tracks FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.playlists pl
            WHERE pl.id = playlist_id AND pl.user_id = auth.uid()
        )
    );


-- ── playlist_likes ────────────────────────────────────────────

CREATE POLICY "playlist_likes_own"
    ON public.playlist_likes FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);


-- ── synthesis_sessions ────────────────────────────────────────

-- Participants can read sessions they're part of
CREATE POLICY "synthesis_sessions_select"
    ON public.synthesis_sessions FOR SELECT
    USING (
        auth.uid() = creator_id
        OR EXISTS (
            SELECT 1 FROM public.synthesis_participants sp
            WHERE sp.session_id = id AND sp.user_id = auth.uid()
        )
    );

CREATE POLICY "synthesis_sessions_insert_own"
    ON public.synthesis_sessions FOR INSERT
    WITH CHECK (auth.uid() = creator_id);

CREATE POLICY "synthesis_sessions_update_own"
    ON public.synthesis_sessions FOR UPDATE
    USING (auth.uid() = creator_id);

CREATE POLICY "synthesis_sessions_delete_own"
    ON public.synthesis_sessions FOR DELETE
    USING (auth.uid() = creator_id);


-- ── synthesis_participants ────────────────────────────────────

CREATE POLICY "synthesis_participants_select"
    ON public.synthesis_participants FOR SELECT
    USING (
        auth.uid() = user_id
        OR EXISTS (
            SELECT 1 FROM public.synthesis_sessions ss
            WHERE ss.id = session_id AND ss.creator_id = auth.uid()
        )
    );

CREATE POLICY "synthesis_participants_insert"
    ON public.synthesis_participants FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "synthesis_participants_delete_own"
    ON public.synthesis_participants FOR DELETE
    USING (auth.uid() = user_id);
