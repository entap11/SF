export type EconomyGuardResult = {
  ok: false;
  err: "economy_disabled";
  code: "economy_disabled";
};

function enabled(value: string | undefined): boolean {
  return ["1", "true", "yes", "on"].includes(String(value ?? "").trim().toLowerCase());
}

export function economyMutationsEnabled(): boolean {
  return enabled(process.env.VS_ECONOMY_MUTATIONS_ENABLED);
}

export function economyResetEnabled(): boolean {
  return enabled(process.env.VS_ECONOMY_RESET_ENABLED);
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
