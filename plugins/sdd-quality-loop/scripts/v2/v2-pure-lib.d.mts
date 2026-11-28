export interface GuardrailsConfig {
  schema: string;
  sourcePath: string | null;
  spec_guard: {
    mode: string;
    protected_globs: string[];
    allow_amendment_section: boolean;
  };
  review: {
    pre_impl_check: string;
    independent_gate: boolean;
  };
  risk_defaults: {
    default_tier: string;
    high_risk_paths: string[];
  };
  limits: {
    max_auto_fix_rounds: number;
  };
}

export interface ProtectedSpecMatch {
  relPath: string;
  feature: string | null;
  fileName: string;
}

export interface SpecAmendmentsSplit {
  beforeAmendments: string;
  amendmentsBody: string;
  afterAmendments: string;
  hasHeading: boolean;
}

export interface AmendmentEntryWithLine {
  text: string;
  sourceFile: string | null;
  sourceLine: number;
  sourceRef: string | null;
}

export interface SpecIdentifierEntry {
  line: string;
  hash: string;
}

export declare const DEFAULT_CONFIG: Readonly<GuardrailsConfig>;
export declare const VALID_MODES: Set<string>;
export declare const VALID_PRE_IMPL: Set<string>;
export declare const VALID_RISK_TIERS: Set<string>;

export declare function normalizeNewlines(text: unknown): string;
export declare function sha256Text(text: unknown): string;
export declare function escapeRegExp(text: unknown): string;
export declare function toPosixPath(filePath: unknown): string;
export declare function normalizeRelPath(filePath: unknown): string;
export declare function sanitizeRelPath(relPath: unknown): string | null;
export declare function assertValidFeatureName(feature: unknown): void;
export declare function stripYamlComment(line: string): string;
export declare function parseSimpleYaml(text: string): Record<string, any>;
export declare function normalizeGuardrailsConfig(parsed: any, sourcePath?: string | null): GuardrailsConfig;
export declare function globToRegExp(glob: string): RegExp;
export declare function matchProtectedSpecRelPath(relPath: string, config?: GuardrailsConfig | null): ProtectedSpecMatch | null;
export declare function countPrimaryApprovals(text: string): number;
export declare function countDomainModelApprovals(text: string): number;
export declare function splitSpecAmendments(text: string): SpecAmendmentsSplit;
export declare function extractAmendmentEntriesWithLines(text: string, sourceFile?: string | null): AmendmentEntryWithLine[];
export declare function extractAmendmentEntries(text: string): string[];
export declare function isApprovedValue(value: unknown): boolean;
export declare function canonicalSpecContractText(text: string, fileName?: string): string;
export declare function isSafeSpecEditOnly(
  oldContent: string,
  newContent: string,
  fileName?: string,
  allowAmendmentSection?: boolean,
): boolean;
export declare function extractSpecIdentifiers(text: string): Record<string, SpecIdentifierEntry>;
