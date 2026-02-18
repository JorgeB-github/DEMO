/**
 * @description       : 
 * @author            : Gerardo Filitto
 * @last modified on  : 25-04-2025
 * @last modified by  : Greta Moro
**/
List<vlocity_cmt__OrchestrationItemDefinition__c> orchItems = [SELECT Id, name 
        FROM vlocity_cmt__OrchestrationItemDefinition__c 
        WHERE name IN ('Crear Orden de Despacho Producto Fisico',
        'Notificar Mensaje de Bienvenida',
        'Instalacion de Producto Base Compleatada PORN',
        'Pedido de Producto Fisico Iniciado')];

if (orchItems.size() > 0) {
    Database.delete(orchItems);
}

List<vlocity_cmt__OrchestrationItemDefinition__c> orchItemsE2EProdFisicos = [
    SELECT Id, Name, vlocity_cmt__OrchestrationPlanDefinitionId__r.Name
    FROM vlocity_cmt__OrchestrationItemDefinition__c
    WHERE vlocity_cmt__OrchestrationPlanDefinitionId__r.Name = 'E2E Productos Fisicos'
    AND Name IN ('Assetizar', 'Cerrar Orden')
];

if (orchItemsE2EProdFisicos.size() > 0) {
    Database.delete(orchItemsE2EProdFisicos);
}

List<vlocity_cmt__OrchestrationDependencyDefinition__c> orchDependencies = [SELECT Id, name 
    FROM vlocity_cmt__OrchestrationDependencyDefinition__c  
    WHERE vlocity_cmt__GlobalKey__c  IN (
        '4ef8bed1-d2f2-d21a-d41e-0f77f85dc1e9',
        '4a66e1dd-d92e-4657-06e3-3fe090c4db06',
        '9b409d71-9534-8ce6-5a77-adadb0c056e5',
        '6ff50832-2874-18c0-8df0-996cbda7f847',
        '5905c221-f723-a5b8-23d9-af04c3cc82cd'
    )
];

if (orchDependencies.size() > 0){
    Database.delete(orchDependencies);
}

List<vlocity_cmt__OrchestrationScenario__c> scenarios = [SELECT Id, name 
FROM vlocity_cmt__OrchestrationScenario__c   
WHERE name IN (
    'Escenario E2E Productos Fisicos',
    'Escenario Venta Producto Fisico Physical Phone CFS',
    'Escenario Venta Producto Fisico Mesh CFS')
];

if (scenarios.size() > 0){
    Database.delete(scenarios);
}

List<vlocity_cmt__DecompositionRelationship__c> decomRels = [SELECT Id, name 
    FROM vlocity_cmt__DecompositionRelationship__c 
    WHERE name = 'Paquete 389 -> Borrar cuando exista la parent class'
];

if (decomRels.size() > 0){
    Database.delete(decomRels);
}

List<vlocity_cmt__OrchestrationPlanDefinition__c> orchPlans = [SELECT Id, name 
    FROM vlocity_cmt__OrchestrationPlanDefinition__c 
    WHERE name = 'E2E Productos Fisicos'
];

if (orchPlans.size() > 0){
    Database.delete(orchPlans);
}
