/**
 * Se eliminan promotion items de promoción de prime video para corrección de error
 * 07 marzo 2025
 * Jesús Ayala / Jorge Infante
 * / */
 List<vlocity_cmt__PromotionItem__c> lLstPromotions = [SELECT Id FROM vlocity_cmt__PromotionItem__c 
 WHERE vlocity_cmt__PromotionId__r.vlocity_cmt__GlobalKey__c in ('1d560e2d-61c2-51e5-4414-1866e920c747','e01a3240-af7c-d504-54b6-e55bea70449f')];
 if (lLstPromotions.isEmpty()) { return; }
 
 Database.delete(lLstPromotions);