/**
 * @description       : 
 * @author            : Gerardo Filitto
 * @last modified on  : 12-03-2025
 * @last modified by  : Gerardo Filitto
**/
List<vlocity_cmt__OrchestrationItemDefinition__c> orchItems = [SELECT Id, name 
        FROM vlocity_cmt__OrchestrationItemDefinition__c 
        WHERE name IN ('Recibir Notificacion de Cierre SVA')];

if (orchItems.size() > 0) {
    Database.delete(orchItems);
}

List<vlocity_cmt__OrchestrationDependencyDefinition__c> orchDependencies = [SELECT Id, name 
    FROM vlocity_cmt__OrchestrationDependencyDefinition__c  
    WHERE vlocity_cmt__GlobalKey__c  IN (
        '1848c722-c4a7-8f84-6b02-03e408edc3f4'
    )
];

if (orchDependencies.size() > 0){
    Database.delete(orchDependencies);
}
