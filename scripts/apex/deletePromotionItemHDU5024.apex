/**
 * Se eliminan promotion items de promoción de cambiate a Telmex (NEGOCIO) para limpiar en QA02
 * 29 mayo 2025
 * Josue Pineda
 * / */
 List<vlocity_cmt__PromotionItem__c> lLstPromotions = [SELECT Id FROM vlocity_cmt__PromotionItem__c WHERE vlocity_cmt__PromotionId__r.vlocity_cmt__GlobalKey__c in ('7c18e52d-2dca-be68-5740-7c1472fe60ba', '23692e5f-e5cb-dacb-ddeb-2266324970c3')];
 if (lLstPromotions.isEmpty()) { return; }
 
 Database.delete(lLstPromotions);