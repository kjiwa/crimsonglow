export default {
  navigation: {
    dmarc: 'DMARC'
  },
  dmarc: {
    title: 'DMARC reports',
    scope: 'Last {days} days: {reports} from {providers}',
    reportCount: { one: '{count} report', other: '{count} reports' },
    providerCount: { one: '{count} provider', other: '{count} providers' },
    messageCount: { one: '{count} message', other: '{count} messages' },
    sourceCount: { one: '{count} source', other: '{count} sources' },
    messages: 'Messages reported',
    passed: 'Passed DMARC',
    passedShare: '{percent}% of messages',
    failed: 'Failed DMARC',
    verdictReady: 'Every message passed. Policy can move to quarantine.',
    verdictFailing: '{messages} from {sources} failed',
    sources: 'Sources',
    sourceIp: 'Source IP',
    reportedBy: 'Reported by',
    colMessages: 'Messages',
    colDkim: 'DKIM',
    colSpf: 'SPF',
    colDmarc: 'DMARC',
    colDisposition: 'Disposition',
    ofTotal: '{passed} of {total}',
    skipped: {
      one: '{count} attachment could not be read and was skipped.',
      other: '{count} attachments could not be read and were skipped.'
    },
    emptyTitle: 'No reports yet',
    emptyBody: 'Providers send aggregate reports about once a day. A filter in Settings files them into a folder named DMARC, and they appear here once that folder holds some.',
    loading: 'Loading reports',
    error: 'The reports could not be loaded.',
    retry: 'Try again'
  }
};
