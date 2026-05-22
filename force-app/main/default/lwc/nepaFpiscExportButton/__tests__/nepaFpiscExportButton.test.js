import { createElement } from 'lwc';
import NepaFpiscExportButton from 'c/nepaFpiscExportButton';
import generateFPISCExport from '@salesforce/apex/NepaCeqExportService.generateFPISCExport';

jest.mock(
    '@salesforce/apex/NepaCeqExportService.generateFPISCExport',
    () => ({ default: jest.fn() }),
    { virtual: true }
);

// ── Helpers ───────────────────────────────────────────────────────────────────

function flushPromises() {
    return new Promise(resolve => setTimeout(resolve, 0));
}

function makeFpiscRows(count = 3) {
    return Array.from({ length: count }, (_, i) => ({
        projectName:      `Test Project ${i}`,
        leadAgency:       'BLM',
        reviewType:       'EIS',
        daysElapsed:      200 + i,
        ofdTargetDays:    180,
        ofdVarianceDays:  20 + i,
        stage:            'Analysis',
        status:           'in progress'
    }));
}

function createElement_withRecord(recordId = 'a000000000000001') {
    const el = createElement('c-nepa-fpisc-export-button', { is: NepaFpiscExportButton });
    el.recordId = recordId;
    document.body.appendChild(el);
    return el;
}

// ── Setup / teardown ─────────────────────────────────────────────────────────

