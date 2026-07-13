class_name EconomyEpoch
extends RefCounted

# Bump this value only when all beta economy records must start from a clean slate.
# Client saves persist the applied value, so each epoch is applied exactly once.
const CURRENT: String = "beta_2026071301"
const STARTING_HONEY: int = 0
