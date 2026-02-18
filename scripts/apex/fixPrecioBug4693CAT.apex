/**
 * @description       : Fix Para bug 4693, se quita precio 0 de producto de voz (5) para LP de sólo datos
 * @author            : Jesús Ayala
 * @last modified on  : 07-marzo-2025
 * @last modified by  : Jesús Ayala
**/
list<vlocity_cmt__PriceListEntry__c> Pln = [SELECT Id FROM vlocity_cmt__PriceListEntry__c WHERE 
vlocity_cmt__PriceListId__r.Name = 'Residencial - Solo Datos' AND vlocity_cmt__ProductId__r.Name = 'voz'];
delete Pln;