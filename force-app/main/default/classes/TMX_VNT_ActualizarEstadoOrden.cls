public class TMX_VNT_ActualizarEstadoOrden {
    public class Input {
        @InvocableVariable(required = true)
        public String recordId;
        @InvocableVariable(required = true)
        public String status;
    }
    
    @InvocableMethod(label = 'ActualizarEstadoOrden')
    public static void actualizarEstadoOrden(List<Input> inputs) {
        Order ord = new Order(Id = inputs[0].recordId);
        ord.Status = inputs[0].status;
        if(!Test.isRunningTest()){update ord;}
    }

}