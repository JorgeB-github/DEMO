/*
    Automación para resolver el error de CurrencyIso, Borramos las Orders/OrderItems, borramos los Product2
    y recreamos los mismos en los ambientes.
*/
List<vlocity_cmt__AttributeAssignment__c> lLstAssignments = [SELECT Id FROM vlocity_cmt__AttributeAssignment__c WHERE ID = 'a0WD3000004CfaBMAS'];
if (lLstAssignments.isEmpty()) { return; }
Database.delete(lLstAssignments);