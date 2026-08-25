UPDATE entap_player_sessions
SET scopes = ARRAY(
  SELECT DISTINCT scope
  FROM unnest(scopes || ARRAY['economy:read', 'economy:spend', 'progression:claim']::TEXT[]) AS scope
  ORDER BY scope
)
WHERE revoked_at IS NULL
  AND expires_at > now();

INSERT INTO rank_audit_events (event_type, payload)
VALUES ('player_session_scope_migration', jsonb_build_object(
  'scopes', jsonb_build_array('economy:read', 'economy:spend', 'progression:claim'),
  'authority', 'migration_008',
  'applies_to', 'active_unrevoked_sessions'
));
