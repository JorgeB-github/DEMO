/**
 * @description         : script para eliminar la decomposition relationship de Infinitum Oferta Class a Voice Service CFS
 * @author              : Greta Moro
 * @last modified on    : 21-04-2025
 * @last modified by    : Greta Moro
**/

List<vlocity_cmt__DecompositionRelationship__c> decomRels = [
    SELECT Id, name 
    FROM vlocity_cmt__DecompositionRelationship__c 
    WHERE name = 'Infinitum Oferta Class > Voice Service CFS'
];

if (decomRels.size() > 0){
    Database.delete(decomRels);
}