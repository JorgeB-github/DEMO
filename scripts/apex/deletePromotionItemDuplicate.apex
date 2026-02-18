/**
 * Se eliminan promotion items de promoción de prime video para corrección de error
 * 20 Febrero 2025
 * jorge
 **/
 List<vlocity_cmt__PromotionItem__c> lLstPromotions = [SELECT Id FROM vlocity_cmt__PromotionItem__c WHERE vlocity_cmt__PromotionId__r.vlocity_cmt__GlobalKey__c in (
'339a4dd2-e8b7-d762-8bae-e8f7e89c0e5a',
'1d560e2d-61c2-51e5-4414-1866e920c747',
'e01a3240-af7c-d504-54b6-e55bea70449f',
'88e9d269-1d24-e4e3-c224-34efc04b7a78',
'3f23bfa7-a3f7-90da-ecc9-c5634f6ec797',
'586b46fe-353b-1e85-07af-157fecb4cddb',
'59d6c436-2c05-4d28-4bbf-030ff587becd',
'78485f3c-5ae4-8d55-d468-bb656e132f3d'
 )];
 if (lLstPromotions.isEmpty()) { return; }
 
 Database.delete(lLstPromotions);