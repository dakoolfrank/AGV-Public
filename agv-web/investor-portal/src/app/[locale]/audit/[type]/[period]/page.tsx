'use client';

import React, { useEffect, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import { motion } from 'framer-motion';
import Layout from '@/components/Layout';
import Button from '@/components/Button';
import { useTranslations } from '@/hooks/useTranslations';
import {
  FiArrowLeft,
  FiShield,
  FiCheckCircle,
  FiAlertTriangle,
  FiClock,
  FiHash,
} from 'react-icons/fi';
import type { AuditReport } from '@/lib/audit-types';
import {
  REPORT_TYPE_LABELS,
  VERDICT_COLORS,
  VERDICT_LABELS,
} from '@/lib/audit-types';

export default function AuditDetailPage() {
  const params = useParams();
  const router = useRouter();
  const { locale } = useTranslations();

  const type = params.type as string;
  const period = params.period as string;

  const [report, setReport] = useState<AuditReport | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!type || !period) return;

    fetch(`/api/audit/${type}/${period}`, { credentials: 'include' })
      .then(async (res) => {
        if (res.status === 404) throw new Error('Report not found');
        if (res.status === 403) throw new Error('Access denied — this report is not available for investor viewing');
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json() as Promise<AuditReport>;
      })
      .then(setReport)
      .catch((e) => setError(e.message))
      .finally(() => setLoading(false));
  }, [type, period]);

  if (loading) {
    return (
      <Layout>
        <div className="flex justify-center items-center min-h-[60vh]">
          <div className="animate-spin rounded-full h-10 w-10 border-b-2 border-primary" />
        </div>
      </Layout>
    );
  }

  if (error || !report) {
    return (
      <Layout>
        <section className="py-20 px-4 sm:px-6 lg:px-8">
          <div className="max-w-3xl mx-auto text-center">
            <FiAlertTriangle className="w-10 h-10 text-red-500 mx-auto mb-4" />
            <h2 className="text-2xl font-bold text-foreground mb-2">
              {error ?? 'Report not found'}
            </h2>
            <Button
              onClick={() => router.push(`/${locale}/audit`)}
              variant="outline"
              size="sm"
              className="mt-4"
            >
              <FiArrowLeft className="mr-1" /> Back to Reports
            </Button>
          </div>
        </section>
      </Layout>
    );
  }

  const reportTypeLabel =
    REPORT_TYPE_LABELS[report.report_type as keyof typeof REPORT_TYPE_LABELS] ??
    report.report_type;

  const verdictColor = VERDICT_COLORS[report.verdict] ?? '';
  const verdictLabel = VERDICT_LABELS[report.verdict] ?? report.verdict;

  // Extract top-level llm_analysis keys for summary display
  const analysisEntries = Object.entries(report.llm_analysis ?? {}).filter(
    ([, v]) => typeof v === 'string' || typeof v === 'number',
  );

  return (
    <Layout>
      <section className="py-20 px-4 sm:px-6 lg:px-8">
        <div className="max-w-4xl mx-auto">
          {/* Back link */}
          <motion.div
            initial={{ opacity: 0, x: -10 }}
            animate={{ opacity: 1, x: 0 }}
            className="mb-8"
          >
            <button
              onClick={() => router.push(`/${locale}/audit`)}
              className="inline-flex items-center text-sm text-muted-foreground hover:text-foreground transition-colors"
            >
              <FiArrowLeft className="mr-1 w-4 h-4" /> All Audit Reports
            </button>
          </motion.div>

          {/* Header */}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.5 }}
            className="mb-10"
          >
            <div className="flex flex-wrap items-center gap-3 mb-2">
              <span className="text-xs font-medium uppercase tracking-wider text-muted-foreground">
                {reportTypeLabel}
              </span>
              <span
                className={`inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-semibold ${verdictColor}`}
              >
                {report.verdict === 'pass' ? (
                  <FiCheckCircle className="w-3.5 h-3.5" />
                ) : (
                  <FiAlertTriangle className="w-3.5 h-3.5" />
                )}
                {verdictLabel}
              </span>
            </div>
            <h1 className="text-3xl sm:text-4xl font-bold text-foreground">
              {report.period}
            </h1>
          </motion.div>

          {/* Meta cards */}
          <motion.div
            initial={{ opacity: 0, y: 15 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.15, duration: 0.4 }}
            className="grid sm:grid-cols-2 gap-4 mb-10"
          >
            <div className="bg-card border border-border rounded-xl p-4 flex items-start gap-3">
              <FiClock className="w-5 h-5 text-primary mt-0.5 shrink-0" />
              <div>
                <p className="text-xs text-muted-foreground">Generated</p>
                <p className="text-sm font-medium text-foreground">
                  {new Date(report.generated_at).toLocaleString()}
                </p>
              </div>
            </div>
            <div className="bg-card border border-border rounded-xl p-4 flex items-start gap-3">
              <FiHash className="w-5 h-5 text-primary mt-0.5 shrink-0" />
              <div>
                <p className="text-xs text-muted-foreground">Snapshot Hash</p>
                <p className="text-sm font-mono text-foreground break-all">
                  {report.snapshot_hash}
                </p>
              </div>
            </div>
          </motion.div>

          {/* LLM Analysis summary (if any scalar values) */}
          {analysisEntries.length > 0 && (
            <motion.div
              initial={{ opacity: 0, y: 15 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.25, duration: 0.4 }}
              className="bg-card border border-border rounded-xl p-6 mb-10"
            >
              <h2 className="text-sm font-semibold uppercase tracking-wider text-muted-foreground mb-4 flex items-center gap-2">
                <FiShield className="w-4 h-4" /> AI Analysis Summary
              </h2>
              <dl className="grid sm:grid-cols-2 gap-x-6 gap-y-3">
                {analysisEntries.map(([key, value]) => (
                  <div key={key}>
                    <dt className="text-xs text-muted-foreground capitalize">
                      {key.replace(/_/g, ' ')}
                    </dt>
                    <dd className="text-sm font-medium text-foreground">
                      {String(value)}
                    </dd>
                  </div>
                ))}
              </dl>
            </motion.div>
          )}

          {/* Report content (markdown rendered as HTML) */}
          <motion.article
            initial={{ opacity: 0, y: 15 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.35, duration: 0.4 }}
            className="prose prose-slate max-w-none 
              prose-headings:text-foreground prose-p:text-muted-foreground
              prose-strong:text-foreground prose-a:text-primary
              prose-code:bg-muted prose-code:px-1 prose-code:rounded
              prose-pre:bg-muted prose-pre:border prose-pre:border-border"
            dangerouslySetInnerHTML={{ __html: report.content_markdown }}
          />
        </div>
      </section>
    </Layout>
  );
}
