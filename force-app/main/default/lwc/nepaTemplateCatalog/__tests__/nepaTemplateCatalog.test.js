import { createElement } from 'lwc';
import NepaTemplateCatalog from 'c/nepaTemplateCatalog';
import getCatalog from '@salesforce/apex/NepaTemplateCatalogController.getCatalog';
import installTemplate from '@salesforce/apex/NepaTemplateCatalogController.installTemplate';

jest.mock(
    '@salesforce/apex/NepaTemplateCatalogController.getCatalog',
    () => ({ default: jest.fn() }),
    { virtual: true }
);

jest.mock(
    '@salesforce/apex/NepaTemplateCatalogController.installTemplate',
    () => ({ default: jest.fn() }),
    { virtual: true }
);

// ── Helpers ───────────────────────────────────────────────────────────────────

function flushPromises() {
    return new Promise(resolve => setTimeout(resolve, 0));
}

function makeTemplate(overrides = {}) {
    return {
        DeveloperName:     'NEPA_CE_Water_Resources',
        MasterLabel:       'CE Water Resources',
        Template_Name__c:  'Categorical Exclusion — Water Resources',
        Template_Category__c: 'CE Sector',
        Agency__c:         'USACE',
        Review_Type__c:    'CE',
        Sector__c:         'Water Resources',
        APT_Unique_Name__c: 'NEPA_CE_Water_Resources',
        Package_Version__c: '1.0.0',
        Description__c:    'CE milestone checklist for Water Resources projects.',
        ...overrides
    };
}

function createElement_catalog(recordId = 'a000000000000001') {
    const el = createElement('c-nepa-template-catalog', { is: NepaTemplateCatalog });
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
});

// ── Rendering ─────────────────────────────────────────────────────────────────

describe('rendering', () => {
    test('renders Review Type and Sector filter dropdowns', async () => {
        getCatalog.mockResolvedValue([]);
        const el = createElement_catalog();
        await flushPromises();

        const combos = el.shadowRoot.querySelectorAll('lightning-combobox');
        const names = Array.from(combos).map(c => c.name);
        expect(names).toContain('reviewType');
        expect(names).toContain('sector');
    });

    test('renders Clear Filters button', async () => {
        getCatalog.mockResolvedValue([]);
        const el = createElement_catalog();
        await flushPromises();

        const buttons = el.shadowRoot.querySelectorAll('lightning-button');
        const clearBtn = Array.from(buttons).find(b => b.label === 'Clear Filters');
        expect(clearBtn).not.toBeUndefined();
    });

    test('shows empty state illustration when getCatalog returns empty array', async () => {
        getCatalog.mockResolvedValue([]);
        const el = createElement_catalog();
        await flushPromises();

        const emptyMsg = el.shadowRoot.querySelector('.slds-illustration');
        expect(emptyMsg).not.toBeNull();
    });

    test('shows result count when getCatalog returns records', async () => {
        getCatalog.mockResolvedValue([makeTemplate(), makeTemplate({ DeveloperName: 'NEPA_EA_Water' })]);
        const el = createElement_catalog();
        await flushPromises();

        const countEl = el.shadowRoot.querySelector('p');
        expect(countEl).not.toBeNull();
        expect(countEl.textContent).toContain('2');
    });
});

// ── getCatalog call ───────────────────────────────────────────────────────────

describe('getCatalog invocation', () => {
    test('calls getCatalog on connectedCallback with default filters', async () => {
        getCatalog.mockResolvedValue([]);
        createElement_catalog();
        await flushPromises();

        expect(getCatalog).toHaveBeenCalledTimes(1);
        expect(getCatalog).toHaveBeenCalledWith({ reviewType: 'All', sector: '' });
    });

    test('calls getCatalog with updated reviewType when dropdown changes', async () => {
        getCatalog.mockResolvedValue([]);
        const el = createElement_catalog();
        await flushPromises();

        const reviewTypeCombo = Array.from(el.shadowRoot.querySelectorAll('lightning-combobox'))
            .find(c => c.name === 'reviewType');
        reviewTypeCombo.dispatchEvent(new CustomEvent('change', { detail: { value: 'CE' } }));
        await flushPromises();

        expect(getCatalog).toHaveBeenLastCalledWith({ reviewType: 'CE', sector: '' });
    });

    test('calls getCatalog with updated sector when dropdown changes', async () => {
        getCatalog.mockResolvedValue([]);
        const el = createElement_catalog();
        await flushPromises();

        const sectorCombo = Array.from(el.shadowRoot.querySelectorAll('lightning-combobox'))
            .find(c => c.name === 'sector');
        sectorCombo.dispatchEvent(new CustomEvent('change', { detail: { value: 'Water Resources' } }));
        await flushPromises();

        expect(getCatalog).toHaveBeenLastCalledWith({ reviewType: 'All', sector: 'Water Resources' });
    });

    test('clears filters and reloads when Clear Filters is clicked', async () => {
        getCatalog.mockResolvedValue([]);
        const el = createElement_catalog();
        await flushPromises();

        // Set a non-default filter first
        const reviewTypeCombo = Array.from(el.shadowRoot.querySelectorAll('lightning-combobox'))
            .find(c => c.name === 'reviewType');
        reviewTypeCombo.dispatchEvent(new CustomEvent('change', { detail: { value: 'EIS' } }));
        await flushPromises();

        const clearBtn = Array.from(el.shadowRoot.querySelectorAll('lightning-button'))
            .find(b => b.label === 'Clear Filters');
        clearBtn.click();
        await flushPromises();

        expect(getCatalog).toHaveBeenLastCalledWith({ reviewType: 'All', sector: '' });
    });
});

