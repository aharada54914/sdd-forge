/** Raw JSON fields stay unknown until the consuming tool validates their meaning. */
export type JsonObject = Record<string, unknown>;

export function isJsonObject(value: unknown): value is JsonObject {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

/** Format JSON fields without invoking an object's user-supplied toString property. */
export function jsonValueText(value: unknown): string {
  return value !== null && typeof value === "object" ? JSON.stringify(value) : String(value ?? "");
}
