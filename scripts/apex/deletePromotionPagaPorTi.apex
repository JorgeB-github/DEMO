/**
 * Se eliminan promotion items de promoción por error
 * 11 febrero 2025
 * Jesús Ayala
 * / */
 List<vlocity_cmt__PromotionItem__c> lLstPromotions = [SELECT Id FROM vlocity_cmt__PromotionItem__c WHERE 
 vlocity_cmt__PromotionId__r.vlocity_cmt__GlobalKey__c in ('e01a3240-af7c-d504-54b6-e55bea70449f','78485f3c-5ae4-8d55-d468-bb656e132f3d',
'59d6c436-2c05-4d28-4bbf-030ff587becd','3f23bfa7-a3f7-90da-ecc9-c5634f6ec797','88e9d269-1d24-e4e3-c224-34efc04b7a78')];
 if (lLstPromotions.isEmpty()) { return; }
 
 Database.delete(lLstPromotions);