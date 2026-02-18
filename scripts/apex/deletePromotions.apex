
List<vlocity_cmt__PromotionItem__c> lLstPromotions = [SELECT Id FROM vlocity_cmt__PromotionItem__c WHERE vlocity_cmt__PromotionId__r.vlocity_cmt__GlobalKey__c in ('586b46fe-353b-1e85-07af-157fecb4cddb','59d6c436-2c05-4d28-4bbf-030ff587becd')];
if (lLstPromotions.isEmpty()) { return; }

Database.delete(lLstPromotions);
