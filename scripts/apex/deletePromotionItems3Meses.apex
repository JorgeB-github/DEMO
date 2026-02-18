/**
 * Se eliminan promotion items de promoción 3 meses de servicio sin costo
 * 26 mayo 2025
 * Jorge Infante
 * / */
List<vlocity_cmt__PromotionItem__c> lLstPromotions = [SELECT Id FROM vlocity_cmt__PromotionItem__c WHERE vlocity_cmt__PromotionId__r.vlocity_cmt__GlobalKey__c in 
('26bfd8ef-72f1-b676-d93c-e283ab0073dd')];
if (lLstPromotions.isEmpty()) { return; }

Database.delete(lLstPromotions);