-- =============================================================
-- RLS POLICIES: profiles
-- Public profiles readable by everyone.
-- Only the owner can update their own profile.
-- =============================================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Anyone can read public profiles (for search, artist pages, etc.)
CREATE POLICY "profiles_select_public"
    ON public.profiles FOR SELECT
    USING (is_public = TRUE OR auth.uid() = id);

-- Only the profile owner can update their own row
CREATE POLICY "profiles_update_own"
    ON public.profiles FOR UPDATE
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- Only the profile owner can insert (handled by trigger on auth.users)
CREATE POLICY "profiles_insert_own"
    ON public.profiles FOR INSERT
    WITH CHECK (auth.uid() = id);

-- Only the profile owner (or service_role) can delete
CREATE POLICY "profiles_delete_own"
    ON public.profiles FOR DELETE
    USING (auth.uid() = id);


-- =============================================================
-- RLS POLICIES: favorite_tracks, favorite_artists, track_history
-- User can only read and write their own data.
-- =============================================================

ALTER TABLE public.favorite_tracks  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.favorite_artists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.track_history    ENABLE ROW LEVEL SECURITY;

CREATE POLICY "favorite_tracks_own"
    ON public.favorite_tracks FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "favorite_artists_own"
    ON public.favorite_artists FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "track_history_own"
    ON public.track_history FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);
