# Table Reference

Complete reference for all 19 tables and 1 view in the StreamVault DB schema.

---

## profiles

User accounts extending the authentication system.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | uuid | PK, FK→auth.users | Matches Supabase Auth user ID |
| username | text | NOT NULL | Display name |
| email | text | NOT NULL | User email (from auth) |
| bio | text | | Optional biography |
| favorite_genre | text | | User's preferred genre |
| avatar_url | text | | Storage object URL |
| is_public | bool | DEFAULT TRUE | Profile visibility |
| is_banned | bool | DEFAULT FALSE | Set by admin on ban |
| ban_reason | text | | Shown to banned user |
| created_at | timestamptz | DEFAULT NOW() | |
| updated_at | timestamptz | auto-updated | Trigger-maintained |

---

## favorite_tracks

Tracks engaged with by users. Doubles as "listening history summary".

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | uuid | PK | |
| user_id | uuid | FK→profiles | |
| track_id | text | NOT NULL | External track ID |
| track_title | text | NOT NULL | Denormalized |
| track_artist | text | NOT NULL | Denormalized |
| track_cover_url | text | | Denormalized |
| track_preview_url | text | | Denormalized |
| play_count | int | DEFAULT 0 | Incremented via RPC |
| added_at | timestamptz | DEFAULT NOW() | |

**Unique:** `(user_id, track_id)`

---

## favorite_artists

Artists engaged with by users.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | uuid | PK | |
| user_id | uuid | FK→profiles | |
| artist_id | text | NOT NULL | External artist ID |
| artist_name | text | NOT NULL | Denormalized |
| artist_image_url | text | | Denormalized |
| play_count | int | DEFAULT 0 | Incremented via RPC |
| added_at | timestamptz | DEFAULT NOW() | |

**Unique:** `(user_id, artist_id)`

---

## track_history

Append-only playback log. One row per listen event.

| Column | Type | Description |
|--------|------|-------------|
| id | uuid PK | |
| user_id | uuid FK→profiles | |
| track_id | text | |
| track_title | text | |
| track_artist | text | |
| track_artist_id | text | |
| played_at | timestamptz | |

---

## track_ratings

5-criteria structured music ratings with optional review text.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | uuid | PK | |
| user_id | uuid | FK→profiles | |
| audius_track_id | text | NOT NULL | |
| track_title / track_artist / track_cover_url | text | denormalized | |
| rhyme_score | smallint | CHECK 1-10 | Rhymes & Imagery |
| imagery_score | smallint | CHECK 1-10 | Structure & Rhythm |
| structure_score | smallint | CHECK 1-10 | Style Execution |
| charisma_score | smallint | CHECK 1-10 | Individuality |
| atmosphere_score | smallint | CHECK 1-10 | Atmosphere & Vibe |
| overall_score | numeric(4,2) | GENERATED STORED | Auto-computed average |
| review | text | | Optional long-form text |
| username / user_avatar_url | text | denormalized | |
| reputation | int | DEFAULT 0 | Maintained by RPC |
| created_at / updated_at | timestamptz | | |

**Unique:** `(user_id, audius_track_id)`

---

## track_ratings_avg (VIEW)

Aggregated averages per track. Read-only.

| Column | Type | Description |
|--------|------|-------------|
| audius_track_id | text | |
| avg_rhyme / avg_imagery / avg_structure / avg_charisma / avg_atmosphere | numeric | Per-criterion averages |
| avg_overall | numeric | Overall average |
| rating_count | bigint | Ratings with scores |
| review_count | bigint | Ratings with review text |

---

## track_comments

Free-text comments on tracks.

| Column | Type | Description |
|--------|------|-------------|
| id | uuid PK | |
| user_id | uuid FK | |
| audius_track_id | text | |
| comment | text | NOT NULL, non-empty |
| username / user_avatar_url | text | denormalized |
| created_at | timestamptz | |

---

## review_votes

Up/downvotes on track reviews (reputation system).

| Column | Type | Constraints |
|--------|------|-------------|
| id | uuid PK | |
| user_id | uuid FK→profiles | |
| rating_id | uuid FK→track_ratings | |
| vote | smallint | CHECK IN (-1, 1) |
| created_at | timestamptz | |

