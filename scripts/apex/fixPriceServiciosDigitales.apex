/**
 * @description       : Fix Para bug de precios en LP de sólo datos para productos de servicios digitales
 * @author            : Cristian Maziere / Jesús Ayala
 * @last modified on  : 03-mar-2025
 * @last modified by  : Jesús Ayala
**/
list<vlocity_cmt__PriceListEntry__c> Pln = [SELECT Id FROM vlocity_cmt__PriceListEntry__c WHERE 
vlocity_cmt__PriceListId__r.Name = 'Residencial - Solo Datos' AND vlocity_cmt__ProductId__r.name in 
('Llamada en Espera', 'Buzón Premium','Sígueme','Remarcado en Ocupado','Tres a la vez','Identificador de Llamadas')];

delete Pln;
