import { DurableCoreError, type RosterEntry } from "./durableCore.js";

export type MultiSeatMode = "STANDARD_3P_FFA" | "STANDARD_2V2" | "STANDARD_4P_FFA";

export type CompetitivePlayerSnapshot = {
  playerId: string;
  publicEntapId?: string | null;
  displayName: string;
  rankValue: number;
  joinedAt: string;
};

export type FriendEdge = { playerAId: string; playerBId: string };

export type AssignmentResult = {
  assignmentPolicyId: "SERVER_SEATS_COLORS_V1" | "FRIEND_THEN_RANK_V1";
  roster: RosterEntry[];
  evidence: {
    strategy: "FFA_UNIQUE" | "EXACT_FRIEND_PAIR" | "RANK_BALANCED";
    friendPairs: string[][];
    rankOrder: string[];
  };
};

const COLORS = ["GREEN", "PURPLE", "ORANGE", "BLUE"];

export function requiredPlayersForPublicMode(modeId: string): number {
  if (modeId === "STANDARD_3P_FFA") return 3;
  if (["STANDARD_2V2", "STANDARD_4P_FFA"].includes(modeId)) return 4;
  return 2;
}

export function assignMultiSeatRoster(
  modeId: MultiSeatMode,
  players: CompetitivePlayerSnapshot[],
  friendEdges: FriendEdge[]
): AssignmentResult {
  const required = requiredPlayersForPublicMode(modeId);
  if (players.length !== required || new Set(players.map((player) => player.playerId)).size !== required) {
    throw new DurableCoreError("multiseat_roster_invalid");
  }
  const rankOrder = [...players].sort((a, b) => b.rankValue - a.rankValue || a.playerId.localeCompare(b.playerId));
  if (modeId !== "STANDARD_2V2") {
    return {
      assignmentPolicyId: "SERVER_SEATS_COLORS_V1",
      roster: players.map((player, index) => rosterEntry(player, index, index + 1)),
      evidence: { strategy: "FFA_UNIQUE", friendPairs: [], rankOrder: rankOrder.map((player) => player.playerId) }
    };
  }
  const ids = new Set(players.map((player) => player.playerId));
  const pairs = friendEdges
    .filter((edge) => ids.has(edge.playerAId) && ids.has(edge.playerBId) && edge.playerAId !== edge.playerBId)
    .map((edge) => [edge.playerAId, edge.playerBId].sort())
    .filter((pair, index, all) => all.findIndex((candidate) => candidate.join("|") === pair.join("|")) === index)
    .sort((a, b) => a.join("|").localeCompare(b.join("|")));
  let ordered: CompetitivePlayerSnapshot[];
  let teams: Map<string, number>;
  let strategy: AssignmentResult["evidence"]["strategy"];
  if (pairs.length === 1) {
    const pairedIds = new Set(pairs[0]);
    const paired = players.filter((player) => pairedIds.has(player.playerId))
      .sort((a, b) => a.playerId.localeCompare(b.playerId));
    const others = players.filter((player) => !pairedIds.has(player.playerId))
      .sort((a, b) => a.playerId.localeCompare(b.playerId));
    ordered = [...paired, ...others];
    teams = new Map(ordered.map((player, index) => [player.playerId, index < 2 ? 1 : 2]));
    strategy = "EXACT_FRIEND_PAIR";
  } else {
    ordered = rankOrder;
    teams = new Map([
      [ordered[0].playerId, 1], [ordered[3].playerId, 1],
      [ordered[1].playerId, 2], [ordered[2].playerId, 2]
    ]);
    strategy = "RANK_BALANCED";
  }
  return {
    assignmentPolicyId: "FRIEND_THEN_RANK_V1",
    roster: ordered.map((player, index) => rosterEntry(player, index, teams.get(player.playerId) ?? 0)),
    evidence: { strategy, friendPairs: pairs, rankOrder: rankOrder.map((player) => player.playerId) }
  };
}

function rosterEntry(player: CompetitivePlayerSnapshot, index: number, teamId: number): RosterEntry {
  return {
    playerId: player.playerId,
    publicEntapId: player.publicEntapId ?? null,
    displayName: player.displayName,
    participantType: "HUMAN",
    seatId: index + 1,
    teamId,
    colorId: COLORS[index],
    rankValue: player.rankValue,
    readyState: "NOT_READY",
    connectionState: "CONNECTED",
    joinedAt: player.joinedAt
  };
}
