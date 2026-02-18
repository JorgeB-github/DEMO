/*
 * Se eliminan promotion items y Promociones Basura En QA y ambientes posteriores
 * 04 junio 2025
 * Josue Pineda
 */
 List<vlocity_cmt__Promotion__c> lLstPromotions = [SELECT Id FROM vlocity_cmt__Promotion__c WHERE vlocity_cmt__GlobalKey__c in ('d37cfe6e-85f6-c9ab-48b4-f7814671c933','586b46fe-353b-1e85-07af-157fecb4cddb','339a4dd2-e8b7-d762-8bae-e8f7e89c0e5a','b6bb5162-97ef-96b4-acca-343c128b2367','3f23bfa7-a3f7-90da-ecc9-c5634f6ec797','88e9d269-1d24-e4e3-c224-34efc04b7a78')];
if (lLstPromotions.isEmpty()) { return; }
List<Id>lLstPromotionId = new List<Id>();
Set<Id> ids = new Set<Id>(new Map<Id, vlocity_cmt__Promotion__c>(lLstPromotions).keySet());
System.debug('Promotion Ids: ' + ids);
// Convert Set<Id> to List<String> using a loop
List<String> stringList = new List<String>();
for (Id id : ids) {
    stringList.add(String.valueOf(id));
}
System.debug(stringList);
Map<String, Object> outputMap = new Map<String, Object>();
Map<String, Object> optionsMap = new Map<String, Object>();
Map<String, Object> inputMap = new Map<String, Object> {'epcRequest' => new map<String, Object>{'entity'=> new map<String, Object> {'Ids' => stringList}}};
vlocity_cmt.PCAppHandler pcAppHandler = new vlocity_cmt.PCAppHandler();
pcAppHandler.invokeMethod('deletePromotion', inputMap, outputMap, optionsMap);
List<List<String>> deletePromoOutput = new List<List<String>>();
System.debug(deletePromoOutput);
