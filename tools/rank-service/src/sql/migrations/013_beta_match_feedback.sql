-- Feedback is a separate, once-accepted annotation; payload_gzip stays immutable.
ALTER TABLE sf_beta_captures
  ADD COLUMN feedback JSONB,
  ADD COLUMN feedback_sha256 TEXT,
  ADD COLUMN feedback_received_at TIMESTAMPTZ,
  ADD CONSTRAINT sf_beta_feedback_receipt CHECK (
    (feedback IS NULL AND feedback_sha256 IS NULL AND feedback_received_at IS NULL)
    OR (feedback IS NOT NULL AND feedback_sha256 IS NOT NULL AND feedback_received_at IS NOT NULL
        AND jsonb_typeof(feedback) = 'object' AND feedback_sha256 ~ '^[a-f0-9]{64}$')
  );
