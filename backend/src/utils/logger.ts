/**
 * Structured JSON logger for the SolFight backend.
 *
 * Outputs one JSON object per line to stdout/stderr, compatible with any
 * log aggregation service (Render, Datadog, CloudWatch, etc.).
 */

type LogLevel = "info" | "warn" | "error" | "debug";

interface LogEntry {
  level: LogLevel;
  msg: string;
  ts: string;
  [key: string]: unknown;
}

function emit(level: LogLevel, msg: string, ctx?: Record<string, unknown>): void {
  const entry: LogEntry = {
    level,
    msg,
    ts: new Date().toISOString(),
    ...ctx,
  };

  const line = JSON.stringify(entry);

  if (level === "error") {
    process.stderr.write(line + "\n");
  } else {
    process.stdout.write(line + "\n");
  }
}

export const log = {
  info:  (msg: string, ctx?: Record<string, unknown>) => emit("info",  msg, ctx),
  warn:  (msg: string, ctx?: Record<string, unknown>) => emit("warn",  msg, ctx),
  error: (msg: string, ctx?: Record<string, unknown>) => emit("error", msg, ctx),
  debug: (msg: string, ctx?: Record<string, unknown>) => emit("debug", msg, ctx),
};
