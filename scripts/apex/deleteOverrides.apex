/*
    Automación para resolver borrar overrides y assignments de sit
*/

List<vlocity_cmt__OverrideDefinition__c> lLstOverrides = [SELECT ID FROM vlocity_cmt__OverrideDefinition__c];
database.delete(lLstOverrides);

List<vlocity_cmt__AttributeAssignment__c> lLstAssignments = [SELECT ID FROM vlocity_cmt__AttributeAssignment__c];
database.delete(lLstAssignments);
