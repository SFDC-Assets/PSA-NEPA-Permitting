/**
 * Maps a NEPATEC2.0 record to Salesforce PSA-NEPA data model objects.
 *
 * Each NEPATEC record represents one project with its process and documents.
 * Returns: { program, individualApplication, contentVersions }
 */

const PROCESS_TYPE_MAP = {
    'Environmental Impact Statement (EIS)': 'EIS',
    'Environmental Assessment (EA)': 'EA',
    'Categorical Exclusion': 'CE',
};

const DOCUMENT_TYPE_MAP = {
    DEIS: 'Draft EIS',
    FEIS: 'Final EIS',
    ROD: 'ROD',
    CE: 'CE Determination',
    EA: 'Environmental Assessment',
    DEA: 'Environmental Assessment',
    FONSI: 'FONSI',
    OTHER: 'Other',
};

/**
 * Extract a scalar string from a NEPATEC field value.
 * NEPATEC wraps all values as { value: string | string[] }.
 */
function scalar(fieldObj) {
    if (!fieldObj) return '';
    const v = fieldObj.value;
    if (Array.isArray(v)) return v.filter(Boolean).join('; ');
    return v || '';
}

/**
 * Parse lat/lon from NEPATEC location string.
 * Format: "City, County, State (Lat/Lon: 33.6119, -114.5969)"
 * Returns { text, lat, lon } — lat/lon null when absent (e.g., legal descriptions).
 */
function parseLocation(locationField) {
    const raw = scalar(locationField);
    if (!raw) return { text: '', lat: null, lon: null };

    const match = raw.match(/\(Lat\/Lon:\s*([-\d.]+),\s*([-\d.]+)\)/);
    if (match) {
        const lat = parseFloat(match[1]);
        const lon = parseFloat(match[2]);
        const text = raw.replace(/\s*\(Lat\/Lon:.*\)/, '').trim();
        return { text, lat, lon };
    }
    return { text: raw.trim(), lat: null, lon: null };
}

/**
 * Map a NEPATEC record to a Salesforce Program record (Entity 1: Project).
 * provenance fields are set to NEPATEC2.0 source values.
 */
function mapProgram(record) {
    const proj = record.project || {};
    const proc = record.process || {};
    const loc = parseLocation(proj.location);

    return {
        // CEQ fields
        nepa_project_id__c: scalar(proj.project_ID),
        nepa_project_title__c: scalar(proj.project_title),
        nepa_project_sector__c: scalar(proj.project_sector),
        nepa_project_type__c: scalar(proj.project_type),
        nepa_project_description__c: scalar(proj.project_description),
        nepa_lead_agency__c: scalar(proc.lead_agency)
            ? scalar(proc.lead_agency).split(';')[0].trim()
            : '',
        nepa_location_text__c: loc.text,
        nepa_location_lat__c: loc.lat,
        nepa_location_lon__c: loc.lon,
        // project_sponsor in NEPATEC is a text field; PSS Program.nepa_project_sponsor__c is a
        // Lookup to Contact — store the raw string in nepa_project_title__c for now; a real
        // import would upsert/match a Contact record first.
        _nepa_project_sponsor_raw: scalar(proj.project_sponsor),
        // Provenance
        nepa_data_source_system__c: 'NEPATEC2.0',
        nepa_data_source_agency__c: scalar(proc.lead_agency)
            ? scalar(proc.lead_agency).split(';')[0].trim()
            : '',
        nepa_record_owner_agency__c: scalar(proc.lead_agency)
            ? scalar(proc.lead_agency).split(';')[0].trim()
            : '',
        nepa_data_record_version__c: '2.0',
    };
}

/**
 * Map a NEPATEC record to a Salesforce IndividualApplication record (Entity 2: Process).
 * nepa_related_project__c is left as a placeholder — set after Program upsert.
 */
function mapIndividualApplication(record) {
    const proc = record.process || {};
    const rawType = scalar(proc.process_type);

    return {
        // CEQ fields
        nepa_review_type__c: PROCESS_TYPE_MAP[rawType] || null,
        nepa_joint_lead_agency__c: scalar(proc.lead_agency)
            ? scalar(proc.lead_agency).split(';')[0].trim()
            : '',
        // nepa_related_project__c: set by caller after Program is known
        nepa_related_project__c: null,
        // Provenance
        nepa_data_source_system__c: 'NEPATEC2.0',
        nepa_data_source_agency__c: scalar(proc.lead_agency)
            ? scalar(proc.lead_agency).split(';')[0].trim()
            : '',
        nepa_record_owner_agency__c: scalar(proc.lead_agency)
            ? scalar(proc.lead_agency).split(';')[0].trim()
            : '',
        nepa_data_record_version__c: '2.0',
    };
}

/**
 * Map a NEPATEC document entry to a Salesforce ContentVersion record (Entity 3: Documents).
 * nepa_volume_title__c uses section_or_volume_title (91% populated).
 * Title falls back to file_name when document_title is absent.
 * nepa_main_document__c maps the main_document YES/NO flag.
 */
function mapContentVersion(doc) {
    const dm = doc?.metadata?.document_metadata || {};
    const fm = doc?.metadata?.file_metadata || {};

    const rawDocType = scalar(dm.document_type);
    const documentTitle = scalar(dm.document_title) || scalar(fm.file_name);
    const mainDoc = scalar(fm.main_document);

    return {
        // Native ContentVersion
        Title: documentTitle,
        // CEQ fields
        nepa_document_type__c: DOCUMENT_TYPE_MAP[rawDocType] || (rawDocType ? 'Other' : null),
        nepa_volume_title__c: scalar(fm.section_or_volume_title),
        nepa_prepared_by__c: scalar(dm.prepared_by)
            ? scalar(dm.prepared_by).split(';')[0].trim()
            : '',
        nepa_main_document__c: mainDoc === 'YES',
        _nepa_file_name: scalar(fm.file_name),
        _nepa_document_id_raw: scalar(dm.document_ID) || scalar(fm.file_ID),
        // Provenance
        nepa_data_source_system__c: 'NEPATEC2.0',
        nepa_data_record_version__c: '2.0',
    };
}

/**
 * Map a complete NEPATEC record to all three Salesforce objects.
 * Returns { program, individualApplication, contentVersions[] }
 */
function mapRecord(record) {
    return {
        program: mapProgram(record),
        individualApplication: mapIndividualApplication(record),
        contentVersions: (record.documents || []).map(mapContentVersion),
    };
}

module.exports = {
    mapRecord,
    mapProgram,
    mapIndividualApplication,
    mapContentVersion,
    parseLocation,
    PROCESS_TYPE_MAP,
    DOCUMENT_TYPE_MAP,
};
