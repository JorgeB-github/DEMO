/**
 * @description       : Fix Para error de precios duplicados
 * @author            : Jorge Infante / Cristian Maziere / Jesús Ayala
 * @last modified on  : 06-feb-2025
 * @last modified by  : Jesús Ayala
**/
list<vlocity_cmt__PriceListEntry__c> Pln = [SELECT Id FROM vlocity_cmt__PriceListEntry__c WHERE vlocity_cmt__PriceListId__r.Name = 'Residencial - Solo Datos' ];
delete Pln;

list<vlocity_cmt__PriceListEntry__c> Pln2 = [SELECT Id FROM vlocity_cmt__PriceListEntry__c WHERE vlocity_cmt__PriceListId__r.Name = 'Residencial - Voz y Datos' ];
delete Pln2;