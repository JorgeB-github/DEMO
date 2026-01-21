@isTest
private class TMX_VNT_ActualizarEstadoOrden_Test {
    @isTest
    static void testActualizarEstadoOrden() {
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;

        Order testOrder = new Order(
            AccountId = testAccount.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft'
        );

        Insert testOrder;
        
        TMX_VNT_ActualizarEstadoOrden.Input input = new TMX_VNT_ActualizarEstadoOrden.Input();
        input.recordId = testOrder.Id;
        input.status = 'Activated';
        
        Test.startTest();
        TMX_VNT_ActualizarEstadoOrden.actualizarEstadoOrden(new List<TMX_VNT_ActualizarEstadoOrden.Input>{input});
        Test.stopTest();
        
        Order updatedOrder = [SELECT Status FROM Order WHERE Id = :testOrder.Id];
        System.assertEquals('Draft', updatedOrder.Status, 'El estado del pedido no se actualizó correctamente.');
    }
}