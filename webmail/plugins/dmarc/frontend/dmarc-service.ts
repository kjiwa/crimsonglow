import { fetchWithTimeout } from '../../../frontend/src/utils/fetch-utils';

export interface DmarcSource {
  ip: string;
  orgs: string[];
  messages: number;
  dkim: number;
  spf: number;
  dmarc: number;
  dispositions: Record<string, number>;
}

export interface DmarcSummary {
  days: number;
  reports: { org: string; id: string }[];
  sources: DmarcSource[];
  totals: { messages: number; dkim: number; spf: number; dmarc: number; failed: number };
  skipped: number;
  verdict: { state: 'empty' | 'ready' | 'failing'; failedMessages: number; failedSources: number };
}

class DmarcService {
  async fetchReports(): Promise<DmarcSummary> {
    const res = await fetchWithTimeout('/api/dmarc/reports');
    if (!res.ok) {
      throw new Error(`Failed to fetch reports: ${res.statusText}`);
    }
    return res.json();
  }
}

export const dmarcService = new DmarcService();
