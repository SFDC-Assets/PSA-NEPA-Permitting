/** Controller exposing public NEPA documents to Experience Cloud portal visitors. */
@SuppressWarnings('PMD.ExcessiveParameterList')
public with sharing class NepaDocumentController {

    private static final Integer DEFAULT_PAGE_SIZE = 20;
    private static final Integer MAX_PAGE_SIZE = 100;

    /** Paginated list of documents linked to a process. */
    public class DocumentListResult {
        @AuraEnabled public List<DocumentRecord> documents;
        @AuraEnabled public Integer totalCount;
    }

    /** Single document row returned to LWC. */
    public class DocumentRecord {
        @AuraEnabled public String contentVersionId;
        @AuraEnabled public String documentTitle;
        @AuraEnabled public String documentType;
        @AuraEnabled public String status;
        @AuraEnabled public String publishDate;
        @AuraEnabled public String downloadUrl;
    }

    /**
     * Returns paginated public documents linked to the given process.
     * @param processId Id of the IndividualApplication record
     * @param docTypeFilter Optional nepa_document_type__c value to restrict results
     * @param pageNumber 1-based page number; defaults to 1
     * @param pageSize Records per page; capped at MAX_PAGE_SIZE
     * @return DocumentListResult containing documents and totalCount
     */
    @SuppressWarnings('PMD.CyclomaticComplexity')
    @AuraEnabled(cacheable=true)
    public static DocumentListResult getPublicDocuments(
        String processId,
        String docTypeFilter,
        Integer pageNumber,
        Integer pageSize
    ) {
        if (String.isBlank(processId)) {
            throw auraEx('processId is required');
        }

        Integer safePageSize   = (pageSize   != null && pageSize   > 0 && pageSize   <= MAX_PAGE_SIZE) ? pageSize   : DEFAULT_PAGE_SIZE;
        Integer safePageNumber = (pageNumber != null && pageNumber > 0)                                ? pageNumber : 1;
        Integer offset         = (safePageNumber - 1) * safePageSize;

        // sfge-disable-next-line MissingNullCheckOnSoqlVariable -- String.isBlank guard at line 40
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :processId
            WITH USER_MODE
            LIMIT 1000
        ];

        if (links.isEmpty()) {
            DocumentListResult empty = new DocumentListResult();
            empty.documents  = new List<DocumentRecord>();
            empty.totalCount = 0;
            return empty;
        }

        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink cdl : links) {
            docIds.add(cdl.ContentDocumentId);
        }

        String typeFilter = String.isNotBlank(docTypeFilter) ? docTypeFilter : null;

        List<DocumentRecord> docs = new List<DocumentRecord>();
        for (ContentVersion cv : queryDocuments(docIds, typeFilter, safePageSize, offset)) {
            DocumentRecord dr = new DocumentRecord();
            dr.contentVersionId = cv.Id;
            dr.documentTitle    = cv.Title;
            dr.documentType     = cv.nepa_document_type__c;
            dr.status           = cv.nepa_status__c;
            dr.publishDate      = cv.nepa_publish_date__c != null
                ? String.valueOf(cv.nepa_publish_date__c) : null;
            // Download URL resolved separately via getContentDownloadUrl to avoid
            // constructing instance-specific URLs in a cacheable method
            dr.downloadUrl      = null;
            docs.add(dr);
        }

        DocumentListResult result = new DocumentListResult();
        result.documents  = docs;
        result.totalCount = countDocuments(docIds, typeFilter);
        return result;
    }

    /**
     * Returns a download URL for a publicly accessible ContentVersion.
     * @param contentVersionId Id of the ContentVersion record to download
     * @return Relative download URL string for the content version
     */
    @AuraEnabled(cacheable=true)
    public static String getContentDownloadUrl(String contentVersionId) {
        if (String.isBlank(contentVersionId)) {
            throw auraEx('contentVersionId is required');
        }

        // sfge-disable-next-line MissingNullCheckOnSoqlVariable -- String.isBlank guard at line 98
        List<ContentVersion> versions = [
            SELECT Id, ContentDocumentId, nepa_public_access__c
            FROM ContentVersion
            WHERE Id = :contentVersionId
              AND nepa_public_access__c = true
            WITH USER_MODE
            LIMIT 1
        ];

        if (versions.isEmpty()) {
            throw new AuraHandledException('Document not found or not publicly accessible');
        }

        return '/sfc/servlet.shepherd/version/download/' + contentVersionId;
    }

    // ── private helpers ───────────────────────────────────────────────────────

    private static AuraHandledException auraEx(String msg) {
        AuraHandledException e = new AuraHandledException(msg);
        e.setMessage(msg);
        return e;
    }

    private static Integer countDocuments(Set<Id> docIds, String typeFilter) {
        if (typeFilter != null) {
            return [
                SELECT COUNT()
                FROM ContentVersion
                WHERE ContentDocumentId IN :docIds
                  AND nepa_public_access__c = true
                  AND nepa_document_type__c = :typeFilter
                  AND IsLatest = true
                WITH USER_MODE
            ];
        }
        return [
            SELECT COUNT()
            FROM ContentVersion
            WHERE ContentDocumentId IN :docIds
              AND nepa_public_access__c = true
              AND IsLatest = true
            WITH USER_MODE
        ];
    }

    private static List<ContentVersion> queryDocuments(Set<Id> docIds, String typeFilter, Integer limitNum, Integer offsetNum) {
        Integer safeLimit  = (limitNum  != null && limitNum  > 0) ? limitNum  : 20;
        Integer safeOffset = (offsetNum != null && offsetNum >= 0) ? offsetNum : 0;
        if (safeLimit  == null) { safeLimit  = 20; }
        if (safeOffset == null) { safeOffset = 0; }
        if (typeFilter != null) {
            return [
                SELECT Id,
                       Title,
                       nepa_document_type__c,
                       nepa_status__c,
                       nepa_publish_date__c
                FROM ContentVersion
                WHERE ContentDocumentId IN :docIds
                  AND nepa_public_access__c = true
                  AND nepa_document_type__c = :typeFilter
                  AND IsLatest = true
                WITH USER_MODE
                ORDER BY nepa_publish_date__c DESC NULLS LAST
                LIMIT :safeLimit
                OFFSET :safeOffset
            ];
        }
        return [
            SELECT Id,
                   Title,
                   nepa_document_type__c,
                   nepa_status__c,
                   nepa_publish_date__c
            FROM ContentVersion
            WHERE ContentDocumentId IN :docIds
              AND nepa_public_access__c = true
              AND IsLatest = true
            WITH USER_MODE
            ORDER BY nepa_publish_date__c DESC NULLS LAST
            LIMIT :safeLimit
            OFFSET :safeOffset
        ];
    }
}
