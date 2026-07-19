-- =============================================================
-- SEED DATA — Example / Development Data
-- Provides realistic sample data for development and testing.
-- DO NOT run in production.
-- =============================================================

-- NOTE: This seed assumes Supabase Auth users are created separately.
-- Replace UUIDs with real auth.users IDs in your environment.

-- =============================================================
-- Example Profiles
-- =============================================================

INSERT INTO public.profiles (id, username, email, bio, is_public, created_at)
VALUES
    ('11111111-1111-1111-1111-111111111111', 'alice_streams', 'alice@example.com',
     'Passionate about electronic music and deep dives.', TRUE, NOW() - INTERVAL '30 days'),
    ('22222222-2222-2222-2222-222222222222', 'bob_reviews', 'bob@example.com',
     'Hip-hop enthusiast. I rate everything.', TRUE, NOW() - INTERVAL '20 days'),
    ('33333333-3333-3333-3333-333333333333', 'charlie_listener', 'charlie@example.com',
     NULL, FALSE, NOW() - INTERVAL '10 days')
ON CONFLICT (id) DO NOTHING;


-- =============================================================
-- Example Custom Artist
-- =============================================================

INSERT INTO public.custom_artists (id, name, bio, genre, location, is_verified)
VALUES
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
     'Nova Collective',
     'An experimental electronic project blending ambient textures with rhythmic complexity.',
     'Experimental Electronic',
     'Berlin, Germany',
     TRUE)
ON CONFLICT (id) DO NOTHING;


-- =============================================================
-- Example Custom Tracks
-- =============================================================

INSERT INTO public.custom_tracks (id, artist_id, title, genre, duration, is_published)
VALUES
    ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
     'Liminal State',
     'Ambient',
     247,
     TRUE),
    ('cccccccc-cccc-cccc-cccc-cccccccccccc',
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
     'Signal Drift',
     'Experimental Electronic',
     312,
     TRUE)
ON CONFLICT (id) DO NOTHING;


-- =============================================================
-- Example Track Ratings
-- =============================================================

INSERT INTO public.track_ratings (
    user_id, audius_track_id, track_title, track_artist,
    rhyme_score, imagery_score, structure_score, charisma_score, atmosphere_score,
    review, username, reputation
)
VALUES
    ('11111111-1111-1111-1111-111111111111',
     'ext-track-001',
     'Midnight Echoes',
     'The Wanderers',
     8, 9, 7, 8, 10,
     'A hauntingly beautiful track. The atmosphere is unmatched — you can feel every layer building into something transcendent.',
     'alice_streams',
     5),
    ('22222222-2222-2222-2222-222222222222',
     'ext-track-001',
     'Midnight Echoes',
     'The Wanderers',
     7, 8, 9, 7, 8,
     'Solid production. The structure is tight and the charisma of the vocal performance keeps it interesting throughout.',
     'bob_reviews',
     3)
ON CONFLICT (user_id, audius_track_id) DO NOTHING;


-- =============================================================
-- Example Review Votes
-- =============================================================

-- Alice upvotes Bob's review
INSERT INTO public.review_votes (user_id, rating_id, vote)
SELECT
    '11111111-1111-1111-1111-111111111111',
    id,
    1
FROM public.track_ratings
WHERE user_id = '22222222-2222-2222-2222-222222222222'
  AND audius_track_id = 'ext-track-001'
ON CONFLICT (user_id, rating_id) DO NOTHING;

-- Sync reputation after seed
SELECT public.update_review_reputation(id)
FROM   public.track_ratings
WHERE  audius_track_id = 'ext-track-001';


-- =============================================================
-- Example Playlist
-- =============================================================

INSERT INTO public.playlists (id, user_id, name, description, is_public, username)
VALUES
    ('dddddddd-dddd-dddd-dddd-dddddddddddd',
     '11111111-1111-1111-1111-111111111111',
     'Late Night Sessions',
     'Tracks for deep listening after midnight.',
     TRUE,
     'alice_streams')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.playlist_tracks (playlist_id, track_id, track_title, track_artist, position)
VALUES
    ('dddddddd-dddd-dddd-dddd-dddddddddddd', 'ext-track-001', 'Midnight Echoes', 'The Wanderers', 1),
    ('dddddddd-dddd-dddd-dddd-dddddddddddd', 'ext-track-002', 'Coastal Drive', 'Seaside Beats', 2)
ON CONFLICT (playlist_id, track_id) DO NOTHING;


-- =============================================================
-- Verification Queries
-- =============================================================

-- Run these to verify seed data was inserted correctly:

-- SELECT username, email FROM profiles;
-- SELECT name, genre FROM custom_artists;
-- SELECT title, duration FROM custom_tracks;
-- SELECT username, track_title, overall_score, reputation FROM track_ratings ORDER BY overall_score DESC;
-- SELECT name, track_count FROM playlists;
