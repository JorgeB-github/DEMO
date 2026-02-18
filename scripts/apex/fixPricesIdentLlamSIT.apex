/**
 * @description       : Fix Para error de precios duplicados en fixsit producto identificador de llamadas
 * @author            : Jesús Ayala
 * @last modified on  : 20-feb-2025
 * @last modified by  : Jesús Ayala
**/

list<vlocity_cmt__PriceListEntry__c> Pln = [SELECT Id FROM vlocity_cmt__PriceListEntry__c WHERE 
vlocity_cmt__PriceListId__r.Name = 'Residencial - Solo Datos' AND vlocity_cmt__ProductId__r.name ='Identificador de Llamadas'];
delete Pln;

list<vlocity_cmt__PriceListEntry__c> Pln2 = [SELECT Id FROM vlocity_cmt__PriceListEntry__c WHERE 
vlocity_cmt__DisplayText__c = '0' AND vlocity_cmt__ProductId__r.name ='Identificador de Llamadas'];
delete Pln2;

list<vlocity_cmt__PriceListEntry__c> PlnB = [SELECT Id FROM vlocity_cmt__PriceListEntry__c WHERE 
 vlocity_cmt__ProductId__r.name ='llamada en espera' and vlocity_cmt__PriceListId__r.Name = 'Residencial - Voz y Datos' and vlocity_cmt__DisplayText__c= '29.87 MXN Mensuales c/Impuestos'];
if (PlnB.size() > 1){
    list<vlocity_cmt__PriceListEntry__c> PlnB2 = [SELECT Id FROM vlocity_cmt__PriceListEntry__c WHERE 
 		vlocity_cmt__ProductId__r.name ='llamada en espera' and vlocity_cmt__PriceListId__r.Name = 'Residencial - Voz y Datos' and vlocity_cmt__DisplayText__c= '29.87 MXN Mensuales c/Impuestos' limit 1];
    delete PlnB2;    
}