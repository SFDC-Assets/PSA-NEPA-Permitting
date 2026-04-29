/**
 * Tests for PermitTEC v0.1 → nepa_litigation__c data model mapping.
 *
 * Test data: 9 records sampled from PermitTEC v0.1 covering:
 *   - Circuits: DC, 9th, 4th, 10th, 11th
 *   - Prevailing party: Agency, Challenger, Cannot be determined
 *   - Linkage: linked to NEPATEC (nepatec_project_uuid set), not linked (null)
 *   - Edge cases: null court field, multi-org plaintiff (19 orgs), multi-defendant
 * Stored in tests/testdata/permittec_sample.json
 */

const {
    mapLitigation,
    parseRulingDate,
    fieldValue,
    PREVAILING_PARTY_MAP,
} = require('./permittecMapper');

const testData = require('./testdata/permittec_sample.json');

// Helpers
const byUuid = (uuid) => testData.find((r) => r.data.case_uuid === uuid);

const spireSTL = byUuid('case-2-f-4th-953');
const delawareRiverkeeper = byUuid('case-753-f-3d-1304');
const barredOwl = byUuid('case-28-f-4th-19');
const izembek = byUuid('case-29-f-4th-432');
const mountainValley = byUuid('case-24-f-4th-915');
const centralValley = byUuid('case-313-f-supp-3d-1199');
const pebbleMine = byUuid('case-1-f-4th-738');
const powderRiver = byUuid('case-358-f-supp-3d-1238');
const jaiAlai = byUuid('case-47-f-supp-3d-1353');

// ─────────────────────────────────────────────────────────────
// parseRulingDate
// ─────────────────────────────────────────────────────────────

describe('parseRulingDate', () => {
    test('extracts YYYY-MM-DD from PermitTEC datetime string', () => {
        expect(parseRulingDate('2021-06-22 00:00:00')).toBe('2021-06-22');
    });

    test('handles date-only string without time component', () => {
        expect(parseRulingDate('2022-03-04')).toBe('2022-03-04');
    });

    test('returns null for empty string', () => {
        expect(parseRulingDate('')).toBeNull();
    });

    test('returns null for null input', () => {
        expect(parseRulingDate(null)).toBeNull();
    });

    test('returns null for undefined input', () => {
        expect(parseRulingDate(undefined)).toBeNull();
    });

    test('returns null for non-date string', () => {
        expect(parseRulingDate('not a date')).toBeNull();
    });
});

// ─────────────────────────────────────────────────────────────
// fieldValue
// ─────────────────────────────────────────────────────────────

describe('fieldValue', () => {
    test('extracts value from a PermitTEC field object', () => {
        expect(fieldValue({ value: 'Agency', source: 'llm_extracted_and_manually_validated' })).toBe(
            'Agency'
        );
    });

    test('returns empty string for null value', () => {
        expect(fieldValue({ value: null, source: 'llm_extracted_and_manually_validated' })).toBe('');
    });

    test('returns empty string for missing field object', () => {
        expect(fieldValue(undefined)).toBe('');
    });

    test('returns empty string for empty value', () => {
        expect(fieldValue({ value: '', source: 'llm_extracted_and_manually_validated' })).toBe('');
    });
});

// ─────────────────────────────────────────────────────────────
// PREVAILING_PARTY_MAP
// ─────────────────────────────────────────────────────────────

describe('PREVAILING_PARTY_MAP', () => {
    test('maps Agency', () => {
        expect(PREVAILING_PARTY_MAP['Agency']).toBe('Agency');
    });

    test('maps Challenger', () => {
        expect(PREVAILING_PARTY_MAP['Challenger']).toBe('Challenger');
    });

    test('maps Cannot be determined', () => {
        expect(PREVAILING_PARTY_MAP['Cannot be determined']).toBe('Cannot be determined');
    });

    test('covers all three picklist values', () => {
        const values = Object.values(PREVAILING_PARTY_MAP);
        expect(values).toContain('Agency');
        expect(values).toContain('Challenger');
        expect(values).toContain('Cannot be determined');
    });
});

