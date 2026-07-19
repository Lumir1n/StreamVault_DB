-- ============================================================
-- Migration: V001__initial_schema
-- Description: Initial database schema — all core tables
-- Applied: 2026-01-01
-- Author: Miroslav Gilevich
-- ============================================================

-- Helper function for updated_at
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

-- Core tables applied in dependency order:
-- See schema/ directory for individual table definitions.
-- This migration applies all schema files in sequence.

-- 01_profiles.sql       → profiles
-- 02_activity.sql       → favorite_tracks, favorite_artists, track_history
-- 03_ratings.sql        → track_ratings
-- 04_comments.sql       → track_comments
-- 05_review_votes.sql   → review_votes
-- 06_playlists.sql      → playlists, playlist_tracks, playlist_likes
-- 07_synthesis.sql      → synthesis_sessions, synthesis_participants
-- 08_custom_content.sql → custom_artists, custom_tracks
-- 09_moderation.sql     → reports, content_strikes, user_bans, ban_appeals
-- 10_artist_profiles.sql → artist_profiles (cache)
