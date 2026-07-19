# Entity Relationships

## Entity-Relationship Diagram (Text)

```
auth.users (Supabase Auth)
    │
    │ 1:1 (ON DELETE CASCADE)
    ▼
profiles
    │
    ├──────────────────────────────────────────────────────┐
    │                                                      │
    │ 1:N                                                  │ 1:N
    ▼                                                      ▼
track_history                                        playlists
                                                          │
    │ 1:N                                                  ├── 1:N → playlist_tracks
    ▼                                                      ├── 1:N → playlist_likes
favorite_tracks                                            └── 1:1 → synthesis_sessions
                                                                          │
    │ 1:N                                                                 └── 1:N → synthesis_participants
    ▼
favorite_artists

    │ 1:N
    ▼
track_ratings  ──────────── 1:N ──────────── review_votes
    │
    └── (aggregated by VIEW) track_ratings_avg

    │ 1:N
    ▼
track_comments

    │ 1:N (as reporter)
    ▼
reports

    │ 1:1 (UNIQUE user_id)
    ▼
user_bans
    │
    └── 1:N → ban_appeals

    │ 1:N
    ▼
content_strikes

custom_artists
    │
    └── 1:N → custom_tracks
```

---

## Foreign Key Relationships

| From Table | Column | To Table | Column | On Delete |
|-----------|--------|----------|--------|-----------|
| profiles | id | auth.users | id | CASCADE |
| favorite_tracks | user_id | profiles | id | CASCADE |
| favorite_artists | user_id | profiles | id | CASCADE |
| track_history | user_id | profiles | id | CASCADE |
| track_ratings | user_id | profiles | id | CASCADE |
| track_comments | user_id | profiles | id | CASCADE |
| review_votes | user_id | profiles | id | CASCADE |
| review_votes | rating_id | track_ratings | id | CASCADE |
| playlists | user_id | profiles | id | CASCADE |
| playlist_tracks | playlist_id | playlists | id | CASCADE |
| playlist_likes | user_id | profiles | id | CASCADE |
| playlist_likes | playlist_id | playlists | id | CASCADE |
| synthesis_sessions | creator_id | profiles | id | CASCADE |
| synthesis_sessions | playlist_id | playlists | id | SET NULL |
| synthesis_participants | session_id | synthesis_sessions | id | CASCADE |
| synthesis_participants | user_id | profiles | id | CASCADE |
| custom_tracks | artist_id | custom_artists | id | SET NULL |
| reports | reporter_id | profiles | id | CASCADE |
| reports | target_user_id | profiles | id | SET NULL |
| user_bans | user_id | profiles | id | CASCADE |
| ban_appeals | user_id | profiles | id | CASCADE |
| ban_appeals | ban_id | user_bans | id | CASCADE |
| content_strikes | user_id | profiles | id | CASCADE |

---

## Unique Constraints

| Table | Unique On | Purpose |
|-------|-----------|---------|
| favorite_tracks | (user_id, track_id) | One entry per user+track |
| favorite_artists | (user_id, artist_id) | One entry per user+artist |
| track_ratings | (user_id, audius_track_id) | One rating per user+track |
| review_votes | (user_id, rating_id) | One vote per user+review |
| playlist_tracks | (playlist_id, track_id) | No duplicate tracks in playlist |
| playlist_likes | (user_id, playlist_id) | One like per user+playlist |
| synthesis_participants | (session_id, user_id) | No duplicate participants |
| synthesis_sessions | invite_code | Globally unique invite codes |
| user_bans | user_id | One ban record per user |

---

## Cascading Rules

**CASCADE DELETE** is used for all user-owned data — deleting a user removes all their content.

**SET NULL** is used for optional references where the parent can be deleted without orphaning the child (e.g., deleting a custom artist doesn't delete tracks, just clears `artist_id`).

---

## External References

Some tables store `TEXT` IDs referencing external API entities:

| Table | Column | External Source |
|-------|--------|----------------|
| favorite_tracks | track_id | External music API |
| favorite_artists | artist_id | External music API |
| track_history | track_id | External music API |
| track_ratings | audius_track_id | External music API |
| track_comments | audius_track_id | External music API |
| playlist_tracks | track_id | External API or custom_tracks.id |

These are stored as `TEXT` (not FK) because the referenced entities live outside PostgreSQL. Referential integrity for these is enforced at the application layer.
