@SuppressWarnings('PMD.ApexAssertionsShouldIncludeMessage,PMD.MethodNamingConventions')
/**
 * FLS enforcement tests for the NEPA_Permitting permission set.
 * Verifies that system-set risk/plaintiff fields are read-only to assigned users,
 * and that readable fields are accessible. Uses Schema introspection inside System.runAs()
 * — no DML required for read-only assertions.
 */
@IsTest
private class NepaPermissionSetFlsTest {

    private static User createNepaUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            FirstName       = 'NEPA',
            LastName        = 'FLS Tester',
            Email           = 'nepa.fls.tester@example.invalid',
            Username        = 'nepa.fls.tester.' + String.valueOf(DateTime.now().getTime()) + '@example.invalid',
            Alias           = 'nflst',
            TimeZoneSidKey  = 'America/Los_Angeles',
            LocaleSidKey    = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId       = p.Id
        );
        insert u;

        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'NEPA_Permitting' LIMIT 1];
        insert new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.Id);
        return u;
    }

    // ── IndividualApplication: system-set fields must be read-only ─────────────

    @IsTest
    static void fls_plaintiffRiskFlagOnIA_isNotUpdateable() {
        User u = createNepaUser();
        System.runAs(u) {
            Schema.DescribeFieldResult dfr =
                Schema.SObjectType.IndividualApplication.fields.nepa_plaintiff_risk_flag__c;
            System.assertEquals(false, dfr.isUpdateable(),
                'nepa_plaintiff_risk_flag__c must not be updateable via NEPA_Permitting PS');
        }
    }

    @IsTest
    static void fls_riskScoreFieldOnIA_isNotUpdateable() {
        User u = createNepaUser();
        System.runAs(u) {
            Schema.DescribeFieldResult dfr =
                Schema.SObjectType.IndividualApplication.fields.nepa_risk_score__c;
            System.assertEquals(false, dfr.isUpdateable(),
                'nepa_risk_score__c must not be updateable via NEPA_Permitting PS');
        }
    }

    @IsTest
    static void fls_riskTierFieldOnIA_isNotUpdateable() {
        User u = createNepaUser();
        System.runAs(u) {
            Schema.DescribeFieldResult dfr =
                Schema.SObjectType.IndividualApplication.fields.nepa_risk_tier__c;
            System.assertEquals(false, dfr.isUpdateable(),
                'nepa_risk_tier__c must not be updateable via NEPA_Permitting PS');
        }
    }

    @IsTest
    static void fls_riskScoreFactorsOnIA_isNotUpdateable() {
        User u = createNepaUser();
        System.runAs(u) {
            Schema.DescribeFieldResult dfr =
                Schema.SObjectType.IndividualApplication.fields.nepa_risk_score_factors__c;
            System.assertEquals(false, dfr.isUpdateable(),
                'nepa_risk_score_factors__c must not be updateable via NEPA_Permitting PS');
        }
    }

    // ── PublicComplaint: plaintiff flag fields must be read-only ──────────────

    @IsTest
    static void fls_plaintiffFlagsOnComment_areNotUpdateable() {
        User u = createNepaUser();
        System.runAs(u) {
            Schema.DescribeFieldResult riskFlag =
                Schema.SObjectType.PublicComplaint.fields.nepa_plaintiff_risk_flag__c;
            Schema.DescribeFieldResult tribalFlag =
                Schema.SObjectType.PublicComplaint.fields.nepa_tribal_plaintiff_flag__c;
            Schema.DescribeFieldResult riskTier =
                Schema.SObjectType.PublicComplaint.fields.nepa_plaintiff_risk_tier__c;
            System.assertEquals(false, riskFlag.isUpdateable(),
                'PublicComplaint.nepa_plaintiff_risk_flag__c must not be updateable via NEPA_Permitting PS');
            System.assertEquals(false, tribalFlag.isUpdateable(),
                'PublicComplaint.nepa_tribal_plaintiff_flag__c must not be updateable via NEPA_Permitting PS');
            System.assertEquals(false, riskTier.isUpdateable(),
                'PublicComplaint.nepa_plaintiff_risk_tier__c must not be updateable via NEPA_Permitting PS');
        }
    }

    // ── Readable fields must be accessible ────────────────────────────────────

    @IsTest
    static void fls_riskFieldsOnIA_areReadable() {
        User u = createNepaUser();
        System.runAs(u) {
            System.assertEquals(true,
                Schema.SObjectType.IndividualApplication.fields.nepa_risk_score__c.isAccessible(),
                'nepa_risk_score__c must be readable');
            System.assertEquals(true,
                Schema.SObjectType.IndividualApplication.fields.nepa_risk_tier__c.isAccessible(),
                'nepa_risk_tier__c must be readable');
            System.assertEquals(true,
                Schema.SObjectType.IndividualApplication.fields.nepa_risk_score_factors__c.isAccessible(),
                'nepa_risk_score_factors__c must be readable');
        }
    }

    @IsTest
    static void fls_plaintiffFlagsOnComment_areReadable() {
        User u = createNepaUser();
        System.runAs(u) {
            System.assertEquals(true,
                Schema.SObjectType.PublicComplaint.fields.nepa_plaintiff_risk_flag__c.isAccessible(),
                'PublicComplaint.nepa_plaintiff_risk_flag__c must be readable');
            System.assertEquals(true,
                Schema.SObjectType.PublicComplaint.fields.nepa_tribal_plaintiff_flag__c.isAccessible(),
                'PublicComplaint.nepa_tribal_plaintiff_flag__c must be readable');
        }
    }

    // ── Positive control: System Administrator can update risk fields ─────────

    @IsTest
    static void fls_systemAdmin_canUpdateRiskScore() {
        // Running as system admin (default test context), risk score field must be updateable
        Schema.DescribeFieldResult dfr =
            Schema.SObjectType.IndividualApplication.fields.nepa_risk_score__c;
        System.assertEquals(true, dfr.isUpdateable(),
            'System Administrator must be able to update nepa_risk_score__c');
    }
}
