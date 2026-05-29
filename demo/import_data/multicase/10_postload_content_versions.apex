/**
 * Creates placeholder ContentVersion records for all 5 multicase demo cases.
 * VersionData requires a Blob — cannot be passed via Bulk API v2 CSV.
 * Uses a single-space placeholder blob; real documents would replace via Files.
 *
 * Run after all CSV loads complete:
 *   sf apex run --file demo/import_data/multicase/10_postload_content_versions.apex --target-org <alias>
 */

Blob placeholder = Blob.valueOf(' ');

// Map nepa_federal_unique_id__c -> IndividualApplication Id
Map<String, Id> iaMap = new Map<String, Id>();
for (IndividualApplication ia : [
    SELECT Id, nepa_federal_unique_id__c
    FROM IndividualApplication
    WHERE nepa_federal_unique_id__c IN (
        'SAMPLE-C7C614DB', 'SAMPLE-E70EA3AD', 'SAMPLE-A8F2A17D',
        'SAMPLE-13839469', 'SAMPLE-13438D6B', 'SAMPLE-FAA-EIS-001'
    )
]) {
    iaMap.put(ia.nepa_federal_unique_id__c, ia.Id);
}
System.debug('Found IndividualApplications: ' + iaMap.keySet());

List<ContentVersion> toInsert = new List<ContentVersion>();

// ── Case A: CE / BLM (Sahara Draw Grazing) ─────────────────────────────────
Id ia_A = iaMap.get('SAMPLE-C7C614DB');
if (ia_A != null) {
    toInsert.add(new ContentVersion(
        Title                      = 'Categorical Exclusion: Grazing Lease Renewal',
        PathOnClient               = 'PDF_Lease_Renewal_CX_Sahara_Draw_Allotment_2018.pdf',
        VersionData                = placeholder,
        nepa_document_summary__c   = 'Categorical Exclusion: Grazing Lease Renewal',
        nepa_document_type__c      = 'CE Determination',
        nepa_process__c            = ia_A
    ));
    toInsert.add(new ContentVersion(
        Title                      = 'PDF Lease Renewal DR Sahara Draw Allotment 2018',
        PathOnClient               = 'PDF_Lease_Renewal_DR_Sahara_Draw_Allotment_2018.pdf',
        VersionData                = placeholder,
        nepa_document_summary__c   = 'PDF Lease Renewal DR Sahara Draw Allotment 2018',
        nepa_document_type__c      = 'Other',
        nepa_process__c            = ia_A
    ));
}

// ── Case B: EA / BLM (Pinyon Solar) ────────────────────────────────────────
Id ia_B = iaMap.get('SAMPLE-E70EA3AD');
if (ia_B != null) {
    toInsert.add(new ContentVersion(
        Title                      = 'Pinyon Solar Wildlife Resources 508',
        PathOnClient               = 'Pinyon_Solar_Wildlife_Resources_508.pdf',
        VersionData                = placeholder,
        nepa_document_summary__c   = 'Pinyon Solar Project Wildlife Resources Desert Tortoise Habitat',
        nepa_document_type__c      = 'Other',
        nepa_process__c            = ia_B
    ));
    toInsert.add(new ContentVersion(
        Title                      = 'Pinyon Solar Project EA',
        PathOnClient               = 'Pinyon_Solar_Land_Use_Designations_508.pdf',
        VersionData                = placeholder,
        nepa_document_summary__c   = 'Pinyon Solar Project Environmental Assessment',
        nepa_document_type__c      = 'EA',
        nepa_process__c            = ia_B
    ));
    toInsert.add(new ContentVersion(
        Title                      = 'Pinyon Scoping PowerPoint VPM 508',
        PathOnClient               = 'Pinyon_Scoping_PowerPoint_VPM_508.pdf',
        VersionData                = placeholder,
        nepa_document_summary__c   = 'Scoping Meeting for the Pinyon Solar Project Environmental Assessment',
        nepa_document_type__c      = 'Other',
        nepa_process__c            = ia_B
    ));
}

// ── Case C: EA / DOE (NexGen Battery Materials) ─────────────────────────────
Id ia_C = iaMap.get('SAMPLE-A8F2A17D');
if (ia_C != null) {
    toInsert.add(new ContentVersion(
        Title                      = 'EA-2205 Exhibit 13 Facility Site Plan',
        PathOnClient               = 'EA-2205_Exhibit_13_Facility_Site_Plan.pdf',
        VersionData                = placeholder,
        nepa_document_summary__c   = 'Exhibit 13 Facility Site Plan',
        nepa_document_type__c      = 'Other',
        nepa_process__c            = ia_C
    ));
    toInsert.add(new ContentVersion(
        Title                      = 'EA-2205 Exhibit 25 Tribal and SHPO Consultations',
        PathOnClient               = 'EA-2205_Exhibit_25_Tribal_SHPO_Consultations.pdf',
        VersionData                = placeholder,
        nepa_document_summary__c   = 'NexGen Battery Materials, Hopkinsville, KY: Tribal Nations and State Historic Preservation Office (SHPO) Consultations Summary',
        nepa_document_type__c      = 'Other',
        nepa_process__c            = ia_C
    ));
    toInsert.add(new ContentVersion(
        Title                      = 'EA-2205 Exhibit 15 Proposed Project Location',
        PathOnClient               = 'EA-2205_Exhibit_15_Proposed_Project_Location.pdf',
        VersionData                = placeholder,
        nepa_document_summary__c   = 'Exhibit 15 Proposed Project Location',
        nepa_document_type__c      = 'Other',
        nepa_process__c            = ia_C
    ));
}

