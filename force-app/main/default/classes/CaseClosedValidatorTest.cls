@IsTest
private class CaseClosedValidatorTest {
    @IsTest
    static void returnsTrueWhenCaseIsClosed() {
        CaseStatus closedStatus = [
            SELECT MasterLabel
            FROM CaseStatus
            WHERE IsClosed = true
            LIMIT 1
        ];
        Case caseRecord = new Case(Origin = 'Phone', Status = closedStatus.MasterLabel);
        insert caseRecord;

        Case savedCase = [
            SELECT IsClosed
            FROM Case
            WHERE Id = :caseRecord.Id
        ];

        System.assertEquals(true, CaseClosedValidator.isClosed(savedCase));
    }

    @IsTest
    static void returnsFalseWhenCaseIsOpen() {
        CaseStatus openStatus = [
            SELECT MasterLabel
            FROM CaseStatus
            WHERE IsClosed = false
            LIMIT 1
        ];
        Case caseRecord = new Case(Origin = 'Phone', Status = openStatus.MasterLabel);
        insert caseRecord;

        Case savedCase = [
            SELECT IsClosed
            FROM Case
            WHERE Id = :caseRecord.Id
        ];

        System.assertEquals(false, CaseClosedValidator.isClosed(savedCase));
    }

    @IsTest
    static void returnsFalseWhenCaseIsNull() {
        System.assertEquals(false, CaseClosedValidator.isClosed(null));
    }
}
