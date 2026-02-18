/**
 * Se eliminan promotion items de promoción de prime video para corrección de error
 * 22 enero 2025
 * Nelson Sosa
 * / */
 List<vlocity_cmt__PromotionItem__c> lLstPromotions = [SELECT Id FROM vlocity_cmt__PromotionItem__c WHERE vlocity_cmt__PromotionId__r.vlocity_cmt__GlobalKey__c in ('7335c275-ce19-8c6d-3c4a-0952ccea5f6e')];
 if (lLstPromotions.isEmpty()) { return; }
 
 Database.delete(lLstPromotions);