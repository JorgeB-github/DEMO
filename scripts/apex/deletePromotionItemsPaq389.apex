/**
 * Se eliminan promotion items de promoción paquete 389
 * 9 mayo 2025
 * Jorge Infante / Jesús Ayala
 * / */
 List<vlocity_cmt__PromotionItem__c> lLstPromotions = [SELECT Id FROM vlocity_cmt__PromotionItem__c WHERE 
 vlocity_cmt__PromotionId__r.vlocity_cmt__GlobalKey__c in ('a54c7ea6-d963-ebf3-e418-b0d9724bd128','89beb214-5727-3490-2b36-1212a9619e8a')];
 if (lLstPromotions.isEmpty()) { return; }
 
 Database.delete(lLstPromotions);
