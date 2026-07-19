-- =============================================================
-- MODERATION LAYER
-- Tables: reports, content_strikes, user_bans, ban_appeals
-- Complete content moderation workflow:
-- User reports content → admin reviews → strike added to user →
-- at N strikes auto-ban triggers → banned user submits appeal →
-- admin reviews appeal → ban lifted or upheld.
-- =============================================================


-- -------------------------------------------------------------
-- TABLE: reports
-- Content moderation reports submitted by users.
-- target_type: 'comment' | 'review'
-- status lifecycle: pending → resolved | dismissed
-- -------------------------------------------------------------

CREATE TABLE public.reports (
    id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id     UUID         NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    target_type     TEXT         NOT NULL CHECK (target_type IN ('comment', 'review')),
    target_id       UUID         NOT NULL,   -- FK to track_comments.id or track_ratings.id
    reason          TEXT         NOT NULL CHECK (char_length(reason) > 0),
    target_content  TEXT,        -- Snapshot of reported content at time of report
    target_user_id  UUID         REFERENCES public.profiles(id) ON DELETE SET NULL,
    target_username TEXT,
    track_title     TEXT,
    status          TEXT         NOT NULL DEFAULT 'pending'
                                 CHECK (status IN ('pending', 'resolved', 'dismissed')),
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_reports_status      ON public.reports (status, created_at DESC);
CREATE INDEX idx_reports_target_user ON public.reports (target_user_id) WHERE target_user_id IS NOT NULL;
CREATE INDEX idx_reports_reporter    ON public.reports (reporter_id);

ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE public.reports IS
    'User-submitted content reports. Admin reviews and sets status to resolved or dismissed.';
COMMENT ON COLUMN public.reports.target_content IS
    'Snapshot of the reported text at submission time — preserved even if original is deleted.';


-- -------------------------------------------------------------
-- TABLE: content_strikes
-- Individual strikes added to users when their content is removed.
-- Auto-ban logic: at 5 strikes, user_bans is upserted with is_active=TRUE.
-- (Auto-ban logic is in application layer, not a DB trigger.)
-- -------------------------------------------------------------

CREATE TABLE public.content_strikes (
    id           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      UUID         NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    content_type TEXT         NOT NULL CHECK (content_type IN ('comment', 'review')),
    content_id   UUID         NOT NULL,
    reason       TEXT         NOT NULL,
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_content_strikes_user ON public.content_strikes (user_id, created_at DESC);

ALTER TABLE public.content_strikes ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE public.content_strikes IS
    'Content removal strikes. 5 strikes triggers auto-ban (enforced by application). '
    'Kept as audit trail even after ban is lifted.';


-- -------------------------------------------------------------
-- TABLE: user_bans
-- Active or historical bans on users.
-- UNIQUE user_id — upsert pattern used to update existing bans.
-- is_active=FALSE means ban was lifted (by appeal or manually).
-- profiles.is_banned is kept in sync by application logic.
-- -------------------------------------------------------------

CREATE TABLE public.user_bans (
    id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID         NOT NULL UNIQUE REFERENCES public.profiles(id) ON DELETE CASCADE,
    reason      TEXT         NOT NULL,
    is_active   BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_user_bans_active ON public.user_bans (user_id, is_active) WHERE is_active = TRUE;

ALTER TABLE public.user_bans ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE public.user_bans IS
    'User ban records. UNIQUE user_id — each user has at most one ban record (upserted). '
    'Set is_active=FALSE to lift ban. profiles.is_banned mirrors this via application sync.';


-- -------------------------------------------------------------
-- TABLE: ban_appeals
-- Appeals submitted by banned users requesting ban reversal.
-- status lifecycle: pending → approved | rejected
-- On approved: user_bans.is_active set to FALSE, profiles.is_banned=FALSE.
-- -------------------------------------------------------------

CREATE TABLE public.ban_appeals (
    id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID         NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    ban_id      UUID         NOT NULL REFERENCES public.user_bans(id) ON DELETE CASCADE,
    message     TEXT         NOT NULL CHECK (char_length(message) > 0),
    username    TEXT,        -- Denormalized for admin panel display
    email       TEXT,        -- Denormalized for admin panel display
    status      TEXT         NOT NULL DEFAULT 'pending'
                             CHECK (status IN ('pending', 'approved', 'rejected')),
    reviewed_at TIMESTAMPTZ,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_ban_appeals_status ON public.ban_appeals (status, created_at DESC);
CREATE INDEX idx_ban_appeals_user   ON public.ban_appeals (user_id);

ALTER TABLE public.ban_appeals ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE public.ban_appeals IS
    'Appeals submitted by banned users. Admin sets status to approved (lifts ban) or rejected.';
