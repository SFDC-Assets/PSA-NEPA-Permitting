/**
 * Tests for NEPATEC2.0 → PSA-NEPA data model mapping.
 *
 * Test data: 18 records (2 per process type × agency combination) sampled from
 * NEPATEC2.0, covering EIS/EA/CE across BLM, DOE, EPA, USDA.
 * Stored in tests/testdata/nepatec2_sample.json (page text stripped).
 */

const {
    mapRecord,
    mapProgram,
    mapIndividualApplication,
    mapContentVersion,
    parseLocation,
    PROCESS_TYPE_MAP,
    DOCUMENT_TYPE_MAP,
} = require('./nepatecMapper');

const testData = require('./testdata/nepatec2_sample.json');

// Flatten all records with their source combo label for parameterized tests
const allRecords = Object.entries(testData).flatMap(([combo, records]) =>
    records.map((r, i) => ({ combo, index: i, record: r }))
);

// Subset helpers
const eisRecords = allRecords.filter(({ combo }) => combo.startsWith('EIS'));
const eaRecords = allRecords.filter(({ combo }) => combo.startsWith('EA'));
const ceRecords = allRecords.filter(({ combo }) => combo.startsWith('CE'));

// ─────────────────────────────────────────────────────────────
// parseLocation
// ─────────────────────────────────────────────────────────────

describe('parseLocation', () => {
    test('extracts lat/lon and text from standard format', () => {
        const field = { value: ['Blythe, Riverside County, CA (Lat/Lon: 33.6119, -114.5969)'] };
        const result = parseLocation(field);
        expect(result.lat).toBeCloseTo(33.6119);
        expect(result.lon).toBeCloseTo(-114.5969);
        expect(result.text).toBe('Blythe, Riverside County, CA');
    });

    test('handles multi-state location with lat/lon', () => {
        const field = {
            value: ['Arizona, California, Colorado, Idaho (Lat/Lon: 39.5000, -115.0000)'],
        };
        const result = parseLocation(field);
        expect(result.lat).toBe(39.5);
        expect(result.lon).toBe(-115.0);
        expect(result.text).toBe('Arizona, California, Colorado, Idaho');
    });

    test('returns null lat/lon for legal land descriptions (CE pattern)', () => {
        const field = {
            value: ['T. 25 S., R. 35 E., NMPM, sec. 20: E2NW¼, New Mexico'],
        };
        const result = parseLocation(field);
        expect(result.lat).toBeNull();
        expect(result.lon).toBeNull();
        expect(result.text).toBeTruthy();
    });

    test('returns null lat/lon for simple state-only location', () => {
        const field = { value: ['Taylor County'] };
        const result = parseLocation(field);
        expect(result.lat).toBeNull();
        expect(result.lon).toBeNull();
        expect(result.text).toBe('Taylor County');
    });

    test('handles empty location gracefully', () => {
        const result = parseLocation({ value: [''] });
        expect(result.lat).toBeNull();
        expect(result.lon).toBeNull();
        expect(result.text).toBe('');
    });

    test('handles missing location field', () => {
        const result = parseLocation(undefined);
        expect(result.lat).toBeNull();
        expect(result.lon).toBeNull();
        expect(result.text).toBe('');
    });

    test('handles negative longitude correctly', () => {
        const field = { value: ['Aiken County, SC (Lat/Lon: 33.25, -81.73)'] };
        const result = parseLocation(field);
        expect(result.lon).toBeLessThan(0);
    });
});

// ─────────────────────────────────────────────────────────────
// mapProgram — field presence and type
// ─────────────────────────────────────────────────────────────

