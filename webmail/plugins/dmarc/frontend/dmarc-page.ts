import { LitElement, html, css, nothing } from 'lit';
import { customElement, state } from 'lit/decorators.js';
import { consume } from '@lit/context';
import { i18nContext, I18nStore } from '../../../frontend/src/store/i18n-store';
import { settingsContext, SettingsStore } from '../../../frontend/src/store/settings-store';
import '../../../frontend/src/components/app-header';
import { dmarcService } from './dmarc-service';
import type { DmarcSource, DmarcSummary } from './dmarc-service';

const MOBILE_MAX_WIDTH = 768;

@customElement('alps-dmarc-page')
export class DmarcPage extends LitElement {
  @consume({ context: i18nContext, subscribe: true })
  i18nStore!: I18nStore;

  @consume({ context: settingsContext })
  settingsStore!: SettingsStore;

  @state() private summary: DmarcSummary | null = null;
  @state() private loading = true;
  @state() private failed = false;
  @state() private isMobile = window.innerWidth <= MOBILE_MAX_WIDTH;

  static styles = css`
    :host {
      display: flex;
      flex-direction: column;
      height: 100vh;
      height: 100dvh;
      width: 100%;
      overflow: hidden;
      background: var(--bg-primary);
      color: var(--text-primary);
      font-family: var(--font-base);
    }
    main {
      flex: 1;
      min-width: 0;
      overflow-y: auto;
      padding: 24px 16px 48px;
      box-sizing: border-box;
    }
    .content {
      max-width: 960px;
      margin: 0 auto;
      display: flex;
      flex-direction: column;
      gap: 24px;
    }
    h1, h2, p { margin: 0; }
    h1 {
      font-family: var(--font-heading);
      font-size: 24px;
      overflow-wrap: anywhere;
    }
    h1 { width: fit-content; max-width: 100%; }
    h1:focus { outline: none; }
    h1:focus-visible {
      outline: 2px solid var(--accent-color);
      outline-offset: 4px;
      border-radius: var(--radius-sm);
    }
    h2 { font-size: 16px; }
    .scope, .caption, .note { color: var(--text-secondary); font-size: 14px; }
    .stats {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
      gap: 12px;
    }
    .stat {
      display: flex;
      flex-direction: column;
      gap: 4px;
      padding: 16px;
      border: 1px solid var(--border-color);
      border-radius: var(--radius-lg);
      background: var(--bg-secondary);
      min-width: 0;
    }
    .value { font-size: 28px; font-weight: 600; overflow-wrap: anywhere; }
    .verdict {
      padding: 12px 16px;
      border: 1px solid var(--border-color);
      border-left-width: 4px;
      border-radius: var(--radius-lg);
      background: var(--bg-secondary);
      overflow-wrap: anywhere;
    }
    .verdict.ready { border-left-color: var(--success); }
    .verdict.failing { border-left-color: var(--error); }
    table { width: 100%; border-collapse: collapse; table-layout: fixed; }
    th, td {
      padding: 10px 8px;
      text-align: left;
      vertical-align: top;
      border-bottom: 1px solid var(--border-color);
      overflow-wrap: anywhere;
    }
    th { font-size: 13px; font-weight: 600; color: var(--text-secondary); }
    td.fail > span { color: color-mix(in srgb, var(--error) 70%, var(--text-primary)); font-weight: 600; }
    .state {
      display: flex;
      flex-direction: column;
      align-items: flex-start;
      gap: 12px;
      padding: 24px 16px;
      border: 1px dashed var(--border-color);
      border-radius: var(--radius-lg);
    }
    button {
      min-height: 44px;
      min-width: 44px;
      padding: var(--btn-padding);
      border: 1px solid var(--border-color);
      border-radius: var(--btn-radius);
      background: var(--bg-secondary);
      color: var(--text-primary);
      font: inherit;
      cursor: pointer;
    }
    button:hover { background: var(--hover-color); }
    button:focus-visible {
      outline: 2px solid var(--accent-color);
      outline-offset: 2px;
    }
    @media (max-width: 900px) {
      thead {
        position: absolute;
        width: 1px;
        height: 1px;
        overflow: hidden;
        clip-path: inset(50%);
      }
      table, tbody, tr, td { display: block; }
      tr { padding: 8px 0; border-bottom: 1px solid var(--border-color); }
      td { display: flex; gap: 12px; justify-content: space-between; border: 0; padding: 4px 8px; }
      td::before {
        content: attr(data-label);
        flex: 0 0 40%;
        color: var(--text-secondary);
        font-size: 13px;
      }
      td > span { flex: 1; min-width: 0; text-align: right; }
    }
  `;

  connectedCallback() {
    super.connectedCallback();
    window.addEventListener('resize', this.onResize);
    this.load();
    this.updateComplete.then(() => this.focusHeading());
  }

  disconnectedCallback() {
    super.disconnectedCallback();
    window.removeEventListener('resize', this.onResize);
  }

  private onResize = () => {
    this.isMobile = window.innerWidth <= MOBILE_MAX_WIDTH;
  };

  private focusHeading() {
    this.shadowRoot?.querySelector<HTMLElement>('h1')?.focus();
  }

  private async load() {
    this.loading = true;
    this.failed = false;
    try {
      this.summary = await dmarcService.fetchReports();
    } catch {
      this.failed = true;
    } finally {
      this.loading = false;
    }
  }

