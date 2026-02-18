/*
    Automación para resolver el error de CurrencyIso, Borramos las Orders/OrderItems, borramos los Product2
    y recreamos los mismos en los ambientes.
*/
List<Product2> lLstProducts = [SELECT Id FROM Product2 WHERE vlocity_cmt__GlobalKey__c = '78800f3f-7136-1c28-e16b-86ffcd648b40' AND  vlocity_cmt__GlobalKey__c = '48336830-9dea-ab95-1048-cb79b3069bf6'];
if (lLstProducts.isEmpty()) { return; }
List<OrderItem> lLstOItems = [SELECT Id, OrderId FROM OrderItem WHERE Product2Id IN :lLstProducts];
if (!lLstOItems.isEmpty()) 
{ 
    List<Id> lSetIdOrders = new List<Id>();
    for (OrderItem i : lLstOItems) { lSetIdOrders.add(i.OrderId); }
    Database.delete(lSetIdOrders);
}
Database.delete(lLstProducts);