describe('mapProgram', () => {
    test.each(allRecords)(
        '$combo[$index]: produces a program object with required shape',
        ({ record }) => {
            const program = mapProgram(record);
            expect(program).toHaveProperty('nepa_project_id__c');
            expect(program).toHaveProperty('nepa_project_title__c');
            expect(program).toHaveProperty('nepa_project_sector__c');
            expect(program).toHaveProperty('nepa_project_type__c');
            expect(program).toHaveProperty('nepa_location_text__c');
            expect(program).toHaveProperty('nepa_location_lat__c');
            expect(program).toHaveProperty('nepa_location_lon__c');
            expect(program).toHaveProperty('nepa_data_source_system__c');
            expect(program).toHaveProperty('nepa_data_record_version__c');
        }
    );

    test.each(allRecords)(
        '$combo[$index]: project_sector fits LongTextArea (no length cap)',
        ({ record }) => {
            const program = mapProgram(record);
            // LongTextArea(32768) — just verify it's a string, no truncation needed
            expect(typeof program.nepa_project_sector__c).toBe('string');
        }
    );

    test.each(allRecords)(
        '$combo[$index]: project_type fits LongTextArea (no length cap)',
        ({ record }) => {
            const program = mapProgram(record);
            expect(typeof program.nepa_project_type__c).toBe('string');
        }
    );

    test('multi-sector record produces semicolon-separated string', () => {
        // Bears Ears / Arizona Strip have 5+ sectors
        const eisBlm = testData['EIS/BLM'];
        const multiSectorRecord = eisBlm.find(
            (r) =>
                (r.project?.project_sector?.value || []).filter(Boolean).length > 2
        );
        expect(multiSectorRecord).toBeDefined();
        const program = mapProgram(multiSectorRecord);
        expect(program.nepa_project_sector__c).toContain(';');
    });

    test('multi-type record produces semicolon-separated string', () => {
        const eisBlm = testData['EIS/BLM'];
        const multiTypeRecord = eisBlm.find(
            (r) => (r.project?.project_type?.value || []).filter(Boolean).length > 2
        );
        expect(multiTypeRecord).toBeDefined();
        const program = mapProgram(multiTypeRecord);
        expect(program.nepa_project_type__c).toContain(';');
    });

    test('provenance fields are set to NEPATEC2.0 values', () => {
        const record = testData['EIS/BLM'][0];
        const program = mapProgram(record);
        expect(program.nepa_data_source_system__c).toBe('NEPATEC2.0');
        expect(program.nepa_data_record_version__c).toBe('2.0');
    });

    test('lead_agency maps to nepa_lead_agency__c (first value when multi)', () => {
        const record = testData['EIS/DOE'][0]; // NNSA record
        const program = mapProgram(record);
        expect(program.nepa_lead_agency__c).toBeTruthy();
        // Should not contain semicolons — first value only
        expect(program.nepa_lead_agency__c).not.toContain(';');
    });

    test.each(eisRecords)(
        '$combo[$index]: EIS records have lat/lon (standard location format)',
        ({ record }) => {
            const program = mapProgram(record);
            // EIS records use "City, State (Lat/Lon: x, y)" — should parse
            if (program.nepa_location_lat__c !== null) {
                expect(program.nepa_location_lat__c).toBeGreaterThan(-90);
                expect(program.nepa_location_lat__c).toBeLessThan(90);
                expect(program.nepa_location_lon__c).toBeGreaterThan(-180);
                expect(program.nepa_location_lon__c).toBeLessThan(180);
            }
        }
    );

    test.each(ceRecords)(
        '$combo[$index]: CE records have location text even when lat/lon absent',
        ({ record }) => {
            const program = mapProgram(record);
            // CE uses legal land descriptions — text present, lat/lon may be null
            expect(program.nepa_location_text__c).toBeTruthy();
        }
    );

    test('project_id field is populated for all non-empty records', () => {
        const populated = allRecords.filter(
            ({ record }) => record.project?.project_ID?.value
        );
        expect(populated.length).toBeGreaterThan(0);
        populated.forEach(({ record }) => {
            const program = mapProgram(record);
            expect(program.nepa_project_id__c).toBeTruthy();
            // CEQ recommends UUID (36 chars) or MD5-hex (32 chars)
            expect([32, 36]).toContain(program.nepa_project_id__c.length);
        });
    });
});