// ─────────────────────────────────────────────────────────────
// mapLitigation — output shape
// ─────────────────────────────────────────────────────────────

describe('mapLitigation — output shape', () => {
    const REQUIRED_KEYS = [
        'Name',
        'nepa_case_title__c',
        'nepa_citation__c',
        'nepa_court__c',
        'nepa_circuit__c',
        'nepa_plaintiff__c',
        'nepa_defendant__c',
        'nepa_ruling_date__c',
        'nepa_prevailing_party__c',
        'nepa_in_nepatec__c',
        'nepa_contested_project_name__c',
        'nepa_llm_keywords__c',
        '_nepatec_project_uuid',
        'nepa_related_project__c',
        'nepa_data_source_system__c',
        'nepa_data_record_version__c',
    ];

    test.each(testData.map((r) => [r.data.case_uuid, r]))(
        '%s — has all required keys',
        (_, record) => {
            const result = mapLitigation(record);
            for (const key of REQUIRED_KEYS) {
                expect(result).toHaveProperty(key);
            }
        }
    );

    test('nepa_related_project__c is always null (set by caller)', () => {
        for (const record of testData) {
            expect(mapLitigation(record).nepa_related_project__c).toBeNull();
        }
    });

    test('nepa_data_source_system__c is always PermitTEC', () => {
        for (const record of testData) {
            expect(mapLitigation(record).nepa_data_source_system__c).toBe('PermitTEC');
        }
    });
});

// ─────────────────────────────────────────────────────────────
// mapLitigation — field constraints
// ─────────────────────────────────────────────────────────────

describe('mapLitigation — field constraints', () => {
    test('Name (case_uuid) fits in 255 chars across all records', () => {
        for (const record of testData) {
            expect(mapLitigation(record).Name.length).toBeLessThanOrEqual(255);
        }
    });

    test('nepa_citation__c fits in 100 chars across all records', () => {
        for (const record of testData) {
            const result = mapLitigation(record);
            if (result.nepa_citation__c) {
                expect(result.nepa_citation__c.length).toBeLessThanOrEqual(100);
            }
        }
    });

    test('nepa_case_title__c fits in 255 chars across all records', () => {
        for (const record of testData) {
            const result = mapLitigation(record);
            if (result.nepa_case_title__c) {
                expect(result.nepa_case_title__c.length).toBeLessThanOrEqual(255);
            }
        }
    });

    test('nepa_ruling_date__c is ISO date format YYYY-MM-DD or null', () => {
        for (const record of testData) {
            const result = mapLitigation(record);
            if (result.nepa_ruling_date__c !== null) {
                expect(result.nepa_ruling_date__c).toMatch(/^\d{4}-\d{2}-\d{2}$/);
            }
        }
    });

    test('nepa_prevailing_party__c is one of the picklist values or null', () => {
        const valid = new Set(['Agency', 'Challenger', 'Cannot be determined', null]);
        for (const record of testData) {
            expect(valid.has(mapLitigation(record).nepa_prevailing_party__c)).toBe(true);
        }
    });

    test('nepa_in_nepatec__c is always a boolean', () => {
        for (const record of testData) {
            expect(typeof mapLitigation(record).nepa_in_nepatec__c).toBe('boolean');
        }
    });
});

// ─────────────────────────────────────────────────────────────
// mapLitigation — named record assertions
// ─────────────────────────────────────────────────────────────

