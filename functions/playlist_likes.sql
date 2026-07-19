-- =============================================================
-- FUNCTIONS: Playlist Likes Counter
-- Atomic increment/decrement of playlists.likes_count.
-- Direct PATCH with arithmetic expressions is not reliably
-- supported by PostgREST, so RPC functions are used instead.
-- =============================================================


-- -------------------------------------------------------------
-- FUNCTION: increment_playlist_likes
-- Called after a like is inserted into playlist_likes.
-- Uses UPDATE with += 1 — atomic, no race condition.
-- -------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.increment_playlist_likes(
    p_playlist_id UUID
)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    UPDATE public.playlists
    SET    likes_count = likes_count + 1
    WHERE  id = p_playlist_id;
$$;

GRANT EXECUTE ON FUNCTION public.increment_playlist_likes(UUID) TO authenticated;

COMMENT ON FUNCTION public.increment_playlist_likes IS
    'Atomically increments likes_count. Call after inserting a row into playlist_likes.';


-- -------------------------------------------------------------
-- FUNCTION: decrement_playlist_likes
-- Called after a like is deleted from playlist_likes.
-- Prevents going below 0.
-- -------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.decrement_playlist_likes(
    p_playlist_id UUID
)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    UPDATE public.playlists
    SET    likes_count = GREATEST(likes_count - 1, 0)
    WHERE  id = p_playlist_id;
$$;

GRANT EXECUTE ON FUNCTION public.decrement_playlist_likes(UUID) TO authenticated;

COMMENT ON FUNCTION public.decrement_playlist_likes IS
    'Atomically decrements likes_count (floor 0). Call after deleting from playlist_likes.';
