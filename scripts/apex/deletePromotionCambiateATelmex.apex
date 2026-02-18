/**
 * Se eliminan promotion items de promoción de Cámbiate a Telmex
 * 26 mayo 2025
 * Jorge Infante
 * / */
List<vlocity_cmt__PromotionItem__c> lLstPromotions = [SELECT Id FROM vlocity_cmt__PromotionItem__c WHERE vlocity_cmt__PromotionId__r.vlocity_cmt__GlobalKey__c in 
('19cec0ae-7e50-61af-e32b-d20f7e17fc5e')];
if (lLstPromotions.isEmpty()) { return; }

Database.delete(lLstPromotions);