**Unique:** `(user_id, rating_id)`

---

## playlists

User-created track collections.

| Column | Type | Description |
|--------|------|-------------|
| id | uuid PK | |
| user_id | uuid FK | |
| name | text | NOT NULL |
| description / cover_url | text | |
| track_count | int | Maintained by app |
| is_public | bool | DEFAULT FALSE |
| is_synthesis | bool | DEFAULT FALSE |
| synthesis_code | text | Links to session |
| likes_count | int | Maintained by RPC |
| username / user_avatar_url | text | denormalized |
| created_at | timestamptz | |

---

## playlist_tracks

Ordered tracks in a playlist.

| Column | Type | Description |
|--------|------|-------------|
| id | uuid PK | |
| playlist_id | uuid FK→playlists | |
| track_id | text | External or custom |
| track_title / track_artist / track_cover_url / track_preview_url | text | denormalized |
| position | int | Sort order |
| added_at | timestamptz | |
| added_by_username / added_by_avatar | text | Who added it |

**Unique:** `(playlist_id, track_id)`

---

## playlist_likes

Many-to-many: users liking playlists.

| Column | Type |
|--------|------|
| id | uuid PK |
| user_id | uuid FK |
| playlist_id | uuid FK |
| created_at | timestamptz |

**Unique:** `(user_id, playlist_id)`

---

## synthesis_sessions

Collaborative playlist generation sessions.

| Column | Type | Description |
|--------|------|-------------|
| id | uuid PK | |
| creator_id | uuid FK | Session host |
| creator_username | text | Denormalized |
| invite_code | text | UNIQUE, 8 hex chars |
| name | text | DEFAULT 'Synthesis' |
| status | text | pending/active/completed/expired |
| playlist_id | uuid FK | Set after completion |
| created_at | timestamptz | |

---

## synthesis_participants

Users who joined a synthesis session.

| Column | Type |
|--------|------|
| id | uuid PK |
| session_id | uuid FK→synthesis_sessions |
| user_id | uuid FK→profiles |
| username / avatar_url | text (denorm) |
| joined_at | timestamptz |

**Unique:** `(session_id, user_id)`

---

## custom_artists

Platform-managed artists (admin content).

| Column | Type |
|--------|------|
| id | uuid PK |
| name | text NOT NULL |
| bio / genre / location | text |
| avatar_url / cover_url | text |
| is_verified | bool DEFAULT FALSE |
| created_at | timestamptz |

---

## custom_tracks

Platform-managed audio tracks (admin content).

| Column | Type |
|--------|------|
| id | uuid PK |
| artist_id | uuid FK→custom_artists |
| title | text NOT NULL |
| genre | text |
| duration | int (seconds) |
| audio_url / cover_url | text (Storage URLs) |
| play_count | int DEFAULT 0 |
| is_published | bool DEFAULT TRUE |
| created_at | timestamptz |

---

## reports

Content moderation reports.

| Column | Type |
|--------|------|
| id | uuid PK |
| reporter_id | uuid FK |
| target_type | text CHECK('comment','review') |
| target_id | uuid |
| reason | text NOT NULL |
| target_content / target_user_id / target_username / track_title | text |
| status | text CHECK('pending','resolved','dismissed') DEFAULT 'pending' |
| created_at | timestamptz |

---

## content_strikes

Individual strikes from content removal.

| Column | Type |
|--------|------|
| id | uuid PK |
| user_id | uuid FK |
| content_type | text |
| content_id | uuid |
| reason | text |
| created_at | timestamptz |

---

## user_bans

User ban records (one per user).

| Column | Type |
|--------|------|
| id | uuid PK |
| user_id | uuid UNIQUE FK |
| reason | text NOT NULL |
| is_active | bool DEFAULT TRUE |
| created_at | timestamptz |

---

## ban_appeals

Appeals by banned users.

| Column | Type |
|--------|------|
| id | uuid PK |
| user_id | uuid FK |
| ban_id | uuid FK→user_bans |
| message | text NOT NULL |
| username / email | text (denorm) |
| status | text CHECK('pending','approved','rejected') |
| reviewed_at | timestamptz |
| created_at | timestamptz |