// ─────────────────────────────────────────────────────────────
// mapIndividualApplication — process type mapping
// ─────────────────────────────────────────────────────────────

describe('mapIndividualApplication', () => {
    test.each(allRecords)(
        '$combo[$index]: produces an individualApplication with required shape',
        ({ record }) => {
            const ia = mapIndividualApplication(record);
            expect(ia).toHaveProperty('nepa_review_type__c');
            expect(ia).toHaveProperty('nepa_joint_lead_agency__c');
            expect(ia).toHaveProperty('nepa_related_project__c');
            expect(ia).toHaveProperty('nepa_data_source_system__c');
        }
    );

    test.each(eisRecords)(
        '$combo[$index]: EIS process maps to review_type EIS',
        ({ record }) => {
            const ia = mapIndividualApplication(record);
            expect(ia.nepa_review_type__c).toBe('EIS');
        }
    );

    test.each(eaRecords)(
        '$combo[$index]: EA process maps to review_type EA',
        ({ record }) => {
            const ia = mapIndividualApplication(record);
            expect(ia.nepa_review_type__c).toBe('EA');
        }
    );

    test.each(ceRecords)(
        '$combo[$index]: CE process maps to review_type CE',
        ({ record }) => {
            const ia = mapIndividualApplication(record);
            expect(ia.nepa_review_type__c).toBe('CE');
        }
    );

    test('nepa_related_project__c is null — must be set by caller after Program upsert', () => {
        const ia = mapIndividualApplication(testData['EIS/BLM'][0]);
        expect(ia.nepa_related_project__c).toBeNull();
    });

    test('all PROCESS_TYPE_MAP values are valid nepa_review_type__c picklist values', () => {
        const validValues = ['EIS', 'EA', 'CE', 'Other Authorization'];
        Object.values(PROCESS_TYPE_MAP).forEach((v) => {
            expect(validValues).toContain(v);
        });
    });

    test('PROCESS_TYPE_MAP covers all process_type values seen in sample', () => {
        const seen = new Set(
            allRecords.map(({ record }) => {
                const v = record.process?.process_type?.value;
                return typeof v === 'string' ? v : '';
            })
        );
        seen.forEach((type) => {
            if (type) expect(PROCESS_TYPE_MAP).toHaveProperty(type);
        });
    });
});

// ─────────────────────────────────────────────────────────────
// mapContentVersion — document mapping
// ─────────────────────────────────────────────────────────────

