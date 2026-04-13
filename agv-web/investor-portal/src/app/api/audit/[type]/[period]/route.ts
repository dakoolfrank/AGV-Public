import { NextRequest, NextResponse } from "next/server";
import { adminDb } from "@/lib/firebase-admin";
import { requireDataroomAccess } from "@/lib/auth-middleware";
import type { AuditReport } from "@/lib/audit-types";

/**
 * GET /api/audit/:type/:period — Fetch a single audit report.
 * Gated by NDA dataroom access (investor-level).
 * Only returns reports where `redacted: true`.
 */
export async function GET(
  req: NextRequest,
  { params }: { params: Promise<{ type: string; period: string }> },
) {
  const access = await requireDataroomAccess(req);
  if (!access) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { type, period } = await params;
  const docId = `${type}_${period}`;
  const doc = await adminDb.collection("audit_reports").doc(docId).get();

  if (!doc.exists) {
    return NextResponse.json({ error: "Report not found" }, { status: 404 });
  }

  const d = doc.data()!;

  // Investors may only see redacted versions
  if (!d.redacted) {
    return NextResponse.json({ error: "Report not available" }, { status: 403 });
  }

  const report: AuditReport = {
    report_id: d.report_id ?? doc.id,
    report_type: d.report_type,
    period: d.period,
    snapshot_hash: d.snapshot_hash ?? "",
    content_markdown: d.content_markdown ?? "",
    llm_analysis: d.llm_analysis ?? {},
    generated_at: d.generated_at ?? "",
    published_at: d.published_at ?? null,
    verdict: d.verdict ?? "pass",
    redacted: d.redacted ?? true,
  };

  return NextResponse.json(report);
}
