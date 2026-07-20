UPDATE entap_player_sessions
SET scopes = ARRAY(
  SELECT DISTINCT scope
  FROM unnest(scopes || ARRAY['contest:play']::TEXT[]) AS scope
  ORDER BY scope
)
WHERE revoked_at IS NULL
  AND expires_at > now()
  AND NOT ('contest:play' = ANY(scopes));

INSERT INTO rank_audit_events (event_type, payload)
VALUES ('player_session_scope_migration', jsonb_build_object(
  'scope', 'contest:play',
  'authority', 'migration_006',
  'applies_to', 'active_unrevoked_sessions'
));
