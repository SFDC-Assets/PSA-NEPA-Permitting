/**
 * Maps a PermitTEC v0.1 record to a Salesforce nepa_litigation__c object.
 *
 * PermitTEC structure: { version, data: { case_uuid, case_metadata, linked_to } }
 * Each case_metadata field is { value: string|null, source: string }.
 * linked_to carries the netatec_project_uuid join key to Program.nepa_project_id__c.
 */

const PREVAILING_PARTY_MAP = {
    Agency: 'Agency',
    Challenger: 'Challenger',
    'Cannot be determined': 'Cannot be determined',
};

/**
 * Extract a scalar string from a PermitTEC field { value, source }.
 * Returns '' for null/missing values.
 */
function fieldValue(fieldObj) {
    if (!fieldObj) return '';
    return fieldObj.value || '';
}

/**
 * Parse a PermitTEC ruling_date "YYYY-MM-DD HH:MM:SS" to a Salesforce Date string "YYYY-MM-DD".
 * Returns null when the value is absent or unparseable.
 */
function parseRulingDate(dateStr) {
    if (!dateStr) return null;
    const match = dateStr.match(/^(\d{4}-\d{2}-\d{2})/);
    return match ? match[1] : null;
}

/**
 * Map a PermitTEC record to a Salesforce nepa_litigation__c record.
 * nepa_related_project__c is null here — set by the caller after Program lookup
 * using nepatec_project_uuid → Program.nepa_project_id__c.
 */
function mapLitigation(record) {
    const data = record.data || record;
    const cm = data.case_metadata || {};
    const lt = data.linked_to || {};

    const rawParty = fieldValue(cm.prevailing_party);

    return {
        // ExternalId — use as upsert key
        Name: data.case_uuid,
        // Case metadata
        nepa_case_title__c: fieldValue(cm.case_title),
        nepa_citation__c: fieldValue(cm.citation),
        nepa_court__c: fieldValue(cm.court) || null,
        nepa_circuit__c: fieldValue(cm.circuit),
        nepa_plaintiff__c: fieldValue(cm.plaintiff),
        nepa_defendant__c: fieldValue(cm.defendant),
        nepa_ruling_date__c: parseRulingDate(fieldValue(cm.ruling_date)),
        nepa_prevailing_party__c: PREVAILING_PARTY_MAP[rawParty] || null,
        // Linkage
        nepa_in_nepatec__c: lt.in_nepatec === 'true',
        nepa_contested_project_name__c: lt.contested_project_name || null,
        nepa_llm_keywords__c: Array.isArray(lt.llm_extracted_keywords)
            ? lt.llm_extracted_keywords.join('; ')
            : null,
        _nepatec_project_uuid: lt.nepatec_project_uuid || null,
        // nepa_related_project__c set by caller
        nepa_related_project__c: null,
        // Provenance
        nepa_data_source_system__c: 'PermitTEC',
        nepa_data_record_version__c: record.version || data.version || '0.1',
    };
}

module.exports = {
    mapLitigation,
    parseRulingDate,
    fieldValue,
    PREVAILING_PARTY_MAP,
};
