/**
 * Se eliminan promotion items de promoción de prime video para corrección de error
 * 22 enero 2025
 * Nelson Sosa
 * / */
 List<vlocity_cmt__PromotionItem__c> lLstPromotions = [SELECT Id FROM vlocity_cmt__PromotionItem__c WHERE vlocity_cmt__PromotionId__r.vlocity_cmt__GlobalKey__c in ('db130dc4-d6c0-f4aa-1300-19654a9cc943','3cd9a658-a1d5-9b9e-f67a-ad9c584ba1e5')];
 if (lLstPromotions.isEmpty()) { return; }
 
 Database.delete(lLstPromotions);