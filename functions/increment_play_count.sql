-- =============================================================
-- FUNCTIONS: Play Count Tracking
-- Atomic upsert of play counts for tracks and artists.
-- Uses INSERT ... ON CONFLICT DO UPDATE to atomically
-- insert-or-increment in a single operation — no race conditions.
-- =============================================================


-- -------------------------------------------------------------
-- FUNCTION: increment_track_play_count
-- Called after a user listens to a track for 30+ seconds.
-- Inserts the track into favorite_tracks if not present,
-- or increments play_count if it already exists.
-- -------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.increment_track_play_count(
    p_user_id          UUID,
    p_track_id         TEXT,
    p_track_title      TEXT,
    p_track_artist     TEXT,
    p_track_cover_url  TEXT DEFAULT NULL,
    p_track_preview_url TEXT DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.favorite_tracks (
        user_id, track_id, track_title, track_artist,
        track_cover_url, track_preview_url, play_count, added_at
    )
    VALUES (
        p_user_id, p_track_id, p_track_title, p_track_artist,
        p_track_cover_url, p_track_preview_url, 1, NOW()
    )
    ON CONFLICT (user_id, track_id)
    DO UPDATE SET
        play_count      = favorite_tracks.play_count + 1,
        track_title     = EXCLUDED.track_title,
        track_artist    = EXCLUDED.track_artist,
        track_cover_url = COALESCE(EXCLUDED.track_cover_url, favorite_tracks.track_cover_url);
END;
$$;

REVOKE ALL ON FUNCTION public.increment_track_play_count(UUID, TEXT, TEXT, TEXT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.increment_track_play_count(UUID, TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated;

COMMENT ON FUNCTION public.increment_track_play_count IS
    'Atomic upsert: inserts track into favorite_tracks or increments play_count. '
    'Single DB round-trip, no SELECT + UPDATE race condition.';


-- -------------------------------------------------------------
-- FUNCTION: increment_artist_play_count
-- Same pattern for artists.
-- -------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.increment_artist_play_count(
    p_user_id         UUID,
    p_artist_id       TEXT,
    p_artist_name     TEXT,
    p_artist_image_url TEXT DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.favorite_artists (
        user_id, artist_id, artist_name, artist_image_url, play_count, added_at
    )
    VALUES (
        p_user_id, p_artist_id, p_artist_name, p_artist_image_url, 1, NOW()
    )
    ON CONFLICT (user_id, artist_id)
    DO UPDATE SET
        play_count       = favorite_artists.play_count + 1,
        artist_name      = EXCLUDED.artist_name,
        artist_image_url = COALESCE(EXCLUDED.artist_image_url, favorite_artists.artist_image_url);
END;
$$;

REVOKE ALL ON FUNCTION public.increment_artist_play_count(UUID, TEXT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.increment_artist_play_count(UUID, TEXT, TEXT, TEXT) TO authenticated;

COMMENT ON FUNCTION public.increment_artist_play_count IS
    'Atomic upsert: inserts artist into favorite_artists or increments play_count.';
