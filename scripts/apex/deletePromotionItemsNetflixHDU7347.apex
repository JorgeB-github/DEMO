/**
 * Se eliminan promotion items de promoción de Netflix
 * 03 junio 2025
 * Josue Pineda
 * / */
List<vlocity_cmt__PromotionItem__c> lLstPromotions = [SELECT Id FROM vlocity_cmt__PromotionItem__c WHERE vlocity_cmt__PromotionId__r.vlocity_cmt__GlobalKey__c in ('59d6c436-2c05-4d28-4bbf-030ff587becd','78485f3c-5ae4-8d55-d468-bb656e132f3d')];
if (lLstPromotions.isEmpty()) { return; }
Database.delete(lLstPromotions);