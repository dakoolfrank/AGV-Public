import { NextRequest, NextResponse } from "next/server";
import { adminDb } from "@/lib/firebase-admin";
import { requireDataroomAccess } from "@/lib/auth-middleware";
import type { AuditReportListItem } from "@/lib/audit-types";

/**
 * GET /api/audit/reports — List published audit reports.
 * Gated by NDA dataroom access (investor-level).
 * Only returns reports where `redacted: true` (L2 sanitized for investors).
 */
export async function GET(req: NextRequest) {
  const access = await requireDataroomAccess(req);
  if (!access) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const typeFilter = req.nextUrl.searchParams.get("type");

  let query = adminDb
    .collection("audit_reports")
    .where("redacted", "==", true)
    .orderBy("generated_at", "desc")
    .limit(50);

  if (typeFilter) {
    query = adminDb
      .collection("audit_reports")
      .where("redacted", "==", true)
      .where("report_type", "==", typeFilter)
      .orderBy("generated_at", "desc")
      .limit(50);
  }

  const snap = await query.get();
  const reports: AuditReportListItem[] = snap.docs.map((doc) => {
    const d = doc.data();
    return {
      report_id: d.report_id ?? doc.id,
      report_type: d.report_type,
      period: d.period,
      verdict: d.verdict ?? "pass",
      generated_at: d.generated_at ?? "",
      redacted: d.redacted ?? true,
    };
  });

  return NextResponse.json({ reports, count: reports.length });
}
