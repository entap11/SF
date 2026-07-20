import { config } from "../config.js";
import { durablePool } from "../db/pool.js";
import type { DurableCoreRepository } from "./durableCore.js";
import { MemoryDurableCoreRepository } from "./memoryDurableCoreRepository.js";
import { PostgresDurableCoreRepository } from "./postgresDurableCoreRepository.js";
import type { Public1v1Repository } from "./public1v1.js";
import { MemoryPublic1v1Repository } from "./memoryPublic1v1Repository.js";
import { PostgresPublic1v1Repository } from "./postgresPublic1v1Repository.js";
import type { VerificationRepository } from "./verificationAuthority.js";
import { MemoryVerificationRepository } from "./memoryVerificationRepository.js";
import { PostgresVerificationRepository } from "./postgresVerificationRepository.js";
import { PostgresRankSettlementRepository } from "./rankSettlement.js";
import type { PublicContestRepository } from "./publicContest.js";
import { PostgresPublicContestRepository } from "./postgresPublicContestRepository.js";
import { PostgresCrucibleSettlementRepository } from "./crucibleSettlement.js";

let repository: DurableCoreRepository | null = null;
let public1v1Repository: Public1v1Repository | null = null;
let verificationRepository: VerificationRepository | null = null;
let rankSettlementRepository: PostgresRankSettlementRepository | null = null;
let publicContestRepository: PublicContestRepository | null = null;
let crucibleSettlementRepository: PostgresCrucibleSettlementRepository | null = null;

export function durableCoreStatus(): {
  enabled: boolean;
  kind: "memory" | "postgres";
  configured: boolean;
  retention_days: number;
} {
  return {
    enabled: config.durableCoreEnabled,
    kind: config.durableStore,
    configured: config.durableStore === "postgres" ? Boolean(config.databaseUrl) : !config.productionMode,
    retention_days: config.durableRetentionDays
  };
}

export function getDurableCoreRepository(): DurableCoreRepository {
  if (repository) return repository;
  if (config.productionMode && config.durableCoreEnabled && config.durableStore !== "postgres") {
    throw new Error("postgres_durable_store_required_in_production");
  }
  if (config.durableStore === "postgres") {
    if (!config.databaseUrl) throw new Error("VS_DATABASE_URL_required_for_postgres_durable_store");
    repository = new PostgresDurableCoreRepository(durablePool);
  } else {
    repository = new MemoryDurableCoreRepository();
  }
  return repository;
}

export function getPublic1v1Repository(): Public1v1Repository {
  if (public1v1Repository) return public1v1Repository;
  const core = getDurableCoreRepository();
  public1v1Repository = config.durableStore === "postgres"
    ? new PostgresPublic1v1Repository(durablePool, core)
    : new MemoryPublic1v1Repository(core);
  return public1v1Repository;
}

export function getVerificationRepository(): VerificationRepository {
  if (verificationRepository) return verificationRepository;
  const core = getDurableCoreRepository();
  verificationRepository = config.durableStore === "postgres"
    ? new PostgresVerificationRepository(durablePool, core)
    : new MemoryVerificationRepository(core);
  return verificationRepository;
}

export function getRankSettlementRepository(): PostgresRankSettlementRepository {
  if (config.durableStore !== "postgres") throw new Error("postgres_rank_settlement_store_required");
  rankSettlementRepository ??= new PostgresRankSettlementRepository(durablePool);
  return rankSettlementRepository;
}

export function getPublicContestRepository(): PublicContestRepository {
  if (config.durableStore !== "postgres") throw new Error("postgres_public_contest_store_required");
  if (!config.databaseUrl) throw new Error("VS_DATABASE_URL_required_for_public_contests");
  publicContestRepository ??= new PostgresPublicContestRepository(durablePool);
  return publicContestRepository;
}

export function getCrucibleSettlementRepository(): PostgresCrucibleSettlementRepository {
  if (config.durableStore !== "postgres") throw new Error("postgres_crucible_settlement_store_required");
  if (!config.databaseUrl) throw new Error("VS_DATABASE_URL_required_for_crucible_settlement");
  crucibleSettlementRepository ??= new PostgresCrucibleSettlementRepository(durablePool);
  return crucibleSettlementRepository;
}
