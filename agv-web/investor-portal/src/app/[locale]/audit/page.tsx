'use client';

import React, { useEffect, useState } from 'react';
import Link from 'next/link';
import { motion } from 'framer-motion';
import Layout from '@/components/Layout';
import SectionHeader from '@/components/SectionHeader';
import Card from '@/components/Card';
import { useTranslations } from '@/hooks/useTranslations';
import { FiShield, FiAlertTriangle, FiCheckCircle, FiFilter } from 'react-icons/fi';
import type {
  AuditReportListItem,
  AuditReportType,
  AuditVerdict,
} from '@/lib/audit-types';
import {
  REPORT_TYPE_LABELS,
  VERDICT_COLORS,
  VERDICT_LABELS,
} from '@/lib/audit-types';

const VERDICT_ICONS: Record<AuditVerdict, React.ReactNode> = {
  pass: <FiCheckCircle className="w-4 h-4" />,
  warning: <FiAlertTriangle className="w-4 h-4" />,
  alarm: <FiAlertTriangle className="w-4 h-4" />,
};

const ALL_TYPES: { value: '' | AuditReportType; label: string }[] = [
  { value: '', label: 'All Types' },
  { value: 'monthly_transparency', label: 'Monthly Transparency' },
  { value: 'token_issuance_audit', label: 'Token Issuance Audit' },
  { value: 'nft_distribution', label: 'NFT Distribution' },
  { value: 'lp_liquidity', label: 'LP Liquidity' },
  { value: 'settlement_bridge', label: 'Settlement Bridge' },
];

export default function AuditListPage() {
  const { locale } = useTranslations();
  const [reports, setReports] = useState<AuditReportListItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [filter, setFilter] = useState<'' | AuditReportType>('');

  useEffect(() => {
    const url = filter
      ? `/api/audit/reports?type=${filter}`
      : '/api/audit/reports';

    fetch(url, { credentials: 'include' })
      .then(async (res) => {
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json() as Promise<AuditReportListItem[]>;
      })
      .then(setReports)
      .catch((e) => setError(e.message))
      .finally(() => setLoading(false));
  }, [filter]);

  return (
    <Layout>
      <section className="py-20 px-4 sm:px-6 lg:px-8">
        <div className="max-w-7xl mx-auto">
          <SectionHeader
            subtitle="On-Chain Verification"
            title="Audit Reports"
            description="Independent automated audits of AGV protocol operations. All reports are redacted for investor access."
          />

          {/* Filter */}
          <motion.div
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.2 }}
            className="flex items-center justify-center gap-2 mt-10 mb-8"
          >
            <FiFilter className="text-muted-foreground w-4 h-4" />
            <select
              value={filter}
              onChange={(e) => {
                setFilter(e.target.value as '' | AuditReportType);
                setLoading(true);
              }}
              className="bg-card border border-border rounded-lg px-3 py-2 text-sm text-foreground focus:outline-none focus:ring-2 focus:ring-primary/30"
            >
              {ALL_TYPES.map((t) => (
                <option key={t.value} value={t.value}>
                  {t.label}
                </option>
              ))}
            </select>
          </motion.div>

          {/* Content */}
          {loading ? (
            <div className="flex justify-center py-20">
              <div className="animate-spin rounded-full h-10 w-10 border-b-2 border-primary" />
            </div>
          ) : error ? (
            <div className="text-center py-20 text-red-600">
              <FiAlertTriangle className="w-8 h-8 mx-auto mb-2" />
              <p>{error}</p>
            </div>
          ) : reports.length === 0 ? (
            <div className="text-center py-20 text-muted-foreground">
              <FiShield className="w-10 h-10 mx-auto mb-3 opacity-40" />
              <p>No audit reports available yet.</p>
            </div>
          ) : (
            <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
              {reports.map((report, idx) => (
                <motion.div
                  key={report.report_id}
                  initial={{ opacity: 0, y: 20 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: 0.1 * idx, duration: 0.4 }}
                >
                  <Link href={`/${locale}/audit/${report.report_type}/${report.period}`}>
                    <Card className="p-6 h-full flex flex-col justify-between cursor-pointer">
                      <div>
                        <div className="flex items-center justify-between mb-3">
                          <span className="text-xs font-medium uppercase tracking-wider text-muted-foreground">
                            {REPORT_TYPE_LABELS[report.report_type]}
                          </span>
                          <span
                            className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-semibold ${VERDICT_COLORS[report.verdict]}`}
                          >
                            {VERDICT_ICONS[report.verdict]}
                            {VERDICT_LABELS[report.verdict]}
                          </span>
                        </div>
                        <h3 className="text-lg font-semibold text-foreground mb-1">
                          {report.period}
                        </h3>
                      </div>
                      <p className="text-xs text-muted-foreground mt-3">
                        Generated {new Date(report.generated_at).toLocaleDateString()}
                      </p>
                    </Card>
                  </Link>
                </motion.div>
              ))}
            </div>
          )}
        </div>
      </section>
    </Layout>
  );
}
