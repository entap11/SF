-- Replace only the operation constraints; retain all lease and FK checks.
DO $$ DECLARE item record; BEGIN
  FOR item IN SELECT conname FROM pg_constraint
    WHERE conrelid = 'vs_platform_economy_deliveries'::regclass AND contype = 'c'
      AND pg_get_constraintdef(oid) LIKE '%operation%'
  LOOP EXECUTE format('ALTER TABLE vs_platform_economy_deliveries DROP CONSTRAINT %I', item.conname); END LOOP;
END $$;
ALTER TABLE vs_platform_economy_deliveries ADD CONSTRAINT quest_delivery_operation_check
  CHECK (operation IN ('QUEST_ACTIVITY','HONEY_ACTIVITY','NECTAR_MATCH','CRUCIBLE_RESERVE','CRUCIBLE_SETTLE','CRUCIBLE_REFUND'));
ALTER TABLE vs_platform_economy_deliveries ADD CONSTRAINT quest_delivery_player_check
  CHECK ((operation IN ('QUEST_ACTIVITY','HONEY_ACTIVITY','NECTAR_MATCH','CRUCIBLE_RESERVE') AND player_id IS NOT NULL)
    OR operation IN ('CRUCIBLE_SETTLE','CRUCIBLE_REFUND'));
