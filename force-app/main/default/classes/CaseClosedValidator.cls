public with sharing class CaseClosedValidator {
    public static Boolean isClosed(Case caseRecord) {
        return caseRecord != null && caseRecord.IsClosed == true;
    }
} 
