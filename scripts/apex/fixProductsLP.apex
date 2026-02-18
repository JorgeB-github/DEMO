/**
 * @description       : Fix Para error de precios duplicados
 * @author            : Jorge Infante / Cristian Maziere / Jesús Ayala
 * @last modified on  : 12-feb-2025
 * @last modified by  : Jesús Ayala
**/
list<vlocity_cmt__PriceListEntry__c> Pln = [SELECT Id, vlocity_cmt__DisplayText__c FROM vlocity_cmt__PriceListEntry__c WHERE 
vlocity_cmt__PriceListId__r.Name = 'Residencial - Solo Datos' AND vlocity_cmt__ProductId__r.Name LIKE '%McAfee%' and vlocity_cmt__DisplayText__c = '0'];
delete Pln;

list<vlocity_cmt__PriceListEntry__c> Pln2 = [SELECT Id, vlocity_cmt__DisplayText__c FROM vlocity_cmt__PriceListEntry__c WHERE 
vlocity_cmt__PriceListId__r.Name = 'Residencial - Solo Datos' AND vlocity_cmt__ProductId__r.Name LIKE '%Facitel%'];
delete Pln2;

list<vlocity_cmt__PriceListEntry__c> Pln3 = [SELECT Id, vlocity_cmt__DisplayText__c FROM vlocity_cmt__PriceListEntry__c WHERE 
vlocity_cmt__PriceListId__r.Name = 'Residencial - Solo Datos' AND vlocity_cmt__ProductId__r.Name LIKE '%Gigaset%'];
delete Pln3;

list<vlocity_cmt__PriceListEntry__c> Pln4 = [SELECT Id, vlocity_cmt__DisplayText__c FROM vlocity_cmt__PriceListEntry__c WHERE 
vlocity_cmt__PriceListId__r.Name = 'Residencial - Solo Datos' AND vlocity_cmt__ProductId__r.Name LIKE '%Motorola%'];
delete Pln4;

list<vlocity_cmt__PriceListEntry__c> Pln5 = [SELECT Id, vlocity_cmt__DisplayText__c, vlocity_cmt__GlobalKey__c  FROM vlocity_cmt__PriceListEntry__c WHERE 
vlocity_cmt__PriceListId__r.Name = 'Residencial - Solo Datos' AND vlocity_cmt__ProductId__r.Name LIKE '%gasto%'];
delete Pln5;