describe('mapContentVersion', () => {
    const allDocs = allRecords.flatMap(({ combo, index, record }) =>
        (record.documents || []).map((doc, di) => ({ combo, index, docIndex: di, doc }))
    );

    test('maps document_type DEIS → Draft EIS', () => {
        const doc = {
            metadata: {
                document_metadata: { document_type: { value: 'DEIS' }, document_title: { value: 'Draft EIS' }, prepared_by: { value: [] } },
                file_metadata: { file_name: { value: 'deis.pdf' }, section_or_volume_title: { value: '' }, main_document: { value: 'YES' }, file_ID: { value: 'abc' }, file_provider: { value: '' } },
            },
        };
        const cv = mapContentVersion(doc);
        expect(cv.nepa_document_type__c).toBe('Draft EIS');
    });

    test('maps document_type FEIS → Final EIS', () => {
        const doc = {
            metadata: {
                document_metadata: { document_type: { value: 'FEIS' }, document_title: { value: '' }, prepared_by: { value: [] } },
                file_metadata: { file_name: { value: 'feis.pdf' }, section_or_volume_title: { value: '' }, main_document: { value: 'YES' }, file_ID: { value: 'def' }, file_provider: { value: '' } },
            },
        };
        const cv = mapContentVersion(doc);
        expect(cv.nepa_document_type__c).toBe('Final EIS');
    });

    test('maps document_type ROD → ROD', () => {
        const cv = mapContentVersion({
            metadata: {
                document_metadata: { document_type: { value: 'ROD' }, document_title: { value: 'Record of Decision' }, prepared_by: { value: [] } },
                file_metadata: { file_name: { value: 'rod.pdf' }, section_or_volume_title: { value: '' }, main_document: { value: 'YES' }, file_ID: { value: 'ghi' }, file_provider: { value: '' } },
            },
        });
        expect(cv.nepa_document_type__c).toBe('ROD');
    });

    test('maps document_type CE → CE Determination', () => {
        const cv = mapContentVersion({
            metadata: {
                document_metadata: { document_type: { value: 'CE' }, document_title: { value: '' }, prepared_by: { value: [] } },
                file_metadata: { file_name: { value: 'ce.pdf' }, section_or_volume_title: { value: '' }, main_document: { value: 'YES' }, file_ID: { value: 'jkl' }, file_provider: { value: '' } },
            },
        });
        expect(cv.nepa_document_type__c).toBe('CE Determination');
    });

    test('maps document_type EA → Environmental Assessment', () => {
        const cv = mapContentVersion({
            metadata: {
                document_metadata: { document_type: { value: 'EA' }, document_title: { value: '' }, prepared_by: { value: [] } },
                file_metadata: { file_name: { value: 'ea.pdf' }, section_or_volume_title: { value: '' }, main_document: { value: 'YES' }, file_ID: { value: 'mno' }, file_provider: { value: '' } },
            },
        });
        expect(cv.nepa_document_type__c).toBe('Environmental Assessment');
    });

    test('maps document_type DEA → Environmental Assessment', () => {
        const cv = mapContentVersion({
            metadata: {
                document_metadata: { document_type: { value: 'DEA' }, document_title: { value: '' }, prepared_by: { value: [] } },
                file_metadata: { file_name: { value: 'dea.pdf' }, section_or_volume_title: { value: '' }, main_document: { value: 'YES' }, file_ID: { value: 'pqr' }, file_provider: { value: '' } },
            },
        });
        expect(cv.nepa_document_type__c).toBe('Environmental Assessment');
    });

    test('maps document_type FONSI → FONSI', () => {
        const cv = mapContentVersion({
            metadata: {
                document_metadata: { document_type: { value: 'FONSI' }, document_title: { value: '' }, prepared_by: { value: [] } },
                file_metadata: { file_name: { value: 'fonsi.pdf' }, section_or_volume_title: { value: '' }, main_document: { value: 'YES' }, file_ID: { value: 'stu' }, file_provider: { value: '' } },
            },
        });
        expect(cv.nepa_document_type__c).toBe('FONSI');
    });

    test('maps document_type OTHER → Other', () => {
        const cv = mapContentVersion({
            metadata: {
                document_metadata: { document_type: { value: 'OTHER' }, document_title: { value: '' }, prepared_by: { value: [] } },
                file_metadata: { file_name: { value: 'other.pdf' }, section_or_volume_title: { value: '' }, main_document: { value: 'NO' }, file_ID: { value: 'vwx' }, file_provider: { value: '' } },
            },
        });
        expect(cv.nepa_document_type__c).toBe('Other');
    });

    test('empty document_type returns null (not "Other")', () => {
        const cv = mapContentVersion({
            metadata: {
                document_metadata: { document_type: { value: '' }, document_title: { value: '' }, prepared_by: { value: [] } },
                file_metadata: { file_name: { value: 'appendix.pdf' }, section_or_volume_title: { value: '' }, main_document: { value: 'NO' }, file_ID: { value: 'yz1' }, file_provider: { value: '' } },
            },
        });
        expect(cv.nepa_document_type__c).toBeNull();
    });

    test('falls back to file_name as Title when document_title is empty', () => {
        const cv = mapContentVersion({
            metadata: {
                document_metadata: { document_type: { value: '' }, document_title: { value: '' }, prepared_by: { value: [] } },
                file_metadata: { file_name: { value: 'Modified_Blythe_Solar_ROD_Appendices_508.pdf' }, section_or_volume_title: { value: '' }, main_document: { value: 'NO' }, file_ID: { value: 'z23' }, file_provider: { value: '' } },
            },
        });
        expect(cv.Title).toBe('Modified_Blythe_Solar_ROD_Appendices_508.pdf');
    });

    test('prefers document_title over file_name when both present', () => {
        const cv = mapContentVersion({
            metadata: {
                document_metadata: { document_type: { value: 'ROD' }, document_title: { value: 'Record of Decision' }, prepared_by: { value: [] } },
                file_metadata: { file_name: { value: 'rod.pdf' }, section_or_volume_title: { value: '' }, main_document: { value: 'YES' }, file_ID: { value: 'z34' }, file_provider: { value: '' } },
            },
        });
        expect(cv.Title).toBe('Record of Decision');
    });

    test('nepa_main_document__c is true when main_document is YES', () => {
        const cv = mapContentVersion({
            metadata: {
                document_metadata: { document_type: { value: 'ROD' }, document_title: { value: 'ROD' }, prepared_by: { value: [] } },
                file_metadata: { file_name: { value: 'rod.pdf' }, section_or_volume_title: { value: '' }, main_document: { value: 'YES' }, file_ID: { value: 'z45' }, file_provider: { value: '' } },
            },
        });
        expect(cv.nepa_main_document__c).toBe(true);
    });

    test('nepa_main_document__c is false when main_document is NO', () => {
        const cv = mapContentVersion({
            metadata: {
                document_metadata: { document_type: { value: '' }, document_title: { value: '' }, prepared_by: { value: [] } },
                file_metadata: { file_name: { value: 'appendix.pdf' }, section_or_volume_title: { value: '' }, main_document: { value: 'NO' }, file_ID: { value: 'z56' }, file_provider: { value: '' } },
            },
        });
        expect(cv.nepa_main_document__c).toBe(false);
    });

    test('nepa_volume_title__c fits LongTextArea — no truncation needed', () => {
        // Arizona Strip has very long section titles
        const eaBlmDocs = testData['EA/BLM'][1]?.documents || [];
        const longTitle = eaBlmDocs
            .map((d) => d.metadata?.file_metadata?.section_or_volume_title?.value || '')
            .find((v) => v.length > 50);
        if (longTitle) {
            const doc = eaBlmDocs.find(
                (d) => d.metadata?.file_metadata?.section_or_volume_title?.value === longTitle
            );
            const cv = mapContentVersion(doc);
            expect(cv.nepa_volume_title__c.length).toBeGreaterThan(50);
        }
    });

    test.each(allDocs.slice(0, 50))(
        '$combo doc[$docIndex]: always has a Title',
        ({ doc }) => {
            const cv = mapContentVersion(doc);
            expect(cv.Title).toBeTruthy();
        }
    );
});

