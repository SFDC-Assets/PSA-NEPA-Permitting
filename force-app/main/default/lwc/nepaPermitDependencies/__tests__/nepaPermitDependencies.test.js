import { createElement } from 'lwc';
import NepaPermitDependencies from 'c/nepaPermitDependencies';
import getPermitStatuses from '@salesforce/apex/NepaAgencyPermitService.getPermitStatuses';

jest.mock(
    '@salesforce/apex/NepaAgencyPermitService.getPermitStatuses',
    () => ({ default: jest.fn() }),
    { virtual: true }
);

// ── helpers ───────────────────────────────────────────────────────────────────

function makePermit(overrides = {}) {
    return {
        permitId:          'a00000000000001',
        permitType:        'CWA Section 404 Permit',
        leadAgency:        'USACE',
        regulatoryCitation: '33 USC 1344',
        isCriticalPath:    false,
        agencySystemUrl:   null,
        expectedCompletion: null,
        localStatus:       'Not Started',
        liveStatus:        null,
        liveStage:         null,
        calloutSuccess:    false,
        calloutError:      'No endpoint configured.',
        lastSynced:        null,
        ...overrides
    };
}

function flushPromises() {
    return new Promise(resolve => setTimeout(resolve, 0));
}

// ── STATUS_CLASS mapping ──────────────────────────────────────────────────────

describe('status badge class mapping', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    async function getBadgeClass(status, calloutSuccess = false) {
        const permit = makePermit({
            localStatus:    status,
            liveStatus:     calloutSuccess ? status : null,
            calloutSuccess: calloutSuccess
        });
        getPermitStatuses.mockResolvedValue([permit]);

        const el = createElement('c-nepa-permit-dependencies', { is: NepaPermitDependencies });
        el.recordId = 'a000000000000test';
        document.body.appendChild(el);
        await flushPromises();

        // When calloutSuccess=false the status is shown as a <span> with inline class
        // When calloutSuccess=true it is a <lightning-badge> with class on the element
        const span = el.shadowRoot.querySelector('td[data-label="Live Status"] span');
        const badge = el.shadowRoot.querySelector('td[data-label="Live Status"] lightning-badge');
        return (badge ? badge.className : span ? span.className : '');
    }

    it('Not Started maps to slds-badge_lightest', async () => {
        const cls = await getBadgeClass('Not Started');
        expect(cls).toContain('slds-badge_lightest');
    });

    it('In Progress (capital I) maps to slds-badge_inverse', async () => {
        const cls = await getBadgeClass('In Progress', true);
        expect(cls).toContain('slds-badge_inverse');
    });

    it('Issued maps to slds-badge slds-theme_success', async () => {
        const cls = await getBadgeClass('Issued', true);
        expect(cls).toContain('slds-theme_success');
    });

    it('Denied maps to slds-badge slds-theme_error', async () => {
        const cls = await getBadgeClass('Denied', true);
        expect(cls).toContain('slds-theme_error');
    });

    it('Withdrawn maps to slds-badge slds-theme_error', async () => {
        const cls = await getBadgeClass('Withdrawn', true);
        expect(cls).toContain('slds-theme_error');
    });

    it('Under Review maps to slds-badge slds-theme_warning', async () => {
        const cls = await getBadgeClass('Under Review', true);
        expect(cls).toContain('slds-theme_warning');
    });

    it('unknown status falls back to slds-badge_lightest', async () => {
        const cls = await getBadgeClass('Some Unknown Status', true);
        expect(cls).toContain('slds-badge_lightest');
    });
});

// ── row class enrichment ──────────────────────────────────────────────────────

