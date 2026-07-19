# Setup Guide

## Prerequisites

- PostgreSQL 14+ **or** a [Supabase](https://supabase.com) project (free tier works)
- `psql` CLI client
- Git

---

## Option A: Supabase (Recommended)

Supabase provides hosted PostgreSQL with Auth, Storage, and auto-generated REST API.

### 1. Create a Supabase Project

1. Go to [supabase.com](https://supabase.com) → New Project
2. Note your **Project URL** and **anon key** from Settings → API

### 2. Open SQL Editor

In Supabase Dashboard → SQL Editor

### 3. Run schema files in order

Paste and run each file sequentially:

```
schema/01_profiles.sql
schema/02_activity.sql
schema/03_ratings.sql
schema/04_comments.sql
schema/05_review_votes.sql
schema/06_playlists.sql
schema/07_synthesis.sql
schema/08_custom_content.sql
schema/09_moderation.sql
```

### 4. Apply Views

```
views/track_ratings_avg.sql
```

### 5. Apply Functions

```
functions/increment_play_count.sql
functions/update_review_reputation.sql
functions/synthesis_management.sql
functions/playlist_likes.sql
```

### 6. Apply RLS Policies

```
rls/profiles_rls.sql
rls/ratings_rls.sql
rls/playlists_rls.sql
rls/moderation_rls.sql
```

### 7. (Optional) Load Example Data

```
seed/seed_example.sql
```

---

## Option B: Local PostgreSQL

### 1. Install PostgreSQL

```bash
# macOS
brew install postgresql@15

# Ubuntu/Debian
sudo apt install postgresql-15

# Windows
# Download from https://www.postgresql.org/download/windows/
```

### 2. Create Database

```bash
createdb streamvault_db
psql -d streamvault_db
```

### 3. Apply Schema

```bash
# Apply all files in order
for f in schema/0*.sql; do psql -d streamvault_db -f "$f"; done
psql -d streamvault_db -f views/track_ratings_avg.sql
for f in functions/*.sql; do psql -d streamvault_db -f "$f"; done
for f in rls/*.sql; do psql -d streamvault_db -f "$f"; done
```

### 4. Verify Installation

```sql
-- Check all tables exist
SELECT table_name
FROM   information_schema.tables
WHERE  table_schema = 'public'
ORDER  BY table_name;

-- Should return 19 tables + 1 view

-- Check functions
SELECT routine_name
FROM   information_schema.routines
WHERE  routine_schema = 'public'
  AND  routine_type = 'FUNCTION';
```

---

## Configuration

### Environment Variables

When connecting from an application:

```env
DATABASE_URL=postgresql://postgres:password@localhost:5432/streamvault_db

# For Supabase
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key  # Never expose publicly
```

### Storage Buckets (Supabase only)

Create three storage buckets in Supabase Dashboard → Storage:

| Bucket | Public | Purpose |
|--------|--------|---------|
| `avatars` | Yes | User profile photos |
| `playlist-covers` | Yes | Playlist cover images |
| `admin-uploads` | Yes | Admin-managed artists and tracks |

---

## Reset / Drop All

```sql
-- Drop everything in reverse dependency order
DROP TABLE IF EXISTS
    ban_appeals, user_bans, content_strikes, reports,
    custom_tracks, custom_artists,
    synthesis_participants, synthesis_sessions,
    playlist_likes, playlist_tracks, playlists,
    review_votes, track_comments, track_ratings,
    track_history, favorite_artists, favorite_tracks,
    profiles
CASCADE;

DROP VIEW IF EXISTS track_ratings_avg;

DROP FUNCTION IF EXISTS
    update_review_reputation,
    increment_track_play_count,
    increment_artist_play_count,
    get_or_create_synthesis_session,
    find_synthesis_session_by_code,
    find_existing_synthesis,
    get_or_create_synthesis_playlist,
    increment_playlist_likes,
    decrement_playlist_likes;
```
