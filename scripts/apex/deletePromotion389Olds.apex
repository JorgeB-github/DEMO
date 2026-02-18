/**
 * Se eliminan promotion items y promociones que se migraron del ambiente anterior
 * 19 mayo 2025
 * Jesús Ayala / Jorge Infante / Cristian Maziere
 * / */
 List<vlocity_cmt__PromotionItem__c> lLstPromotions = [SELECT Id FROM vlocity_cmt__PromotionItem__c WHERE vlocity_cmt__PromotionId__r.vlocity_cmt__GlobalKey__c in 
 ('db130dc4-d6c0-f4aa-1300-19654a9cc943','3cd9a658-a1d5-9b9e-f67a-ad9c584ba1e5')];
 if (lLstPromotions.isEmpty()) { return; }
 Database.delete(lLstPromotions);

  List<vlocity_cmt__Promotion__c> lLstPromotions2 = [SELECT Id FROM vlocity_cmt__Promotion__c WHERE vlocity_cmt__GlobalKey__c in 
 ('db130dc4-d6c0-f4aa-1300-19654a9cc943','3cd9a658-a1d5-9b9e-f67a-ad9c584ba1e5')];
 if (lLstPromotions2.isEmpty()) { return; }
 Database.delete(lLstPromotions2);