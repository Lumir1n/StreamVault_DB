# Security Architecture

## Overview

The database employs a defense-in-depth security model with multiple layers: authentication, authorization via Row Level Security, and privilege separation through stored procedures.

---

## Authentication

All API access requires a valid JWT issued by Supabase Auth. The JWT contains the user's UUID and role (`anon`, `authenticated`, or `service_role`). Every database function receives the caller's identity via `auth.uid()`.

---

## Row Level Security (RLS)

RLS is **enabled on all 19 tables**. No table is accessible without an explicit policy.

### Policy Design Principles

| Principle | Implementation |
|-----------|---------------|
| Least privilege | Each policy grants the minimum required access |
| Owner isolation | Users can only mutate their own rows (`auth.uid() = user_id`) |
| Public read | Selected tables allow `anon` read for public content |
| Service bypass | Admin operations use `service_role` which bypasses RLS |

### Role Matrix

| Table | anon | authenticated | service_role |
|-------|------|---------------|--------------|
| profiles | SELECT (public only) | SELECT, INSERT (own), UPDATE (own) | ALL |
| track_ratings | SELECT | SELECT, INSERT (own), UPDATE (own), DELETE (own) | ALL |
| track_comments | SELECT | SELECT, INSERT, DELETE (own) | ALL |
| review_votes | — | ALL (own) | ALL |
| playlists | SELECT (public) | ALL (own) | ALL |
| playlist_tracks | SELECT (public pl.) | ALL (own pl.) | ALL |
| custom_artists | SELECT | SELECT | ALL |
| custom_tracks | SELECT (published) | SELECT | ALL |
| reports | — | INSERT (own), SELECT (own) | ALL |
| user_bans | — | SELECT (own) | ALL |
| ban_appeals | — | INSERT (own), SELECT (own) | ALL |

---

## SECURITY DEFINER Functions

Some operations require elevated privileges to bypass RLS while still being safe. These use `SECURITY DEFINER`:

| Function | Why DEFINER is needed |
|----------|----------------------|
| `update_review_reputation` | User B needs to update User A's `track_ratings.reputation` after voting — normally blocked by RLS |
| `increment_track_play_count` | Upsert into `favorite_tracks` — needs to insert/update cross-user context atomically |
| `increment_artist_play_count` | Same as above for artists |
| `get_or_create_synthesis_session` | Needs to read/write sessions without exposing other users' sessions |
| `get_or_create_synthesis_playlist` | Atomic playlist creation with session update |

All SECURITY DEFINER functions:
- Have `REVOKE ALL FROM PUBLIC` then explicit `GRANT` to specific roles
- Use `SET search_path = public` to prevent search path injection
- Perform only tightly scoped, auditable operations

---

## Data Protection

### Denormalization Trade-offs
`username` and `user_avatar_url` are stored redundantly in `track_ratings` and `track_comments`. This means username changes are not automatically propagated. This is an intentional trade-off for read performance — acceptable for a social platform where historical content preserves the author's name at time of posting.

### Soft Bans
When a user is banned:
1. `user_bans.is_active = TRUE`
2. `profiles.is_banned = TRUE` (synced by application)
3. Application checks `is_banned` flag before allowing writes

### Content Moderation Pipeline
```
User submits report
    ↓
reports table (status: pending)
    ↓
Admin reviews → resolves or dismisses
    ↓ (resolved)
Content deleted + content_strike added to user
    ↓ (5+ strikes)
user_bans upsert → is_active = TRUE
    ↓
User submits ban_appeal
    ↓
Admin approves → is_active = FALSE
```

---

## Secrets Management

- API keys are never stored in the database
- Supabase `anon` key is public by design (protected by RLS)
- `service_role` key never leaves the server environment
- Storage bucket policies restrict file access independently of table RLS
