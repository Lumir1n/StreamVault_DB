-- =============================================================
-- FUNCTIONS: Synthesis Session Management
-- Atomic operations for collaborative playlist sessions.
-- Uses INSERT ... ON CONFLICT to prevent race conditions
-- when two users try to create/join simultaneously.
-- =============================================================


-- -------------------------------------------------------------
-- FUNCTION: get_or_create_synthesis_session
-- Returns an existing active synthesis session for the creator,
-- or creates a new one with a random 8-char invite code.
-- Atomic: safe to call concurrently from multiple clients.
-- -------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.get_or_create_synthesis_session(
    p_creator_id       UUID,
    p_creator_username TEXT DEFAULT NULL
)
RETURNS public.synthesis_sessions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_session public.synthesis_sessions;
    v_code    TEXT;
BEGIN
    -- Try to find existing active session for this user
    SELECT * INTO v_session
    FROM   public.synthesis_sessions
    WHERE  creator_id = p_creator_id
      AND  status IN ('pending', 'active')
    ORDER  BY created_at DESC
    LIMIT  1;

    IF FOUND THEN
        RETURN v_session;
    END IF;

    -- Generate unique invite code (8 hex chars)
    LOOP
        v_code := LOWER(encode(gen_random_bytes(4), 'hex'));
        EXIT WHEN NOT EXISTS (
            SELECT 1 FROM public.synthesis_sessions WHERE invite_code = v_code
        );
    END LOOP;

    -- Create new session
    INSERT INTO public.synthesis_sessions (
        creator_id, creator_username, invite_code, status
    )
    VALUES (p_creator_id, p_creator_username, v_code, 'pending')
    RETURNING * INTO v_session;

    RETURN v_session;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_or_create_synthesis_session(UUID, TEXT) TO authenticated;

COMMENT ON FUNCTION public.get_or_create_synthesis_session IS
    'Returns existing active synthesis session for the user or creates a new one. '
    'Generates a collision-free 8-char hex invite code atomically.';


-- -------------------------------------------------------------
-- FUNCTION: find_synthesis_session_by_code
-- Case-insensitive lookup by invite code.
-- Returns SETOF to work cleanly with PostgREST (array response).
-- -------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.find_synthesis_session_by_code(
    p_invite_code TEXT
)
RETURNS SETOF public.synthesis_sessions
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
    SELECT *
    FROM   public.synthesis_sessions
    WHERE  LOWER(invite_code) = LOWER(TRIM(p_invite_code))
    LIMIT  1;
$$;

GRANT EXECUTE ON FUNCTION public.find_synthesis_session_by_code(TEXT) TO authenticated, anon;

COMMENT ON FUNCTION public.find_synthesis_session_by_code IS
    'Case-insensitive invite code lookup. Returns SETOF for PostgREST compatibility.';


-- -------------------------------------------------------------
-- FUNCTION: find_existing_synthesis
-- Checks if two users already have a completed synthesis together.
-- Returns playlist_id if found, otherwise NULL.
-- Prevents creating duplicate synthesis playlists.
-- -------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.find_existing_synthesis(
    p_user1_id UUID,
    p_user2_id UUID
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
    v_playlist_id UUID;
BEGIN
    -- Find sessions where both users are participants and a playlist exists
    SELECT ss.playlist_id INTO v_playlist_id
    FROM   public.synthesis_sessions  ss
    JOIN   public.synthesis_participants sp1
           ON sp1.session_id = ss.id AND sp1.user_id = p_user1_id
    JOIN   public.synthesis_participants sp2
           ON sp2.session_id = ss.id AND sp2.user_id = p_user2_id
    WHERE  ss.playlist_id IS NOT NULL
    ORDER  BY ss.created_at DESC
    LIMIT  1;

    RETURN v_playlist_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.find_existing_synthesis(UUID, UUID) TO authenticated;

COMMENT ON FUNCTION public.find_existing_synthesis IS
    'Returns playlist_id of an existing synthesis between two users, or NULL. '
    'Used to reuse existing synthesis instead of creating duplicates.';


-- -------------------------------------------------------------
-- FUNCTION: get_or_create_synthesis_playlist
-- Atomically creates the shared playlist for a synthesis session,
-- or returns the existing one if already created.
-- Sets synthesis_sessions.playlist_id on creation.
-- Prevents race condition when both users try to finalize simultaneously.
-- -------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.get_or_create_synthesis_playlist(
    p_session_id      UUID,
    p_host_user_id    UUID,
    p_name            TEXT,
    p_description     TEXT,
    p_synthesis_code  TEXT,
    p_host_username   TEXT DEFAULT NULL,
    p_host_avatar_url TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_playlist_id UUID;
BEGIN
    -- Check if playlist already exists for this session
    SELECT playlist_id INTO v_playlist_id
    FROM   public.synthesis_sessions
    WHERE  id = p_session_id;

    IF v_playlist_id IS NOT NULL THEN
        RETURN v_playlist_id;
    END IF;

    -- Create the synthesis playlist
    INSERT INTO public.playlists (
        user_id, name, description,
        is_public, is_synthesis, synthesis_code,
        track_count, likes_count,
        username, user_avatar_url
    )
    VALUES (
        p_host_user_id, p_name, p_description,
        FALSE, TRUE, p_synthesis_code,
        0, 0,
        p_host_username, p_host_avatar_url
    )
    RETURNING id INTO v_playlist_id;

    -- Link playlist back to session
    UPDATE public.synthesis_sessions
    SET    playlist_id = v_playlist_id,
           status      = 'completed'
    WHERE  id = p_session_id;

    RETURN v_playlist_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_or_create_synthesis_playlist(UUID, UUID, TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated;

COMMENT ON FUNCTION public.get_or_create_synthesis_playlist IS
    'Atomically creates a synthesis playlist and links it to the session. '
    'Idempotent — returns existing playlist_id if already created (race condition safe).';
