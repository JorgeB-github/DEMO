/**
 * @description       : Borrar residuos del merge de r1.1 y r2
 * @author            : Luis Lino
 * @last modified on  : 21-05-2025
 * @last modified by  : Luis Lino
**/

Database.delete([SELECT Id FROM Product2 WHERE vlocity_cmt__GlobalKey__c = 'de8e2b37-bbdd-c52f-b0b1-6064eba079b6']);
Database.delete([SELECT Id FROM vlocity_cmt__Promotion__c WHERE vlocity_cmt__GlobalKey__c IN 
('db130dc4-d6c0-f4aa-1300-19654a9cc943','3cd9a658-a1d5-9b9e-f67a-ad9c584ba1e5')]);