-- =============================================================
-- QUERY EXAMPLES
-- Practical SQL queries demonstrating schema capabilities.
-- =============================================================


-- ─────────────────────────────────────────────────────────────
-- 1. Get all reviews for a track, sorted by reputation
-- ─────────────────────────────────────────────────────────────
SELECT
    tr.username,
    tr.overall_score,
    tr.rhyme_score,
    tr.imagery_score,
    tr.structure_score,
    tr.charisma_score,
    tr.atmosphere_score,
    tr.review,
    tr.reputation,
    tr.created_at
FROM   public.track_ratings tr
WHERE  tr.audius_track_id = 'your-track-id'
  AND  tr.review IS NOT NULL
ORDER  BY tr.reputation DESC, tr.overall_score DESC;


-- ─────────────────────────────────────────────────────────────
-- 2. Get community average rating for a track
-- ─────────────────────────────────────────────────────────────
SELECT
    avg_rhyme,
    avg_imagery,
    avg_structure,
    avg_charisma,
    avg_atmosphere,
    avg_overall,
    rating_count,
    review_count
FROM   public.track_ratings_avg
WHERE  audius_track_id = 'your-track-id';


-- ─────────────────────────────────────────────────────────────
-- 3. Get top 10 tracks by average score (minimum 5 ratings)
-- ─────────────────────────────────────────────────────────────
SELECT
    audius_track_id,
    avg_overall,
    avg_atmosphere,
    rating_count,
    review_count
FROM   public.track_ratings_avg
WHERE  rating_count >= 5
ORDER  BY avg_overall DESC
LIMIT  10;


-- ─────────────────────────────────────────────────────────────
-- 4. Get user's listening profile: top tracks and artists
-- ─────────────────────────────────────────────────────────────
-- Top tracks
SELECT
    track_title,
    track_artist,
    play_count,
    added_at
FROM   public.favorite_tracks
WHERE  user_id = 'user-uuid-here'
ORDER  BY play_count DESC
LIMIT  20;

-- Top artists
SELECT
    artist_name,
    play_count
FROM   public.favorite_artists
WHERE  user_id = 'user-uuid-here'
ORDER  BY play_count DESC
LIMIT  10;


-- ─────────────────────────────────────────────────────────────
-- 5. Find users with the most high-reputation reviews
-- ─────────────────────────────────────────────────────────────
SELECT
    tr.username,
    COUNT(*)                                  AS review_count,
    ROUND(AVG(tr.overall_score)::NUMERIC, 2)  AS avg_score,
    SUM(tr.reputation)                        AS total_reputation
FROM   public.track_ratings tr
WHERE  tr.review IS NOT NULL
GROUP  BY tr.username
HAVING COUNT(*) >= 3
ORDER  BY total_reputation DESC, avg_score DESC
LIMIT  20;


-- ─────────────────────────────────────────────────────────────
-- 6. Get reputation integrity check
-- Are all stored reputation values in sync with vote sums?
-- ─────────────────────────────────────────────────────────────
SELECT
    tr.id,
    tr.username,
    tr.track_title,
    tr.reputation                          AS stored_reputation,
    COALESCE(SUM(rv.vote), 0)              AS calculated_reputation,
    CASE
        WHEN tr.reputation = COALESCE(SUM(rv.vote), 0) THEN 'OK'
        ELSE 'MISMATCH'
    END                                    AS integrity_status
FROM   public.track_ratings tr
LEFT   JOIN public.review_votes rv ON rv.rating_id = tr.id
GROUP  BY tr.id, tr.username, tr.track_title, tr.reputation
ORDER  BY integrity_status DESC, tr.reputation DESC;


-- ─────────────────────────────────────────────────────────────
-- 7. Get moderation queue: unresolved reports with strike counts
-- ─────────────────────────────────────────────────────────────
SELECT
    r.id                 AS report_id,
    r.target_type,
    r.reason,
    r.target_username,
    r.target_content,
    r.created_at,
    COUNT(cs.id)         AS strike_count
FROM   public.reports       r
LEFT   JOIN public.content_strikes cs ON cs.user_id = r.target_user_id
WHERE  r.status = 'pending'
GROUP  BY r.id, r.target_type, r.reason, r.target_username, r.target_content, r.created_at
ORDER  BY strike_count DESC, r.created_at ASC;


-- ─────────────────────────────────────────────────────────────
-- 8. Track playlist membership across the platform
-- ─────────────────────────────────────────────────────────────
SELECT
    pt.track_title,
    pt.track_artist,
    COUNT(DISTINCT pt.playlist_id)          AS playlist_count,
    COUNT(DISTINCT pl.user_id)              AS unique_users
FROM   public.playlist_tracks pt
JOIN   public.playlists       pl ON pl.id = pt.playlist_id
WHERE  pl.is_public = TRUE
GROUP  BY pt.track_title, pt.track_artist
ORDER  BY playlist_count DESC
LIMIT  20;


-- ─────────────────────────────────────────────────────────────
-- 9. Synthesis session analysis
-- ─────────────────────────────────────────────────────────────
SELECT
    ss.invite_code,
    ss.status,
    ss.created_at,
    COUNT(sp.id)    AS participant_count,
    pl.name         AS playlist_name,
    pl.track_count
FROM   public.synthesis_sessions   ss
LEFT   JOIN public.synthesis_participants sp ON sp.session_id = ss.id
LEFT   JOIN public.playlists              pl ON pl.id = ss.playlist_id
GROUP  BY ss.id, ss.invite_code, ss.status, ss.created_at, pl.name, pl.track_count
ORDER  BY ss.created_at DESC;


-- ─────────────────────────────────────────────────────────────
-- 10. Sync all reputation values (maintenance script)
-- Run after any manual data corrections
-- ─────────────────────────────────────────────────────────────
SELECT public.update_review_reputation(id)
FROM   public.track_ratings;
