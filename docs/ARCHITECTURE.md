# Architecture & Design Decisions

## Overview

StreamVault DB is designed around a **read-heavy, write-occasional** workload pattern typical of social streaming platforms: millions of reads (feeds, reviews, ratings) against a relatively modest volume of writes (new ratings, comments, votes). Every design decision flows from this constraint.

---

## Layered Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        API Layer (PostgREST)                     │
│              Auto-generated REST from PostgreSQL schema          │
└────────────────────────────┬────────────────────────────────────┘
                             │
┌────────────────────────────▼────────────────────────────────────┐
│                    Row Level Security (RLS)                       │
│         All access filtered by auth.uid() before reaching DB     │
└────────────────────────────┬────────────────────────────────────┘
                             │
┌────────────────────────────▼────────────────────────────────────┐
│                    Business Logic Layer                           │
│              SECURITY DEFINER stored procedures                  │
│         (reputation updates, synthesis sessions, counters)       │
└────────────────────────────┬────────────────────────────────────┘
                             │
┌────────────────────────────▼────────────────────────────────────┐
│                      Data Storage Layer                           │
│                                                                   │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────────────┐   │
│  │  Core Tables │  │    Views      │  │  Aggregate Counters  │   │
│  │  (19 tables) │  │  (avg scores) │  │  (play_count, likes) │   │
│  └─────────────┘  └──────────────┘  └──────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

---

## Data Flow

### Content Feed Request

```
Client GET /track_ratings?audius_track_id=eq.xxx&order=reputation.desc
    → RLS: SELECT allowed for anon (public reviews)
    → Index scan: idx_track_ratings_rep (partial, WHERE review IS NOT NULL)
    → Returns: rows with denormalized username, avatar (no JOIN needed)
```

### Vote Cast

```
Client POST /rpc/update_review_reputation
    1. INSERT into review_votes (ON CONFLICT DO UPDATE vote)
    2. SECURITY DEFINER function runs with elevated privileges:
       SELECT SUM(vote) FROM review_votes WHERE rating_id = $1
       UPDATE track_ratings SET reputation = $sum WHERE id = $1
    → Atomic: single transaction, no race condition
```

### Play Count Tracking

```
Client POST /rpc/increment_track_play_count
    INSERT INTO favorite_tracks (..., play_count = 1)
    ON CONFLICT (user_id, track_id)
    DO UPDATE SET play_count = favorite_tracks.play_count + 1
    → Single round-trip, lock-free increment
```

---

## Key Design Decisions

### 1. UUID Primary Keys

All modern tables use `gen_random_uuid()` instead of SERIAL. Benefits:
- No hot-spot contention on B-tree index with sequential inserts
- Globally unique — safe for distributed systems and data merges
- No information leakage (can't guess record count from ID)

### 2. Strategic Denormalization

`track_ratings`, `track_comments`, and `playlists` store `username` and `user_avatar_url` directly:

```sql
-- Without denormalization (2 queries or expensive JOIN)
SELECT tr.*, p.username, p.avatar_url
FROM track_ratings tr
JOIN profiles p ON p.id = tr.user_id
WHERE audius_track_id = $1;

-- With denormalization (single indexed scan, no JOIN)
SELECT * FROM track_ratings WHERE audius_track_id = $1;
```

Trade-off: username changes are not back-propagated. Acceptable for social content — industry standard (Reddit, Twitter follow the same pattern).

### 3. Generated Columns vs Application Logic

`overall_score` uses PostgreSQL's `GENERATED ALWAYS AS ... STORED`:

```sql
overall_score NUMERIC(4,2) GENERATED ALWAYS AS (
    CASE WHEN all_five_present
    THEN (rhyme + imagery + structure + charisma + atmosphere) / 5.0
    ELSE NULL END
) STORED
```

This eliminates an entire class of bugs: the score is always mathematically consistent with the criteria scores. No trigger, no application code, no chance of drift.

### 4. SECURITY DEFINER for Cross-User Operations

RLS prevents User A from updating User B's rows — this is correct and desired. But some operations legitimately need to cross user boundaries (e.g., User B's vote must update User A's review reputation). The solution:

```sql
CREATE FUNCTION update_review_reputation(p_rating_id UUID)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    UPDATE track_ratings SET reputation = (
        SELECT COALESCE(SUM(vote), 0) FROM review_votes WHERE rating_id = p_rating_id
    ) WHERE id = p_rating_id;
END;
$$;
```

The function runs with the owner's privileges but performs only a tightly scoped, auditable operation.

### 5. Atomic Upsert Pattern

Play counts use `INSERT ... ON CONFLICT DO UPDATE` instead of SELECT + UPDATE:

```sql
INSERT INTO favorite_tracks (user_id, track_id, play_count, ...)
VALUES ($1, $2, 1, ...)
ON CONFLICT (user_id, track_id)
DO UPDATE SET play_count = favorite_tracks.play_count + 1;
```

This is fully atomic — no TOCTOU race condition, no need for advisory locks, and works correctly even under high concurrency.

---

## Scalability

### Current State

The schema is designed to handle millions of users and hundreds of millions of rows across core tables without schema changes.

### Horizontal Read Scaling

When read load exceeds a single instance:
1. **Read replicas** — PostgreSQL streaming replication to read replicas
2. **PostgREST connection pooling** — PgBouncer in front of PostgREST
3. **CDN caching** — `track_ratings_avg` responses are cacheable per track ID

### Vertical Scaling Checkpoints

| Condition | Action |
|-----------|--------|
| `track_history` > 50M rows | Partition by `played_at` (monthly ranges) |
| `track_ratings_avg` view > 100ms | Convert to Materialized View with pg_cron refresh |
| `review_votes` > 100M rows | Partition by `created_at` |
| Full-text search needed on reviews | Add `tsvector` column + GIN index |

### Caching Layer

```
Client → CDN → PostgREST → RLS → PostgreSQL
                    ↑
              Cache public endpoints:
              - /track_ratings_avg (TTL: 5 min per track)
              - /custom_artists (TTL: 1 hour)
              - /playlists?is_public=eq.true (TTL: 5 min)
```

---

## Future Improvements

### Short-term
- **Materialized View** for `track_ratings_avg` with scheduled refresh (removes live GROUP BY)
- **Full-text search** index on `track_ratings.review` using `tsvector` + GIN
- **Notification system** — `pg_notify` for real-time synthesis session updates

### Medium-term
- **Table partitioning** for `track_history` (by month) and `review_votes` (by quarter)
- **Audit log table** — immutable append-only log of all RLS-sensitive mutations
- **Soft delete pattern** — `deleted_at` column instead of hard delete for content recovery

### Long-term
- **Multi-tenancy** — schema-per-tenant or row-level tenant isolation for B2B licensing
- **Read replica routing** — route read-only queries to replicas automatically
- **Event sourcing** for reputation — store vote events rather than just the aggregate
- **pgvector extension** — store track embedding vectors for ML-based recommendations
