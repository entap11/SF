ALTER TABLE vs_match_queue_tickets
  DROP CONSTRAINT IF EXISTS vs_match_queue_tickets_mode_id_check;

ALTER TABLE vs_match_queue_tickets
  ADD CONSTRAINT vs_match_queue_tickets_mode_id_check
  CHECK (mode_id IN ('STANDARD_1V1', 'CTF_1V1', 'HCTF_1V1'));

COMMENT ON CONSTRAINT vs_match_queue_tickets_mode_id_check ON vs_match_queue_tickets IS
  'Authenticated two-seat human queues only. Bot fallback creates a separate practice contract and cancels the source ticket.';