// ── Case D: EIS / BLM (Arturo Mine) ─────────────────────────────────────────
Id ia_D = iaMap.get('SAMPLE-13839469');
if (ia_D != null) {
    toInsert.add(new ContentVersion(
        Title                      = 'Arturo Mine Record of Decision 2014',
        PathOnClient               = 'ARTURO_MINE_ROD_Final_Signed_2014.pdf',
        VersionData                = placeholder,
        nepa_document_summary__c   = 'Arturo Mine Project Record of Decision, Plan of Operations Amendment Approval, and Approval of Issuance of Right-of-Way Grants',
        nepa_document_type__c      = 'ROD',
        nepa_process__c            = ia_D
    ));
    toInsert.add(new ContentVersion(
        Title                      = 'Arturo Mine Draft EIS Executive Summary',
        PathOnClient               = 'Arturo_Mine_DEIS_Exec_Summary.pdf',
        VersionData                = placeholder,
        nepa_document_summary__c   = 'Draft Environmental Impact Statement for the Arturo Mine Project',
        nepa_document_type__c      = 'Draft EIS',
        nepa_process__c            = ia_D
    ));
    toInsert.add(new ContentVersion(
        Title                      = 'Arturo Mine DEIS Federal Register Notice of Availability',
        PathOnClient               = 'Arturo_Mine_DEIS_Federal_Register_NOA.pdf',
        VersionData                = placeholder,
        nepa_document_summary__c   = 'Notice of Availability of the Draft Environmental Impact Statement for the Arturo Mine Project, Elko County, NV',
        nepa_document_type__c      = 'NOI',
        nepa_process__c            = ia_D
    ));
}

// ── Case E: EA / USDA (Skillem Restoration) ─────────────────────────────────
Id ia_E = iaMap.get('SAMPLE-13438D6B');
if (ia_E != null) {
    toInsert.add(new ContentVersion(
        Title                      = 'Skillem Integrated Resource Restoration Project FONSI',
        PathOnClient               = 'Skillem_IRRP_FONSI.pdf',
        VersionData                = placeholder,
        nepa_document_summary__c   = 'Final Decision Notice and Finding of No Significant Impact — Skillem Integrated Resource Restoration Project',
        nepa_document_type__c      = 'FONSI',
        nepa_process__c            = ia_E
    ));
}

// ── Case F: EIS / FAA (Denver TRACON Airspace Redesign) ─────────────────────
Id ia_F = iaMap.get('SAMPLE-FAA-EIS-001');
if (ia_F != null) {
    toInsert.add(new ContentVersion(
        Title                       = 'Denver TRACON Airspace Redesign - Notice of Intent',
        PathOnClient                = 'Denver_TRACON_NOI_2021.pdf',
        VersionData                 = placeholder,
        nepa_document_type__c       = 'NOI',
        nepa_document_summary__c    = 'Federal Register Notice of Intent to prepare an EIS for the Denver TRACON Airspace Redesign Project',
        nepa_status__c              = 'Published',
        nepa_process__c             = ia_F,
        nepa_record_owner_agency__c = 'Federal Aviation Administration',
        nepa_data_source_agency__c  = 'Federal Aviation Administration',
        nepa_data_source_system__c  = 'FAA-NEPA-System',
        nepa_data_record_version__c = '1.2'
    ));
    toInsert.add(new ContentVersion(
        Title                       = 'Denver TRACON Airspace Redesign - Draft EIS',
        PathOnClient                = 'Denver_TRACON_DEIS_2023.pdf',
        VersionData                 = placeholder,
        nepa_document_type__c       = 'Draft EIS',
        nepa_document_summary__c    = 'Draft Environmental Impact Statement for the Denver TRACON Airspace Redesign Project covering noise, air quality, and environmental justice impacts',
        nepa_status__c              = 'Published',
        nepa_process__c             = ia_F,
        nepa_record_owner_agency__c = 'Federal Aviation Administration',
        nepa_data_source_agency__c  = 'Federal Aviation Administration',
        nepa_data_source_system__c  = 'FAA-NEPA-System',
        nepa_data_record_version__c = '1.2'
    ));
    toInsert.add(new ContentVersion(
        Title                       = 'Denver TRACON Airspace Redesign - Final EIS',
        PathOnClient                = 'Denver_TRACON_FEIS_2024.pdf',
        VersionData                 = placeholder,
        nepa_document_type__c       = 'Final EIS',
        nepa_document_summary__c    = 'Final Environmental Impact Statement for the Denver TRACON Airspace Redesign Project with responses to public comments and updated analysis',
        nepa_status__c              = 'Published',
        nepa_process__c             = ia_F,
        nepa_record_owner_agency__c = 'Federal Aviation Administration',
        nepa_data_source_agency__c  = 'Federal Aviation Administration',
        nepa_data_source_system__c  = 'FAA-NEPA-System',
        nepa_data_record_version__c = '1.2'
    ));
    toInsert.add(new ContentVersion(
        Title                       = 'Denver TRACON Airspace Redesign - Record of Decision',
        PathOnClient                = 'Denver_TRACON_ROD_2024.pdf',
        VersionData                 = placeholder,
        nepa_document_type__c       = 'ROD',
        nepa_document_summary__c    = 'Record of Decision selecting Alternative B for the Denver TRACON Airspace Redesign with binding noise mitigation commitments',
        nepa_status__c              = 'Approved',
        nepa_process__c             = ia_F,
        nepa_record_owner_agency__c = 'Federal Aviation Administration',
        nepa_data_source_agency__c  = 'Federal Aviation Administration',
        nepa_data_source_system__c  = 'FAA-NEPA-System',
        nepa_data_record_version__c = '1.2'
    ));
}

if (!toInsert.isEmpty()) {
    insert toInsert;
    System.debug('Inserted ' + toInsert.size() + ' ContentVersion records.');
} else {
    System.debug('No IndividualApplications found — check that CSV loads completed first.');
}
