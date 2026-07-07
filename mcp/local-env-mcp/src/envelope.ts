/**
 * Common response envelope for every local-env-mcp tool and resource.
 *
 * Canonical contract: contracts/local-env-mcp-tools.v1.schema.json
 *
 * Structure and ErrorCode enum are verbatim-compatible with sdd-forge-mcp's
 * envelope so MCP clients can share error-handling. local-env-mcp emits mainly
 * `invalid-input` and `cannot-determine`; the other codes are retained for
 * contract compatibility. Error `details` must never contain file contents,
 * environment variable values, or other secret data.
 */

/** Error codes accepted by the v1 response contract. */
export type ErrorCode =
  | "cannot-parse"
  | "cannot-determine"
  | "not-found"
  | "path-denied"
  | "not-sdd-root"
  | "too-large"
  | "invalid-input";

/** Machine-readable context for a failure. Never carries secret values. */
export interface ErrorDetails {
  file?: string;
  line?: number;
  rule?: string;
  [key: string]: unknown;
}

export interface ErrorInfo {
  code: ErrorCode;
  message: string;
  details?: ErrorDetails;
}

export interface OkEnvelope<T> {
  ok: true;
  data: T;
}

export interface ErrorEnvelope {
  ok: false;
  error: ErrorInfo;
}

/** Result type returned by every guarded read / tool implementation. */
export type Result<T> = OkEnvelope<T> | ErrorEnvelope;

/** Builds a successful envelope. */
export function ok<T>(data: T): OkEnvelope<T> {
  return { ok: true, data };
}

/** Builds a failure envelope. `details` is optional and must stay secret-free. */
export function err(
  code: ErrorCode,
  message: string,
  details?: ErrorDetails,
): ErrorEnvelope {
  const error: ErrorInfo = details === undefined
    ? { code, message }
    : { code, message, details };
  return { ok: false, error };
}

/** Narrows a Result to its ok branch. */
export function isOk<T>(result: Result<T>): result is OkEnvelope<T> {
  return result.ok === true;
}

/** Narrows a Result to its error branch. */
export function isErr<T>(result: Result<T>): result is ErrorEnvelope {
  return result.ok === false;
}