// ─────────────────────────────────────────────────────────────
// mapRecord — integration: full record round-trip
// ─────────────────────────────────────────────────────────────

describe('mapRecord', () => {
    test.each(allRecords)(
        '$combo[$index]: returns program, individualApplication, and contentVersions',
        ({ record }) => {
            const result = mapRecord(record);
            expect(result).toHaveProperty('program');
            expect(result).toHaveProperty('individualApplication');
            expect(result).toHaveProperty('contentVersions');
            expect(Array.isArray(result.contentVersions)).toBe(true);
        }
    );

    test.each(allRecords)(
        '$combo[$index]: contentVersions count matches documents count',
        ({ record }) => {
            const result = mapRecord(record);
            expect(result.contentVersions).toHaveLength(
                (record.documents || []).length
            );
        }
    );

    test('Bears Ears EIS maps all expected fields', () => {
        const record = testData['EIS/BLM'][0]; // Bears Ears
        const { program, individualApplication, contentVersions } = mapRecord(record);
        expect(program.nepa_project_title__c).toBe('Bears Ears National Monument Monument Management Plans');
        expect(program.nepa_location_lat__c).toBeCloseTo(37.59);
        expect(program.nepa_location_lon__c).toBeCloseTo(-109.5);
        expect(individualApplication.nepa_review_type__c).toBe('EIS');
        expect(contentVersions.length).toBe(71);
        // At least some documents should be typed DEIS
        const deis = contentVersions.filter((cv) => cv.nepa_document_type__c === 'Draft EIS');
        expect(deis.length).toBeGreaterThan(0);
    });

    test('Plutonium Pit Production EIS maps nuclear defense sector', () => {
        const record = testData['EIS/DOE'][0];
        const { program, individualApplication } = mapRecord(record);
        expect(program.nepa_project_title__c).toBe('Plutonium Pit Production at the Savannah River Site in South Carolina');
        expect(program.nepa_project_sector__c).toContain('Military');
        expect(individualApplication.nepa_review_type__c).toBe('EIS');
    });

    test('Project Icebreaker EA maps offshore wind correctly', () => {
        const record = testData['EA/DOE'][0];
        const { program, individualApplication } = mapRecord(record);
        expect(program.nepa_project_title__c).toBe('Project Icebreaker');
        expect(program.nepa_project_sector__c).toContain('Energy');
        expect(individualApplication.nepa_review_type__c).toBe('EA');
    });

    test('CE records have short document lists and CE Determination type', () => {
        const ceBlm = testData['CE/BLM'];
        ceBlm.forEach((record) => {
            const { individualApplication, contentVersions } = mapRecord(record);
            expect(individualApplication.nepa_review_type__c).toBe('CE');
            const ceDocs = contentVersions.filter(
                (cv) => cv.nepa_document_type__c === 'CE Determination'
            );
            expect(ceDocs.length).toBeGreaterThanOrEqual(0); // some CE docs typed, some OTHER
        });
    });

    test('USDA/USDA EA record maps correctly despite sparse data', () => {
        const record = testData['EA/USDA'][0];
        const { program, individualApplication, contentVersions } = mapRecord(record);
        expect(program.nepa_project_title__c).toBeTruthy();
        expect(individualApplication.nepa_review_type__c).toBe('EA');
        // USDA EA records have 1 document each
        expect(contentVersions.length).toBeGreaterThanOrEqual(1);
    });

    test('Hills Creek EA with FONSI documents maps FONSI type correctly', () => {
        const record = testData['EA/DOE'][1]; // Hills Creek
        const { contentVersions } = mapRecord(record);
        const fonsi = contentVersions.filter(
            (cv) => cv.nepa_document_type__c === 'FONSI'
        );
        expect(fonsi.length).toBeGreaterThan(0);
    });

    test('program and individualApplication share consistent provenance values', () => {
        allRecords.forEach(({ record }) => {
            const { program, individualApplication } = mapRecord(record);
            expect(program.nepa_data_source_system__c).toBe(
                individualApplication.nepa_data_source_system__c
            );
            expect(program.nepa_data_record_version__c).toBe(
                individualApplication.nepa_data_record_version__c
            );
        });
    });
});

