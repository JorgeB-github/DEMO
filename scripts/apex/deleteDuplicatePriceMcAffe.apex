/**
 * @description       : Fix Para error de precios duplicados
 * @author            : Jorge Infante / Cristian Maziere / Jesús Ayala
 * @last modified on  : 13-feb-2025
 * @last modified by  : Jesús Ayala
**/
list<vlocity_cmt__PriceListEntry__c> Pln = [SELECT Id, vlocity_cmt__DisplayText__c FROM vlocity_cmt__PriceListEntry__c WHERE 
vlocity_cmt__PriceListId__r.Name = 'Residencial - Solo Datos' AND vlocity_cmt__EffectiveFromDate__c = 2024-12-14T18:00:00.000+0000];
delete Pln;

