/**
 * Se eliminan promotion items de promociones que se actualizaron o crearon
 * 03 febrero 2025
 * Jesús Ayala
 * / */
 List<vlocity_cmt__PromotionItem__c> lLstPromotions = [SELECT Id FROM vlocity_cmt__PromotionItem__c WHERE vlocity_cmt__PromotionId__r.vlocity_cmt__GlobalKey__c in ('7335c275-ce19-8c6d-3c4a-0952ccea5f6e',
 'e01a3240-af7c-d504-54b6-e55bea70449f','339a4dd2-e8b7-d762-8bae-e8f7e89c0e5a','1d560e2d-61c2-51e5-4414-1866e920c747','26bfd8ef-72f1-b676-d93c-e283ab0073dd')];
 if (lLstPromotions.isEmpty()) { return; }
 
 Database.delete(lLstPromotions);