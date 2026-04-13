/**
 * Audit report types for investor-portal.
 * Mirrors the Python AuditReport dataclass (S3 Digital-Ops)
 * and the asset/src/lib/audit-types.ts definitions.
 */

export type AuditReportType =
  | "monthly_transparency"
  | "token_issuance_audit"
  | "nft_distribution"
  | "lp_liquidity"
  | "settlement_bridge";

export type AuditVerdict = "pass" | "warning" | "alarm";

/** Full report as stored in Firestore `audit_reports` collection */
export interface AuditReport {
  report_id: string;
  report_type: AuditReportType;
  period: string;
  snapshot_hash: string;
  content_markdown: string;
  llm_analysis: Record<string, unknown>;
  // Web-side enrichment (written by FirestoreDelivery)
  generated_at: string;
  published_at: string | null;
  verdict: AuditVerdict;
  redacted: boolean;
}

/** Lighter type for list views */
export interface AuditReportListItem {
  report_id: string;
  report_type: AuditReportType;
  period: string;
  verdict: AuditVerdict;
  generated_at: string;
  redacted: boolean;
}

export const REPORT_TYPE_LABELS: Record<AuditReportType, string> = {
  monthly_transparency: "Monthly Transparency",
  token_issuance_audit: "Token Issuance Audit",
  nft_distribution: "NFT Distribution",
  lp_liquidity: "LP Liquidity",
  settlement_bridge: "Settlement Bridge",
};

export const VERDICT_COLORS: Record<AuditVerdict, string> = {
  pass: "bg-green-100 text-green-800",
  warning: "bg-yellow-100 text-yellow-800",
  alarm: "bg-red-100 text-red-800",
};

export const VERDICT_LABELS: Record<AuditVerdict, string> = {
  pass: "Pass",
  warning: "Warning",
  alarm: "Alarm",
};