// ── Template cards ────────────────────────────────────────────────────────────

describe('template cards', () => {
    test('renders one card per template returned', async () => {
        const templates = [
            makeTemplate({ DeveloperName: 'T1' }),
            makeTemplate({ DeveloperName: 'T2' }),
            makeTemplate({ DeveloperName: 'T3' })
        ];
        getCatalog.mockResolvedValue(templates);
        const el = createElement_catalog();
        await flushPromises();

        // Each card has a lightning-card inside a grid col
        const cards = el.shadowRoot.querySelectorAll('lightning-card');
        // The outer wrapper card + one inner card per template
        expect(cards.length).toBeGreaterThanOrEqual(templates.length);
    });

    test('each card has an Install on Record button', async () => {
        getCatalog.mockResolvedValue([makeTemplate(), makeTemplate({ DeveloperName: 'T2' })]);
        const el = createElement_catalog();
        await flushPromises();

        const installButtons = Array.from(el.shadowRoot.querySelectorAll('lightning-button'))
            .filter(b => b.label === 'Install on Record');
        expect(installButtons.length).toBe(2);
    });
});

// ── Install behavior ──────────────────────────────────────────────────────────

describe('installTemplate', () => {
    test('calls installTemplate with correct aptUniqueName and recordId on Install click', async () => {
        const tmpl = makeTemplate({ APT_Unique_Name__c: 'NEPA_CE_Water_Resources' });
        getCatalog.mockResolvedValue([tmpl]);
        installTemplate.mockResolvedValue('a00000000000PLAN');

        const recordId = 'a000000000000REC';
        const el = createElement_catalog(recordId);
        await flushPromises();

        const installBtn = Array.from(el.shadowRoot.querySelectorAll('lightning-button'))
            .find(b => b.label === 'Install on Record');
        installBtn.click();
        await flushPromises();

        expect(installTemplate).toHaveBeenCalledWith({
            recordId:    recordId,
            aptUniqueName: 'NEPA_CE_Water_Resources'
        });
    });

    test('shows success message with Action Plan ID after successful install', async () => {
        getCatalog.mockResolvedValue([makeTemplate()]);
        installTemplate.mockResolvedValue('a00000000000PLAN');

        const el = createElement_catalog();
        await flushPromises();

        const installBtn = Array.from(el.shadowRoot.querySelectorAll('lightning-button'))
            .find(b => b.label === 'Install on Record');
        installBtn.click();
        await flushPromises();

        const msgEl = el.shadowRoot.querySelector('.slds-notify');
        expect(msgEl).not.toBeNull();
        expect(msgEl.textContent).toContain('a00000000000PLAN');
    });

    test('shows error message when installTemplate fails', async () => {
        getCatalog.mockResolvedValue([makeTemplate()]);
        installTemplate.mockRejectedValue({
            body: { message: 'ActionPlanTemplate not found or inactive: NEPA_CE_Water_Resources' }
        });

        const el = createElement_catalog();
        await flushPromises();

        const installBtn = Array.from(el.shadowRoot.querySelectorAll('lightning-button'))
            .find(b => b.label === 'Install on Record');
        installBtn.click();
        await flushPromises();

        const msgEl = el.shadowRoot.querySelector('.slds-theme_error');
        expect(msgEl).not.toBeNull();
        expect(msgEl.textContent).toContain('not found or inactive');
    });

    test('disables all Install buttons while an install is in progress', async () => {
        let resolveInstall;
        getCatalog.mockResolvedValue([makeTemplate()]);
        installTemplate.mockReturnValue(new Promise(res => { resolveInstall = res; }));

        const el = createElement_catalog();
        await flushPromises();

        const installBtn = Array.from(el.shadowRoot.querySelectorAll('lightning-button'))
            .find(b => b.label === 'Install on Record');
        installBtn.click();
        await Promise.resolve();

        expect(installBtn.disabled).toBe(true);

        resolveInstall('a00000000000PLAN');
        await flushPromises();
    });
});

// ── Error state ───────────────────────────────────────────────────────────────

describe('getCatalog error handling', () => {
    test('shows error alert when getCatalog fails', async () => {
        getCatalog.mockRejectedValue({ body: { message: 'SOQL query failed' } });
        const el = createElement_catalog();
        await flushPromises();

        const errorEl = el.shadowRoot.querySelector('.slds-alert_error');
        expect(errorEl).not.toBeNull();
        expect(errorEl.textContent).toContain('SOQL query failed');
    });
});
