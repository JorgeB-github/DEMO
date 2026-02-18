/**
 * Se eliminan promotion items de promoción paga por tí sólo datos
 * 12 marzo 2025
 * Jorge Infante
 * / */
 List<vlocity_cmt__PromotionItem__c> lLstPromotions = [SELECT Id FROM vlocity_cmt__PromotionItem__c WHERE 
 vlocity_cmt__PromotionId__r.vlocity_cmt__GlobalKey__c in ('7335c275-ce19-8c6d-3c4a-0952ccea5f6e','e01a3240-af7c-d504-54b6-e55bea70449f')];
 if (lLstPromotions.isEmpty()) { return; }
 
 Database.delete(lLstPromotions);