describe('mapLitigation — Spire STL Pipeline (DC circuit, challenger win, linked)', () => {
    let result;
    beforeAll(() => {
        result = mapLitigation(spireSTL);
    });

    test('Name is the case_uuid', () => {
        expect(result.Name).toBe('case-2-f-4th-953');
    });

    test('nepa_prevailing_party__c is Challenger', () => {
        expect(result.nepa_prevailing_party__c).toBe('Challenger');
    });

    test('nepa_circuit__c is District of Columbia', () => {
        expect(result.nepa_circuit__c).toBe('District of Columbia');
    });

    test('nepa_in_nepatec__c is true', () => {
        expect(result.nepa_in_nepatec__c).toBe(true);
    });

    test('_nepatec_project_uuid joins to Program.nepa_project_id__c', () => {
        expect(result._nepatec_project_uuid).toBe('ddee6a29a3a06a44f495850065fcd664');
    });

    test('nepa_contested_project_name__c is set', () => {
        expect(result.nepa_contested_project_name__c).toBe('Spire STL Pipeline Project');
    });

    test('nepa_ruling_date__c strips time component', () => {
        expect(result.nepa_ruling_date__c).toBe('2021-06-22');
    });

    test('nepa_llm_keywords__c is semicolon-joined list', () => {
        expect(result.nepa_llm_keywords__c).toContain('Spire STL Pipeline');
        expect(result.nepa_llm_keywords__c).toContain('; FERC');
    });
});

describe('mapLitigation — Barred Owl (9th circuit, agency win, linked)', () => {
    let result;
    beforeAll(() => {
        result = mapLitigation(barredOwl);
    });

    test('nepa_prevailing_party__c is Agency', () => {
        expect(result.nepa_prevailing_party__c).toBe('Agency');
    });

    test('nepa_circuit__c is 9th', () => {
        expect(result.nepa_circuit__c).toBe('9th');
    });

    test('nepa_in_nepatec__c is true', () => {
        expect(result.nepa_in_nepatec__c).toBe(true);
    });

    test('_nepatec_project_uuid is set', () => {
        expect(result._nepatec_project_uuid).toBe('57578a0d3d45d79bbbbe17a294cbaeeb');
    });
});

describe('mapLitigation — Central Valley (Cannot be determined)', () => {
    let result;
    beforeAll(() => {
        result = mapLitigation(centralValley);
    });

    test('nepa_prevailing_party__c is Cannot be determined', () => {
        expect(result.nepa_prevailing_party__c).toBe('Cannot be determined');
    });

    test('nepa_in_nepatec__c is true', () => {
        expect(result.nepa_in_nepatec__c).toBe(true);
    });

    test('nepa_contested_project_name__c contains long project description', () => {
        expect(result.nepa_contested_project_name__c).toContain('Central Valley Project');
    });
});

describe('mapLitigation — Pebble Mine (not in NEPATEC, multi-plaintiff)', () => {
    let result;
    beforeAll(() => {
        result = mapLitigation(pebbleMine);
    });

    test('nepa_in_nepatec__c is false', () => {
        expect(result.nepa_in_nepatec__c).toBe(false);
    });

    test('_nepatec_project_uuid is null', () => {
        expect(result._nepatec_project_uuid).toBeNull();
    });

    test('nepa_contested_project_name__c is null', () => {
        expect(result.nepa_contested_project_name__c).toBeNull();
    });

    test('nepa_plaintiff__c contains all 19+ organizations', () => {
        const p = result.nepa_plaintiff__c;
        expect(p).toContain('TROUT UNLIMITED');
        expect(p).toContain('Sierra Club');
        expect(p).toContain('Natural Resources Defense Council');
        expect(p).toContain('McNeil River Alliance');
    });
});

describe('mapLitigation — Powder River / JAI ALAI (null court field)', () => {
    test('Powder River: nepa_court__c is null when source value is empty string', () => {
        const result = mapLitigation(powderRiver);
        expect(result.nepa_court__c).toBeNull();
    });

    test('JAI ALAI: nepa_court__c is null when source value is empty string', () => {
        const result = mapLitigation(jaiAlai);
        expect(result.nepa_court__c).toBeNull();
    });

    test('JAI ALAI: not in NEPATEC', () => {
        const result = mapLitigation(jaiAlai);
        expect(result.nepa_in_nepatec__c).toBe(false);
    });

    test('JAI ALAI: nepa_circuit__c is 11th', () => {
        const result = mapLitigation(jaiAlai);
        expect(result.nepa_circuit__c).toBe('11th');
    });
});