  private t(key: string, params?: Record<string, unknown>): string {
    return this.i18nStore?.t(key, params) ?? key;
  }

  private num(n: number): string {
    return n.toLocaleString();
  }

  private renderScope(s: DmarcSummary) {
    const providers = new Set(s.sources.flatMap(src => src.orgs)).size;
    return this.t('dmarc.scope', {
      days: s.days,
      reports: this.t('dmarc.reportCount', { count: s.reports.length }),
      providers: this.t('dmarc.providerCount', { count: providers })
    });
  }

  private renderStats(s: DmarcSummary) {
    // Floor, so a few failures never read as 100%.
    const percent = Math.floor((s.totals.dmarc / s.totals.messages) * 100);
    return html`
      <div class="stats">
        <div class="stat">
          <span class="value">${this.num(s.totals.messages)}</span>
          <span class="caption">${this.t('dmarc.messages')}</span>
        </div>
        <div class="stat">
          <span class="value">${this.num(s.totals.dmarc)}</span>
          <span class="caption">${this.t('dmarc.passed')}, ${this.t('dmarc.passedShare', { percent })}</span>
        </div>
        <div class="stat">
          <span class="value">${this.num(s.totals.failed)}</span>
          <span class="caption">${this.t('dmarc.failed')}</span>
        </div>
      </div>
    `;
  }

  private renderVerdict(s: DmarcSummary) {
    const { state, failedMessages, failedSources } = s.verdict;
    const text = state === 'ready'
      ? this.t('dmarc.verdictReady')
      : this.t('dmarc.verdictFailing', {
          messages: this.t('dmarc.messageCount', { count: failedMessages }),
          sources: this.t('dmarc.sourceCount', { count: failedSources })
        });
    return html`<p class="verdict ${state}" role="status">${text}</p>`;
  }

  private ofTotal(passed: number, total: number) {
    return this.t('dmarc.ofTotal', { passed: this.num(passed), total: this.num(total) });
  }

  private renderSource(src: DmarcSource) {
    const dispositions = Object.entries(src.dispositions)
      .map(([name, count]) => `${name} ${this.num(count)}`)
      .join(', ');
    return html`
      <tr>
        <td data-label=${this.t('dmarc.sourceIp')}><span>${src.ip}</span></td>
        <td data-label=${this.t('dmarc.reportedBy')}><span>${src.orgs.join(', ')}</span></td>
        <td data-label=${this.t('dmarc.colMessages')}><span>${this.num(src.messages)}</span></td>
        <td data-label=${this.t('dmarc.colDkim')}><span>${this.ofTotal(src.dkim, src.messages)}</span></td>
        <td data-label=${this.t('dmarc.colSpf')}><span>${this.ofTotal(src.spf, src.messages)}</span></td>
        <td data-label=${this.t('dmarc.colDmarc')} class=${src.dmarc < src.messages ? 'fail' : ''}>
          <span>${this.ofTotal(src.dmarc, src.messages)}</span>
        </td>
        <td data-label=${this.t('dmarc.colDisposition')}><span>${dispositions}</span></td>
      </tr>
    `;
  }

  private renderSources(s: DmarcSummary) {
    return html`
      <section class="content-section">
        <h2>${this.t('dmarc.sources')}</h2>
        <table>
          <thead>
            <tr>
              <th scope="col">${this.t('dmarc.sourceIp')}</th>
              <th scope="col">${this.t('dmarc.reportedBy')}</th>
              <th scope="col">${this.t('dmarc.colMessages')}</th>
              <th scope="col">${this.t('dmarc.colDkim')}</th>
              <th scope="col">${this.t('dmarc.colSpf')}</th>
              <th scope="col">${this.t('dmarc.colDmarc')}</th>
              <th scope="col">${this.t('dmarc.colDisposition')}</th>
            </tr>
          </thead>
          <tbody>${s.sources.map(src => this.renderSource(src))}</tbody>
        </table>
      </section>
    `;
  }

  private renderBody() {
    if (this.loading) return html`<p class="note" role="status">${this.t('dmarc.loading')}</p>`;
    const s = this.summary;
    if (this.failed || !s) {
      return html`
        <div class="state" role="alert">
          <p>${this.t('dmarc.error')}</p>
          <button @click=${() => this.load()}>${this.t('dmarc.retry')}</button>
        </div>
      `;
    }
    const skipped = s.skipped > 0
      ? html`<p class="note">${this.t('dmarc.skipped', { count: s.skipped })}</p>`
      : nothing;
    if (s.verdict.state === 'empty') {
      return html`
        <div class="state">
          <h2>${this.t('dmarc.emptyTitle')}</h2>
          <p>${this.t('dmarc.emptyBody')}</p>
        </div>
        ${skipped}
      `;
    }
    return html`
      <p class="scope">${this.renderScope(s)}</p>
      ${this.renderStats(s)}
      ${this.renderVerdict(s)}
      ${this.renderSources(s)}
      ${skipped}
    `;
  }

  render() {
    return html`
      <app-header
        currentTab="dmarc"
        .username=${this.settingsStore?.getState().loginUsername || ''}
        .isMobile=${this.isMobile}
      ></app-header>
      <main>
        <div class="content">
          <h1 tabindex="-1">${this.t('dmarc.title')}</h1>
          ${this.renderBody()}
        </div>
      </main>
    `;
  }
}
