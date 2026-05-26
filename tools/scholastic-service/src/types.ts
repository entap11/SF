export type Ecosystem = "NONE" | "SFA" | "SFU";

export interface SfaState {
  is_candidate: boolean;
  is_user: boolean;
  eligibility_status: string;
  eligible_for_school_team: boolean;
  school_id: string;
  current_school_year_attested: string;
  freshman_school_year: string;
  sfa_eligibility_end_start_year: number;
  school_enrollment_attested: boolean;
  school_enrollment_attested_at_unix: number;
  school_attestation_expires_school_year: string;
  transition_status: string;
  team_id: string;
  team_index: number;
  team_label: string;
  roster_slot: number;
  analytics_package_entitlements: string[];
  real_money_prize_eligible: boolean;
  sfa_progression_locked_from_adult_money_games: boolean;
}

export interface SfuState {
  college_program_id: string;
  college_team_id: string;
  program_affiliation_attested: boolean;
  program_affiliation_attested_at_unix: number;
  affiliation_school_year: string;
  sfu_status: string;
  recruiting_status: string;
  normal_comms_allowed: boolean;
  normal_money_games_allowed: boolean;
  normal_buffs_allowed: boolean;
}

export interface ScholasticProfile {
  player_id: string;
  display_name: string;
  age_years: number;
  ecosystem: Ecosystem;
  sfa: SfaState;
  sfu: SfuState;
  competitive: Record<string, unknown>;
  scholastic: Record<string, unknown>;
  privacy: Record<string, unknown>;
  communication_access: Record<string, unknown>;
  money_access: Record<string, unknown>;
}

export interface SchoolProgram {
  school_id: string;
  school_name: string;
  canonical_school_name: string;
  public_school_name: string;
  city: string;
  state: string;
  mascot_name: string;
  colors: string[];
  verification_status: string;
  school_hive_review_status: string;
  review_school_year: string;
  hive_bonus_eligible: boolean;
  hive_bonus_locked_reason: string;
  material_dispute_open: boolean;
  enrollment_complaints: Array<Record<string, unknown>>;
  teams: Array<Record<string, unknown>>;
  membership_by_player_id: Record<string, Record<string, unknown>>;
  attested_player_ids_by_school_year: Record<string, string[]>;
  created_at_unix: number;
  updated_at_unix: number;
}

export interface CollegeProgram {
  college_program_id: string;
  university_name: string;
  city: string;
  state: string;
  mascot_name: string;
  colors: string[];
  program_type: string;
  verification_status: string;
  membership_by_player_id: Record<string, Record<string, unknown>>;
  attested_player_ids_by_school_year: Record<string, string[]>;
  created_at_unix: number;
  updated_at_unix: number;
}

export interface ScholasticTournament {
  tournament_id: string;
  ecosystem: "SFA" | "SFU";
  tournament_type: string;
  title: string;
  buffs_allowed?: boolean;
  cash_prizes_allowed?: boolean;
  entry_fee_allowed?: boolean;
  program_roster_required?: boolean;
  official_sfu_event?: boolean;
  real_money_prizes_allowed?: boolean;
  counts_for_sfa_progression?: boolean;
  created_at_unix: number;
}

export interface ActivityEvent {
  event_id: string;
  player_id: string;
  ecosystem: Ecosystem;
  event_date: string;
  duration_seconds: number;
  is_new_player: boolean;
  props: Record<string, unknown>;
}

export interface ScholasticState {
  profiles: Record<string, ScholasticProfile>;
  schools: Record<string, SchoolProgram>;
  colleges: Record<string, CollegeProgram>;
  tournaments: Record<string, ScholasticTournament>;
  activity_events: ActivityEvent[];
}

export interface AuditEventInput {
  event_type: string;
  player_id?: string;
  related_id?: string;
  payload?: Record<string, unknown>;
}

export interface ScholasticServiceConfig {
  port: number;
  bindHost: string;
  databaseUrl: string;
  apiToken: string;
  adminToken: string;
  enableDebugActions: boolean;
}