afterEach(() => {
    while (document.body.firstChild) {
        document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
    // Restore URL mocks if set
    if (global.URL.createObjectURL.mockRestore) global.URL.createObjectURL.mockRestore();
    if (global.URL.revokeObjectURL.mockRestore) global.URL.revokeObjectURL.mockRestore();
});

// ── Rendering ─────────────────────────────────────────────────────────────────

describe('rendering', () => {
    test('renders Export This Project and Export All Active buttons', async () => {
        generateFPISCExport.mockResolvedValue([]);
        const el = createElement_withRecord();
        await flushPromises();

        const buttons = el.shadowRoot.querySelectorAll('lightning-button');
        const labels = Array.from(buttons).map(b => b.label);
        expect(labels).toContain('Export This Project');
        expect(labels).toContain('Export All Active');
    });

    test('does not show spinner on initial render', async () => {
        generateFPISCExport.mockResolvedValue([]);
        const el = createElement_withRecord();
        await flushPromises();

        const spinner = el.shadowRoot.querySelector('lightning-spinner');
        expect(spinner).toBeNull();
    });

    test('does not show error message on initial render', async () => {
        generateFPISCExport.mockResolvedValue([]);
        const el = createElement_withRecord();
        await flushPromises();

        const errorEl = el.shadowRoot.querySelector('.slds-text-color_error');
        expect(errorEl).toBeNull();
    });
});

// ── Export This Project ───────────────────────────────────────────────────────

describe('Export This Project', () => {
    test('calls generateFPISCExport with the record ID', async () => {
        const recordId = 'a000000000000TEST';
        const rows = makeFpiscRows(2);
        generateFPISCExport.mockResolvedValue(rows);

        global.URL.createObjectURL = jest.fn(() => 'blob:mock-url');
        global.URL.revokeObjectURL = jest.fn();

        const el = createElement_withRecord(recordId);
        await flushPromises();

        const projectBtn = Array.from(el.shadowRoot.querySelectorAll('lightning-button'))
            .find(b => b.label === 'Export This Project');
        projectBtn.click();

        await flushPromises();

        expect(generateFPISCExport).toHaveBeenCalledWith({ programId: recordId });
    });

    test('shows row count after successful export', async () => {
        const rows = makeFpiscRows(5);
        generateFPISCExport.mockResolvedValue(rows);
        global.URL.createObjectURL = jest.fn(() => 'blob:mock-url');
        global.URL.revokeObjectURL = jest.fn();

        const el = createElement_withRecord();
        await flushPromises();

        const projectBtn = Array.from(el.shadowRoot.querySelectorAll('lightning-button'))
            .find(b => b.label === 'Export This Project');
        projectBtn.click();
        await flushPromises();

        const successMsg = el.shadowRoot.querySelector('.slds-text-color_success');
        expect(successMsg).not.toBeNull();
        expect(successMsg.textContent).toContain('5');
    });
});

// ── Export All Active ─────────────────────────────────────────────────────────

describe('Export All Active', () => {
    test('calls generateFPISCExport with null programId', async () => {
        generateFPISCExport.mockResolvedValue(makeFpiscRows(10));
        global.URL.createObjectURL = jest.fn(() => 'blob:mock-url');
        global.URL.revokeObjectURL = jest.fn();

        const el = createElement_withRecord();
        await flushPromises();

        const allBtn = Array.from(el.shadowRoot.querySelectorAll('lightning-button'))
            .find(b => b.label === 'Export All Active');
        allBtn.click();
        await flushPromises();

        expect(generateFPISCExport).toHaveBeenCalledWith({ programId: null });
    });
});

// ── Loading state ─────────────────────────────────────────────────────────────

describe('loading state', () => {
    test('shows spinner while export is in progress', async () => {
        let resolveExport;
        generateFPISCExport.mockReturnValue(new Promise(res => { resolveExport = res; }));

        const el = createElement_withRecord();
        await flushPromises();

        const projectBtn = Array.from(el.shadowRoot.querySelectorAll('lightning-button'))
            .find(b => b.label === 'Export This Project');
        projectBtn.click();

        // Don't flush — check mid-flight state
        await Promise.resolve();

        const spinner = el.shadowRoot.querySelector('lightning-spinner');
        expect(spinner).not.toBeNull();

        // Clean up
        resolveExport([]);
        await flushPromises();
    });

    test('buttons are disabled while loading', async () => {
        let resolveExport;
        generateFPISCExport.mockReturnValue(new Promise(res => { resolveExport = res; }));

        const el = createElement_withRecord();
        await flushPromises();

        const projectBtn = Array.from(el.shadowRoot.querySelectorAll('lightning-button'))
            .find(b => b.label === 'Export This Project');
        projectBtn.click();
        await Promise.resolve();

        const buttons = el.shadowRoot.querySelectorAll('lightning-button');
        buttons.forEach(btn => {
            expect(btn.disabled).toBe(true);
        });

        resolveExport([]);
        await flushPromises();
    });
});

// ── Error handling ────────────────────────────────────────────────────────────

describe('error handling', () => {
    test('shows error message when Apex call fails', async () => {
        generateFPISCExport.mockRejectedValue({
            body: { message: 'SOQL query failed: missing field' }
        });

        const el = createElement_withRecord();
        await flushPromises();

        const projectBtn = Array.from(el.shadowRoot.querySelectorAll('lightning-button'))
            .find(b => b.label === 'Export This Project');
        projectBtn.click();
        await flushPromises();

        const errorEl = el.shadowRoot.querySelector('.slds-text-color_error');
        expect(errorEl).not.toBeNull();
        expect(errorEl.textContent).toContain('SOQL query failed');
    });

    test('shows fallback message when error has no body', async () => {
        generateFPISCExport.mockRejectedValue(new Error('Network error'));

        const el = createElement_withRecord();
        await flushPromises();

        const projectBtn = Array.from(el.shadowRoot.querySelectorAll('lightning-button'))
            .find(b => b.label === 'Export This Project');
        projectBtn.click();
        await flushPromises();

        const errorEl = el.shadowRoot.querySelector('.slds-text-color_error');
        expect(errorEl).not.toBeNull();
        expect(errorEl.textContent.length).toBeGreaterThan(0);
    });

    test('hides spinner after error', async () => {
        generateFPISCExport.mockRejectedValue({ body: { message: 'Apex error' } });

        const el = createElement_withRecord();
        await flushPromises();

        const projectBtn = Array.from(el.shadowRoot.querySelectorAll('lightning-button'))
            .find(b => b.label === 'Export This Project');
        projectBtn.click();
        await flushPromises();

        const spinner = el.shadowRoot.querySelector('lightning-spinner');
        expect(spinner).toBeNull();
    });
});

// ── File download ─────────────────────────────────────────────────────────────

describe('file download', () => {
    test('calls URL.createObjectURL and revokeObjectURL on successful export', async () => {
        const createMock  = jest.fn(() => 'blob:mock-url');
        const revokeMock  = jest.fn();
        global.URL.createObjectURL = createMock;
        global.URL.revokeObjectURL = revokeMock;

        generateFPISCExport.mockResolvedValue(makeFpiscRows(3));

        const el = createElement_withRecord();
        await flushPromises();

        const projectBtn = Array.from(el.shadowRoot.querySelectorAll('lightning-button'))
            .find(b => b.label === 'Export This Project');
        projectBtn.click();
        await flushPromises();

        expect(createMock).toHaveBeenCalledTimes(1);
        expect(revokeMock).toHaveBeenCalledTimes(1);
    });
});
