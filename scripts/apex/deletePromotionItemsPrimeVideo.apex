/**
 * Se eliminan promotion items de promoción de prime video para corrección de error
 * 22 enero 2025
 * Jesús Ayala
 * / */
List<vlocity_cmt__PromotionItem__c> lLstPromotions = [SELECT Id FROM vlocity_cmt__PromotionItem__c WHERE vlocity_cmt__PromotionId__r.vlocity_cmt__GlobalKey__c in ('339a4dd2-e8b7-d762-8bae-e8f7e89c0e5a')];
if (lLstPromotions.isEmpty()) { return; }

Database.delete(lLstPromotions);