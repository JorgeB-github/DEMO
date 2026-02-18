/**
 * Se eliminan promotion items de promoción de prime video para corrección de error
 * 20 Febrero 2025
 * jorge
 **/
 List<vlocity_cmt__PromotionItem__c> lLstPromotions = [SELECT Id FROM vlocity_cmt__PromotionItem__c WHERE vlocity_cmt__PromotionId__r.vlocity_cmt__GlobalKey__c in (
'26bfd8ef-72f1-b676-d93c-e283ab0073dd',
'78485f3c-5ae4-8d55-d468-bb656e132f3d'
 )];
 if (lLstPromotions.isEmpty()) { return; }
 
 Database.delete(lLstPromotions);