export type AnalyzerSpec = {
  name: string;
  class: string;
  spec: string;
  [key: string]: unknown;
};

export type AnalyzeReportFightOptions = {
  reportCode: string;
  fightId: number;
  playerName?: string | null;
  className?: string;
  specName?: string;
  rankingInfo?: Record<string, unknown>;
};

export type AnalyzeReportFightResult = {
  reportCode: string;
  fightId: number;
  playerName: string | null;
  spec: {
    name: string;
    class: string;
    spec: string;
  };
  result: {
    cast_sequence: unknown[];
    uptimes: Record<string, unknown>;
    [key: string]: unknown;
  };
};

export function analyzeReportFight(options: AnalyzeReportFightOptions): Promise<AnalyzeReportFightResult>;
export function resolveSpec(className: string, specName?: string): AnalyzerSpec;

export const bearDruid: AnalyzerSpec;
export const catDruid: AnalyzerSpec;
export const hunter: AnalyzerSpec;
export function hunterSpellName(spellId: number): string;

export function graphql(query: string, variables?: Record<string, unknown>): Promise<unknown>;
export function fetchAllEvents(...args: unknown[]): Promise<unknown>;
export function fetchFightEvents(...args: unknown[]): Promise<unknown>;
export function listTrashFights(...args: unknown[]): Promise<unknown>;
export function fetchRankings(...args: unknown[]): Promise<unknown>;
export function discover(...args: unknown[]): Promise<unknown>;
export function compareFights(...args: unknown[]): unknown;
export function compareFromFiles(...args: unknown[]): Promise<unknown>;
export function buildBuffTimeline(...args: unknown[]): unknown;
export function sampleBuffsAtTime(...args: unknown[]): unknown;
export function computeUptimes(...args: unknown[]): unknown;
export function computeTransitions(...args: unknown[]): unknown;
export function computeRefreshPatterns(...args: unknown[]): unknown;
export function processFight(...args: unknown[]): Promise<unknown>;
