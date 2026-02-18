/**
 * @description       : Fix Para bug de precios en antivirus y claro drive 400 gb por bug 5099 en SIT
 * @author            : Jesús Ayala
 * @last modified on  : 14-mar-2025
 * @last modified by  : Jesús Ayala
**/

list<vlocity_cmt__PriceListEntry__c> Pln = [SELECT Id, vlocity_cmt__EffectiveFromDate__c FROM vlocity_cmt__PriceListEntry__c WHERE 
vlocity_cmt__PriceListId__r.Name like '%Solo Datos' AND vlocity_cmt__ProductId__r.name in 
('Antivirus Mcafee') and vlocity_cmt__EffectiveFromDate__c = 2024-12-14T18:00:00.000+0000];

delete Pln;


list<vlocity_cmt__PriceListEntry__c> Pln2 = [SELECT Id, vlocity_cmt__EffectiveFromDate__c FROM vlocity_cmt__PriceListEntry__c WHERE 
vlocity_cmt__PriceListId__r.Name like '%Voz y Datos' AND vlocity_cmt__ProductId__r.name in 
('Claro Drive 400GB') and vlocity_cmt__EffectiveFromDate__c = 2025-02-06T06:00:00.000+0000];

delete Pln2;