describe('row class enrichment', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('isCriticalPath=true adds nepa-critical-row class', async () => {
        getPermitStatuses.mockResolvedValue([makePermit({ isCriticalPath: true })]);
        const el = createElement('c-nepa-permit-dependencies', { is: NepaPermitDependencies });
        el.recordId = 'a000000000000test';
        document.body.appendChild(el);
        await flushPromises();

        const row = el.shadowRoot.querySelector('tbody tr');
        expect(row.className).toContain('nepa-critical-row');
    });

    it('isCriticalPath=false does not add nepa-critical-row class', async () => {
        getPermitStatuses.mockResolvedValue([makePermit({ isCriticalPath: false })]);
        const el = createElement('c-nepa-permit-dependencies', { is: NepaPermitDependencies });
        el.recordId = 'a000000000000test';
        document.body.appendChild(el);
        await flushPromises();

        const row = el.shadowRoot.querySelector('tbody tr');
        expect(row.className).not.toContain('nepa-critical-row');
    });
});

// ── display status selection ──────────────────────────────────────────────────

describe('display status selection', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('calloutSuccess=false shows localStatus, not liveStatus', async () => {
        getPermitStatuses.mockResolvedValue([makePermit({
            localStatus:    'Not Started',
            liveStatus:     'in progress',
            calloutSuccess: false,
            calloutError:   'Endpoint unreachable'
        })]);

        const el = createElement('c-nepa-permit-dependencies', { is: NepaPermitDependencies });
        el.recordId = 'a000000000000test';
        document.body.appendChild(el);
        await flushPromises();

        const span = el.shadowRoot.querySelector('td[data-label="Live Status"] span');
        expect(span.textContent).toBe('Not Started');
    });

    it('calloutSuccess=true shows liveStatus via lightning-badge', async () => {
        getPermitStatuses.mockResolvedValue([makePermit({
            localStatus:    'Not Started',
            liveStatus:     'Issued',
            calloutSuccess: true
        })]);

        const el = createElement('c-nepa-permit-dependencies', { is: NepaPermitDependencies });
        el.recordId = 'a000000000000test';
        document.body.appendChild(el);
        await flushPromises();

        const badge = el.shadowRoot.querySelector('td[data-label="Live Status"] lightning-badge');
        expect(badge.label).toBe('Issued');
    });
});

// ── empty and error states ────────────────────────────────────────────────────

describe('empty and error states', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('empty state renders when no permits are returned', async () => {
        getPermitStatuses.mockResolvedValue([]);
        const el = createElement('c-nepa-permit-dependencies', { is: NepaPermitDependencies });
        el.recordId = 'a000000000000test';
        document.body.appendChild(el);
        await flushPromises();

        const heading = el.shadowRoot.querySelector('.slds-text-heading_small');
        expect(heading).not.toBeNull();
        expect(heading.textContent).toContain('No dependent permits recorded');
    });

    it('error state renders when apex rejects', async () => {
        getPermitStatuses.mockRejectedValue({
            body: { message: 'Failed to load permit statuses.' }
        });
        const el = createElement('c-nepa-permit-dependencies', { is: NepaPermitDependencies });
        el.recordId = 'a000000000000test';
        document.body.appendChild(el);
        await flushPromises();

        const alert = el.shadowRoot.querySelector('[role="alert"]');
        expect(alert).not.toBeNull();
    });

    it('cached data warning shown when any permit has calloutSuccess=false', async () => {
        getPermitStatuses.mockResolvedValue([
            makePermit({ calloutSuccess: false, calloutError: 'No endpoint' }),
            makePermit({ permitId: 'a00000000000002', calloutSuccess: true })
        ]);
        const el = createElement('c-nepa-permit-dependencies', { is: NepaPermitDependencies });
        el.recordId = 'a000000000000test';
        document.body.appendChild(el);
        await flushPromises();

        const warning = el.shadowRoot.querySelector('.slds-var-m-top_small.slds-text-body_small');
        expect(warning).not.toBeNull();
    });

    it('no cached data warning when all permits have calloutSuccess=true', async () => {
        getPermitStatuses.mockResolvedValue([
            makePermit({ calloutSuccess: true })
        ]);
        const el = createElement('c-nepa-permit-dependencies', { is: NepaPermitDependencies });
        el.recordId = 'a000000000000test';
        document.body.appendChild(el);
        await flushPromises();

        const footer = el.shadowRoot.querySelector('.slds-var-m-top_small.slds-text-body_small');
        expect(footer).toBeNull();
    });
});
