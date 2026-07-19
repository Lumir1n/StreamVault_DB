-- ============================================================
-- Migration: V002__add_rls_policies
-- Description: Enable Row Level Security on all tables
-- Applied: 2026-01-15
-- Author: Miroslav Gilevich
-- ============================================================

-- Enable RLS on all tables
ALTER TABLE public.profiles             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.favorite_tracks      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.favorite_artists     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.track_history        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.track_ratings        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.track_comments       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.review_votes         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.playlists            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.playlist_tracks      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.playlist_likes       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.synthesis_sessions   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.synthesis_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.custom_artists       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.custom_tracks        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reports              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.content_strikes      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_bans            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ban_appeals          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.artist_profiles      ENABLE ROW LEVEL SECURITY;

-- See rls/ directory for individual policy definitions.