describe('mapLitigation — Izembek (multi-plaintiff, multi-defendant, both corrected)', () => {
    let result;
    beforeAll(() => {
        result = mapLitigation(izembek);
    });

    test('plaintiff contains multiple organizations', () => {
        const p = result.nepa_plaintiff__c;
        expect(p).toContain('FRIENDS OF ALASKA NATIONAL WILDLIFE REFUGES');
        expect(p).toContain('Sierra Club');
    });

    test('defendant contains agency + tribal intervenors', () => {
        const d = result.nepa_defendant__c;
        expect(d).toContain('U.S. Fish and Wildlife Service');
        expect(d).toContain('King Cove Corporation');
    });

    test('nepa_ruling_date__c is 2022-03-16', () => {
        expect(result.nepa_ruling_date__c).toBe('2022-03-16');
    });
});

describe('mapLitigation — Mountain Valley Pipeline (4th circuit, multi-plaintiff)', () => {
    let result;
    beforeAll(() => {
        result = mapLitigation(mountainValley);
    });

    test('nepa_circuit__c is 4th', () => {
        expect(result.nepa_circuit__c).toBe('4th');
    });

    test('nepa_contested_project_name__c includes Equitrans Expansion', () => {
        expect(result.nepa_contested_project_name__c).toContain(
            'Mountain Valley Pipeline and Equitrans Expansion Project'
        );
    });

    test('plaintiff contains seven organizations', () => {
        const orgs = result.nepa_plaintiff__c.split(';');
        expect(orgs.length).toBe(7);
    });
});

// ─────────────────────────────────────────────────────────────
// mapLitigation — full sample sweep
// ─────────────────────────────────────────────────────────────

describe('mapLitigation — full sample sweep', () => {
    test('all 9 records produce a non-null Name (case_uuid)', () => {
        expect(testData.length).toBe(9);
        for (const record of testData) {
            expect(mapLitigation(record).Name).toBeTruthy();
        }
    });

    test('all records have a ruling date', () => {
        for (const record of testData) {
            expect(mapLitigation(record).nepa_ruling_date__c).not.toBeNull();
        }
    });

    test('linked records have _netatec_project_uuid set', () => {
        const linked = testData.filter((r) => r.data.linked_to.in_nepatec === 'true');
        expect(linked.length).toBeGreaterThan(0);
        for (const record of linked) {
            expect(mapLitigation(record)._nepatec_project_uuid).not.toBeNull();
        }
    });

    test('unlinked records have _netatec_project_uuid null', () => {
        const unlinked = testData.filter((r) => r.data.linked_to.in_nepatec === 'false');
        expect(unlinked.length).toBeGreaterThan(0);
        for (const record of unlinked) {
            expect(mapLitigation(record)._nepatec_project_uuid).toBeNull();
        }
    });

    test('nepa_in_nepatec__c matches in_nepatec string for all records', () => {
        for (const record of testData) {
            const expected = record.data.linked_to.in_nepatec === 'true';
            expect(mapLitigation(record).nepa_in_nepatec__c).toBe(expected);
        }
    });

    test('llm_keywords are semicolon-joined for all records with keywords', () => {
        for (const record of testData) {
            const result = mapLitigation(record);
            const keywords = record.data.linked_to.llm_extracted_keywords;
            if (keywords && keywords.length > 1) {
                expect(result.nepa_llm_keywords__c).toContain('; ');
            }
        }
    });

    test('prevailing party distribution: agency + challenger + cannot_determine', () => {
        const parties = testData.map((r) => mapLitigation(r).nepa_prevailing_party__c);
        expect(parties).toContain('Agency');
        expect(parties).toContain('Challenger');
        expect(parties).toContain('Cannot be determined');
    });

    test('circuits span DC, 9th, 4th, 10th, 11th', () => {
        const circuits = new Set(testData.map((r) => mapLitigation(r).nepa_circuit__c));
        expect(circuits.has('District of Columbia')).toBe(true);
        expect(circuits.has('9th')).toBe(true);
        expect(circuits.has('4th')).toBe(true);
        expect(circuits.has('10th')).toBe(true);
        expect(circuits.has('11th')).toBe(true);
    });
});
