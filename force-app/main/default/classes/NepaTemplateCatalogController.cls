/**
 * F-11: Agency Template Exchange catalog controller.
 * Provides filtered catalog queries and ActionPlan launch for the nepaTemplateCatalog LWC.
 * Reads NEPA_Template_Catalog__mdt — CMT reads are guest-safe (no FLS/CRUD).
 */
public with sharing class NepaTemplateCatalogController {

    @AuraEnabled(cacheable=true)
    @SuppressWarnings('PMD.ApexCRUDViolation')
    public static List<NEPA_Template_Catalog__mdt> getCatalog(String reviewType, String sector) {
        String query = 'SELECT Id, DeveloperName, MasterLabel, Template_Name__c, Template_Category__c, ' +
                       'Agency__c, Review_Type__c, Sector__c, APT_Unique_Name__c, ' +
                       'Package_Version__c, Description__c ' +
                       'FROM NEPA_Template_Catalog__mdt ' +
                       'WHERE Is_Active__c = true';

        List<Object> bindValues = new List<Object>();

        if (String.isNotBlank(reviewType) && reviewType != 'All') {
            query += ' AND (Review_Type__c = :reviewType OR Review_Type__c = \'All\')';
            bindValues.add(reviewType);
        }
        if (String.isNotBlank(sector)) {
            query += ' AND Sector__c LIKE :sectorPattern';
            bindValues.add('%' + sector + '%');
        }

        query += ' ORDER BY Review_Type__c, Sector__c, MasterLabel LIMIT 200';

        // CMT SOQL cannot use bind variables in dynamic SOQL — build static query branches instead
        if (String.isBlank(reviewType) || reviewType == 'All') {
            if (String.isBlank(sector)) {
                return [SELECT Id, DeveloperName, MasterLabel, Template_Name__c, Template_Category__c,
                               Agency__c, Review_Type__c, Sector__c, APT_Unique_Name__c,
                               Package_Version__c, Description__c
                        FROM NEPA_Template_Catalog__mdt
                        WHERE Is_Active__c = true
                        ORDER BY Review_Type__c, Sector__c, MasterLabel
                        LIMIT 200];
            }
            String sectorPat = '%' + sector + '%';
            return [SELECT Id, DeveloperName, MasterLabel, Template_Name__c, Template_Category__c,
                           Agency__c, Review_Type__c, Sector__c, APT_Unique_Name__c,
                           Package_Version__c, Description__c
                    FROM NEPA_Template_Catalog__mdt
                    WHERE Is_Active__c = true AND Sector__c LIKE :sectorPat
                    ORDER BY Review_Type__c, Sector__c, MasterLabel
                    LIMIT 200];
        }

        if (String.isBlank(sector)) {
            return [SELECT Id, DeveloperName, MasterLabel, Template_Name__c, Template_Category__c,
                           Agency__c, Review_Type__c, Sector__c, APT_Unique_Name__c,
                           Package_Version__c, Description__c
                    FROM NEPA_Template_Catalog__mdt
                    WHERE Is_Active__c = true
                      AND (Review_Type__c = :reviewType OR Review_Type__c = 'All')
                    ORDER BY Review_Type__c, Sector__c, MasterLabel
                    LIMIT 200];
        }

        String sectorPattern = '%' + sector + '%';
        return [SELECT Id, DeveloperName, MasterLabel, Template_Name__c, Template_Category__c,
                       Agency__c, Review_Type__c, Sector__c, APT_Unique_Name__c,
                       Package_Version__c, Description__c
                FROM NEPA_Template_Catalog__mdt
                WHERE Is_Active__c = true
                  AND (Review_Type__c = :reviewType OR Review_Type__c = 'All')
                  AND Sector__c LIKE :sectorPattern
                ORDER BY Review_Type__c, Sector__c, MasterLabel
                LIMIT 200];
    }

    @AuraEnabled
    public static String installTemplate(Id recordId, String aptUniqueName) {
        if (String.isBlank(aptUniqueName)) {
            throw new AuraHandledException('APT developer name is required.');
        }
        if (recordId == null) {
            throw new AuraHandledException('Record ID is required to install a template.');
        }

        List<ActionPlanTemplate> templates = [
            SELECT Id, Name, UniqueName,
                   (SELECT Id FROM ActionPlanTemplateVersions WHERE Status = 'Active' ORDER BY Version DESC LIMIT 1)
            FROM ActionPlanTemplate
            WHERE UniqueName = :aptUniqueName
            WITH USER_MODE
            LIMIT 1
        ];

        if (templates.isEmpty() || templates[0].ActionPlanTemplateVersions.isEmpty()) {
            throw new AuraHandledException('ActionPlanTemplate not found or has no active version: ' + aptUniqueName +
                '. Verify the template is active in Setup → Action Plans → Templates.');
        }

        ActionPlan ap = new ActionPlan();
        ap.ActionPlanTemplateVersionId = templates[0].ActionPlanTemplateVersions[0].Id;
        ap.Name = templates[0].Name;
        ap.StartDate = Date.today();

        // Relate to the correct object based on record ID prefix
        String objPrefix = String.valueOf(recordId).left(3);
        Schema.SObjectType sot = Schema.getGlobalDescribe().get(getObjectApiName(objPrefix));
        if (sot != null) {
            ap.put(getActionPlanRelationshipField(sot.getDescribe().getName()), recordId);
        }

        Database.insert(ap, AccessLevel.USER_MODE);
        return ap.Id;
    }

    private static String getObjectApiName(String keyPrefix) {
        for (Schema.SObjectType t : Schema.getGlobalDescribe().values()) {
            if (t.getDescribe().getKeyPrefix() == keyPrefix) {
                return t.getDescribe().getName();
            }
        }
        return null;
    }

    private static String getActionPlanRelationshipField(String objectName) {
        Map<String, String> relFields = new Map<String, String>{
            'IndividualApplication' => 'IndividualApplicationId',
            'Program'               => 'ProgramId',
            'WorkOrder'             => 'WorkOrderId'
        };
        return relFields.containsKey(objectName) ? relFields.get(objectName) : null;
    }
}
