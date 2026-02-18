/**
 * Se eliminan promotion items de promoción paga por tí 
 * 06 marzo 2025
 * Jorge Infante
 * / */
 List<vlocity_cmt__PromotionItem__c> lLstPromotions = [SELECT Id FROM vlocity_cmt__PromotionItem__c WHERE 
 vlocity_cmt__PromotionId__r.vlocity_cmt__GlobalKey__c in ('e01a3240-af7c-d504-54b6-e55bea70449f')];
 if (lLstPromotions.isEmpty()) { return; }
 
 Database.delete(lLstPromotions);

