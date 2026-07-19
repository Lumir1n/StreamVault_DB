-- =============================================================
-- PLAYLISTS LAYER — SYNTHESIS SESSIONS
-- Tables: synthesis_sessions, synthesis_participants
-- Collaborative playlist generation: two users join a session
-- via an invite code and the system blends their listening histories
-- into a shared playlist.
-- =============================================================


-- -------------------------------------------------------------
-- TABLE: synthesis_sessions
-- Represents a collaborative playlist-building event.
-- Created by a host user; others join via invite_code.
-- After completion, playlist_id points to the generated playlist.
-- -------------------------------------------------------------

CREATE TABLE public.synthesis_sessions (
    id               UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    creator_id       UUID         NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    creator_username TEXT,
    invite_code      TEXT         NOT NULL UNIQUE,  -- Short code for joining (e.g. "44f9817e")
    name             TEXT         NOT NULL DEFAULT 'Synthesis',
    status           TEXT         NOT NULL DEFAULT 'pending'
                                  CHECK (status IN ('pending', 'active', 'completed', 'expired')),
    playlist_id      UUID         REFERENCES public.playlists(id) ON DELETE SET NULL,
    created_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_synthesis_sessions_creator     ON public.synthesis_sessions (creator_id);
CREATE INDEX idx_synthesis_sessions_invite_code ON public.synthesis_sessions (LOWER(invite_code));

ALTER TABLE public.synthesis_sessions ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE public.synthesis_sessions IS
    'Collaborative playlist sessions. Users join via invite_code. '
    'playlist_id is set after the synthesis playlist is generated.';
COMMENT ON COLUMN public.synthesis_sessions.invite_code IS
    'Short alphanumeric code used to join the session. Indexed for case-insensitive lookup.';
COMMENT ON COLUMN public.synthesis_sessions.status IS
    'pending → active (when joined) → completed (playlist created) | expired.';


-- -------------------------------------------------------------
-- TABLE: synthesis_participants
-- Users who have joined a synthesis session.
-- Typically 2 users max (host + one guest).
-- UNIQUE (session_id, user_id) prevents double-joining.
-- -------------------------------------------------------------

CREATE TABLE public.synthesis_participants (
    id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id  UUID         NOT NULL REFERENCES public.synthesis_sessions(id) ON DELETE CASCADE,
    user_id     UUID         NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    username    TEXT,
    avatar_url  TEXT,
    joined_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_synthesis_participants_session_user UNIQUE (session_id, user_id)
);

CREATE INDEX idx_synthesis_participants_session ON public.synthesis_participants (session_id, joined_at ASC);
CREATE INDEX idx_synthesis_participants_user    ON public.synthesis_participants (user_id);

ALTER TABLE public.synthesis_participants ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE public.synthesis_participants IS
    'Users who have joined a synthesis session. '
    'UNIQUE (session_id, user_id) prevents the same user joining twice.';
