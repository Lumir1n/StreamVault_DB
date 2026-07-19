# Performance Architecture

## Overview

The schema is designed for a read-heavy workload typical of streaming platforms: millions of reads per day against a modest number of writes. Several deliberate design decisions optimize for low-latency reads at the cost of some write complexity.

---

## Indexing Strategy

### Primary Indexes

Every table has a UUID primary key with a default B-tree index. UUIDs use `gen_random_uuid()` — random distribution prevents B-tree hotspot issues seen with sequential IDs.

### Application-Specific Indexes

| Table | Index | Rationale |
|-------|-------|-----------|
| `profiles` | `(username)` | Username search/autocomplete |
| `profiles` | `(is_public) WHERE is_public=TRUE` | Partial index — only public profiles need fast lookup |
| `favorite_tracks` | `(user_id, play_count DESC)` | Top tracks feed — most common sort |
| `favorite_artists` | `(user_id, play_count DESC)` | Top artists feed |
| `track_history` | `(user_id, played_at DESC)` | History feed — time-ordered per user |
| `track_ratings` | `(audius_track_id)` | All reviews for a track |
| `track_ratings` | `(reputation DESC) WHERE review IS NOT NULL` | Partial index — only reviews need reputation sort |
| `track_ratings` | `(overall_score DESC NULLS LAST)` | Score leaderboard |
| `track_comments` | `(audius_track_id, created_at DESC)` | Comments feed for a track |
| `playlists` | `(is_public, likes_count DESC) WHERE is_public=TRUE` | Public playlist discovery |
| `synthesis_sessions` | `LOWER(invite_code)` | Case-insensitive code lookup |
| `custom_artists` | `LOWER(name)` | Case-insensitive name search |
| `custom_tracks` | `LOWER(title)` | Case-insensitive title search (ilike queries) |
| `reports` | `(status, created_at DESC)` | Admin moderation queue |

---

## Denormalization

### Why We Denormalize

The reviews and comments feeds are the highest-read endpoints. Displaying `username` and `avatar_url` alongside content without denormalization would require a JOIN to `profiles` on every row — O(N) extra queries or a JOIN on a large table.

**Denormalized fields:**
- `track_ratings.username`, `track_ratings.user_avatar_url`
- `track_comments.username`, `track_comments.user_avatar_url`
- `playlists.username`, `playlists.user_avatar_url`

**Trade-off:** Username changes are not back-propagated to historical content. This is standard for social platforms (Twitter, Reddit follow the same pattern).

---

## Aggregated View

`track_ratings_avg` is a VIEW that pre-defines the GROUP BY aggregation:

```sql
SELECT
    audius_track_id,
    ROUND(AVG(rhyme_score)::NUMERIC, 2)      AS avg_rhyme,
    -- ...
    COUNT(*) FILTER (WHERE overall_score IS NOT NULL) AS rating_count
FROM public.track_ratings
GROUP BY audius_track_id;
```

Without this view, every track page request would trigger a full GROUP BY scan. The view can be replaced with a **Materialized View** + periodic refresh for even better performance at scale.

---

## Atomic Counter Pattern

`play_count` on `favorite_tracks` and `favorite_artists`, and `likes_count` on `playlists` use atomic upsert:

```sql
INSERT INTO favorite_tracks (user_id, track_id, play_count, ...)
VALUES (...)
ON CONFLICT (user_id, track_id)
DO UPDATE SET play_count = favorite_tracks.play_count + 1;
```

This is a single round-trip, no SELECT + UPDATE race condition. Equivalent to `INCR` in Redis but fully ACID.

---

## Generated Column

`track_ratings.overall_score` is a `GENERATED ALWAYS AS ... STORED` column:

```sql
overall_score NUMERIC(4,2) GENERATED ALWAYS AS (
    CASE WHEN all_five_criteria_present
    THEN (rhyme + imagery + structure + charisma + atmosphere) / 5.0
    ELSE NULL END
) STORED
```

No trigger, no application logic, no chance of inconsistency. PostgreSQL computes and indexes it automatically.

---

## Recommended Future Optimizations

| Optimization | When to apply |
|-------------|--------------|
| Materialized View for `track_ratings_avg` | When reads on this view exceed 1k/min |
| Partitioning `track_history` by month | When history table exceeds 50M rows |
| Connection pooling (PgBouncer) | At production scale |
| Read replicas | When reads > 80% of DB load |
| Full-text search index (`tsvector`) on `track_ratings.review` | When text search is needed |
