/**
 * Se eliminan promotion items y promociones que se migraron del ambiente anterior
 * 19 mayo 2025
 * Jesús Ayala / Jorge Infante / Cristian Maziere
 * / */
 List<vlocity_cmt__PromotionItem__c> lLstPromotions = [SELECT Id FROM vlocity_cmt__PromotionItem__c WHERE vlocity_cmt__PromotionId__r.vlocity_cmt__GlobalKey__c in 
 ('e01a3240-af7c-d504-54b6-e55bea70449f','7335c275-ce19-8c6d-3c4a-0952ccea5f6e','19cec0ae-7e50-61af-e32b-d20f7e17fc5e')];
 if (lLstPromotions.isEmpty()) { return; }
 Database.delete(lLstPromotions);