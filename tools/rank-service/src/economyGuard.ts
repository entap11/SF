export type EconomyGuardResult = {
  ok: false;
  err: "economy_disabled";
  code: "economy_disabled";
};

export const RANK_ECONOMY_MUTATION_ACTIONS = new Set([
  "admin_recompute",
  "record_match_result",
  "record_contest_result",
  "apply_decay_tick",
  "debug_set_player_wax",
  "debug_set_last_active"
]);

// These routes belong to the pre-Platform Rank implementation. Keeping the
// classification explicit makes it impossible to revive a second economy
// writer by changing an environment flag.
export const RANK_SUPERSEDED_ACTIONS = new Set([
  "register_player",
  ...RANK_ECONOMY_MUTATION_ACTIONS
]);

function enabled(value: string | undefined): boolean {
  return ["1", "true", "yes", "on"].includes(String(value ?? "").trim().toLowerCase());
}

export function economyMutationsEnabled(): boolean {
  return enabled(process.env.RANK_ECONOMY_MUTATIONS_ENABLED);
}

export function economyResetEnabled(): boolean {
  return enabled(process.env.RANK_ECONOMY_RESET_ENABLED);
}

export function economyResetPermitted(): boolean {
  return economyResetEnabled() && economyMutationsEnabled();
}

export function economyDisabledResult(): EconomyGuardResult {
  return { ok: false, err: "economy_disabled", code: "economy_disabled" };
}

export function guardEconomyMutation(): EconomyGuardResult | null {
  return economyMutationsEnabled() ? null : economyDisabledResult();
}

export function isRankEconomyMutationAction(action: string): boolean {
  return RANK_ECONOMY_MUTATION_ACTIONS.has(action.trim());
}

export function isRankSupersededAction(action: string): boolean {
  return RANK_SUPERSEDED_ACTIONS.has(action.trim());
}

export function rankMutationHttpStatus(result: unknown): number {
  if (typeof result === "object" && result != null && "code" in result
    && (result as { code?: unknown }).code === "economy_disabled") {
    return 503;
  }
  return 200;
}

export function rankTokenAuthorized(configuredToken: string, suppliedToken: string): boolean {
  const configured = configuredToken.trim();
  return configured.length > 0 && suppliedToken.trim() === configured;
}
