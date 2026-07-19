-- =============================================================
-- VIEW: track_ratings_avg
-- Aggregated average scores per track across all user ratings.
-- Read-only. Accessible by anon role (no auth required).
-- Used to display "community average" on track pages and feeds.
-- =============================================================

CREATE OR REPLACE VIEW public.track_ratings_avg AS
SELECT
    audius_track_id,
    ROUND(AVG(rhyme_score)::NUMERIC,      2) AS avg_rhyme,
    ROUND(AVG(imagery_score)::NUMERIC,    2) AS avg_imagery,
    ROUND(AVG(structure_score)::NUMERIC,  2) AS avg_structure,
    ROUND(AVG(charisma_score)::NUMERIC,   2) AS avg_charisma,
    ROUND(AVG(atmosphere_score)::NUMERIC, 2) AS avg_atmosphere,
    ROUND(AVG(overall_score)::NUMERIC,    2) AS avg_overall,
    COUNT(*) FILTER (WHERE overall_score IS NOT NULL)       AS rating_count,
    COUNT(*) FILTER (WHERE review IS NOT NULL AND review <> '') AS review_count
FROM public.track_ratings
GROUP BY audius_track_id;

COMMENT ON VIEW public.track_ratings_avg IS
    'Pre-aggregated view of average scores per track. '
    'Avoids expensive GROUP BY on every API request. '
    'Readable by anon role — used for public track pages.';

-- Grant read access to anon and authenticated roles
GRANT SELECT ON public.track_ratings_avg TO anon, authenticated;