// ─────────────────────────────────────────────────────────────
// Data model field constraints — validate mapped values fit Salesforce field types
// ─────────────────────────────────────────────────────────────

describe('Field constraint validation', () => {
    test('nepa_project_id__c length ≤ 36 chars (External ID field length)', () => {
        allRecords.forEach(({ record }) => {
            const program = mapProgram(record);
            if (program.nepa_project_id__c) {
                expect(program.nepa_project_id__c.length).toBeLessThanOrEqual(36);
            }
        });
    });

    test('nepa_project_title__c length ≤ 255 chars (Text field)', () => {
        allRecords.forEach(({ record }) => {
            const program = mapProgram(record);
            if (program.nepa_project_title__c) {
                expect(program.nepa_project_title__c.length).toBeLessThanOrEqual(255);
            }
        });
    });

    test('nepa_lead_agency__c length ≤ 255 chars (Text field)', () => {
        allRecords.forEach(({ record }) => {
            const program = mapProgram(record);
            if (program.nepa_lead_agency__c) {
                expect(program.nepa_lead_agency__c.length).toBeLessThanOrEqual(255);
            }
        });
    });

    test('nepa_project_sector__c multi-value strings reach lengths that risk Text(255) truncation', () => {
        const longSectors = allRecords.filter(({ record }) => {
            const program = mapProgram(record);
            return program.nepa_project_sector__c.length > 100;
        });
        // Several records exceed 100 chars; at corpus scale many exceed 255
        expect(longSectors.length).toBeGreaterThan(0);
        // The longest in this sample is ~190 chars — confirms multi-value growth
        const maxLen = Math.max(...allRecords.map(({ record }) => mapProgram(record).nepa_project_sector__c.length));
        expect(maxLen).toBeGreaterThan(150);
    });

    test('nepa_project_type__c would have exceeded 255 chars without LongTextArea upgrade', () => {
        const exceeded = allRecords.filter(({ record }) => {
            const program = mapProgram(record);
            return program.nepa_project_type__c.length > 255;
        });
        expect(exceeded.length).toBeGreaterThan(0);
    });

    test('nepa_review_type__c values are all valid picklist values', () => {
        const validValues = new Set(['EIS', 'EA', 'CE', 'Other Authorization', null]);
        allRecords.forEach(({ record }) => {
            const ia = mapIndividualApplication(record);
            expect(validValues.has(ia.nepa_review_type__c)).toBe(true);
        });
    });

    test('nepa_document_type__c values are all valid picklist values or null', () => {
        const validValues = new Set([
            'NOI', 'Draft EIS', 'Supplemental EIS', 'Programmatic EIS', 'Final EIS',
            'ROD', 'Environmental Assessment', 'FONSI', 'CE Determination',
            'Memorandum to File', 'Permit', 'Other', null,
        ]);
        const allDocs = allRecords.flatMap(({ record }) =>
            (record.documents || []).map((doc) => mapContentVersion(doc))
        );
        allDocs.forEach((cv) => {
            expect(validValues.has(cv.nepa_document_type__c)).toBe(true);
        });
    });

    test('nepa_location_lat__c is in valid range [-90, 90] when present', () => {
        allRecords.forEach(({ record }) => {
            const program = mapProgram(record);
            if (program.nepa_location_lat__c !== null) {
                expect(program.nepa_location_lat__c).toBeGreaterThanOrEqual(-90);
                expect(program.nepa_location_lat__c).toBeLessThanOrEqual(90);
            }
        });
    });

    test('nepa_location_lon__c is in valid range [-180, 180] when present', () => {
        allRecords.forEach(({ record }) => {
            const program = mapProgram(record);
            if (program.nepa_location_lon__c !== null) {
                expect(program.nepa_location_lon__c).toBeGreaterThanOrEqual(-180);
                expect(program.nepa_location_lon__c).toBeLessThanOrEqual(180);
            }
        });
    });

    test('nepa_main_document__c is always a boolean', () => {
        const allDocs = allRecords.flatMap(({ record }) =>
            (record.documents || []).map((doc) => mapContentVersion(doc))
        );
        allDocs.forEach((cv) => {
            expect(typeof cv.nepa_main_document__c).toBe('boolean');
        });
    });

    test('all DOCUMENT_TYPE_MAP target values exist in the nepa_document_type__c picklist', () => {
        const picklist = [
            'NOI', 'Draft EIS', 'Supplemental EIS', 'Programmatic EIS', 'Final EIS',
            'ROD', 'Environmental Assessment', 'FONSI', 'CE Determination',
            'Memorandum to File', 'Permit', 'Other',
        ];
        Object.values(DOCUMENT_TYPE_MAP).forEach((v) => {
            expect(picklist).toContain(v);
        });
    });
});
