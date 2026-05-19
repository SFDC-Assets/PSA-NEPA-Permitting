/**
 * Invocable utility: splits a semicolon-delimited string into a trimmed String collection.
 * Called by NEPA_Permit_Record_Creator to convert nepa_co_permits_required__c into
 * individual permit label tokens for loop-based RegulatoryAuthorizationType lookup.
 */
public with sharing class NepaStringSplitter {

    public class SplitRequest {
        @InvocableVariable(label='Input String' description='Semicolon-delimited string to split' required=true)
        public String inputString;
    }

    public class SplitResult {
        @InvocableVariable(label='Tokens' description='Trimmed individual values from the input string')
        public List<String> tokens;
    }

    @InvocableMethod(
        label='Split Semicolon-Delimited String'
        description='Splits a semicolon-delimited string into a trimmed String collection. Used by NEPA_Permit_Record_Creator to tokenize the permit label string.'
        category='NEPA Utilities'
    )
    public static List<SplitResult> split(List<SplitRequest> requests) {
        List<SplitResult> results = new List<SplitResult>();
        for (SplitRequest req : requests) {
            SplitResult res = new SplitResult();
            res.tokens = new List<String>();
            if (String.isNotBlank(req.inputString)) {
                for (String token : req.inputString.split(';')) {
                    String trimmed = token.trim();
                    if (String.isNotBlank(trimmed)) {
                        res.tokens.add(trimmed);
                    }
                }
            }
            results.add(res);
        }
        return results;
    }
}
