/*
    Automación para resolver borrar overrides huerfanos en SIT en post despliegue
*/

List<vlocity_cmt__OverrideDefinition__c> lLstOverrides = [
    SELECT Id FROM vlocity_cmt__OverrideDefinition__c 
    WHERE vlocity_cmt__OverrideType__c = 'Attribute' AND 
    (   
        vlocity_cmt__CompiledAttributeOverrideId__c = null 
        OR vlocity_cmt__OverriddenAttributeAssignmentId__c = null 
        OR vlocity_cmt__OverridingAttributeAssignmentId__c = null
    )
];
database.delete(lLstOverrides);

lLstOverrides = [ 
    SELECT Id FROM vlocity_cmt__OverrideDefinition__c  
    WHERE vlocity_cmt__OverrideType__c = 'Product Definition' 
    AND vlocity_cmt__OverriddenProductChildItemId__c = null
];
database.delete(lLstOverrides);