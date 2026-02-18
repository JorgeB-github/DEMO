/**
 * NOTA IMPORTANTE: Este script no ejecutable para devops, 
 * es un script de prueba para ejecutar a demanda en el org.
 */

/** 
 * PASOS PARA CORRER EL CÓDIGO:
 * 1. Click en icono de 'Setup'
 * 2. Click en 'Developer Console'
 * 3. Click en 'Debug' > 'Open Execute Anonymous Window'
 * 4. Copiar y pegar el código que esta despues de la palabra SCRIPT en la ventana de 'Execute Anonymous'
 * 5. Click en 'Execute'
 *
 * PASOS PARA VERIFICAR QUE LA ORDEN SE CREÓ CORRECTAMENTE:
 * 1. Validar si el campo Order.Status es igual a 'Pendiente validar ordenes duplicadas'
 *    despues de insertar la orden, en dado caso modificar a 'Draft'
 * 
 * APROVISIONAR ORDEN:
 * 1. Avanzar la orden a 'Seleccion de oferta' y agregar los productos necesarios
 * 2. Avanzar la orden por cada estado hasta llegar a 'Resumen'
 * 3. Click en el boton 'Aprovisionar'
 *
 * NOTA: 
 * 1. Ya la orden cuenta con los datos necesarios para pasar las validaciones
 * 2. Asegurarse de que los datos sean correctos antes de aprovisionar la orden
 * 3. Asegurarse tenga los permisos necesarios para crear registros de tipo Account y Order
 * 4. Actualizar la varible 'consumerId' con el Id de la ceunta a la que se le creará la orden. 
 *    Asegurece que sea una cuenta creada por el flujo de ventas o por el script CreateTestingData
 */

 //SCRIPT

/** CAMBIAR SIEMPRE ESTE ID CON EL ID DE LA CUENTA A LA QUE SE LE CREARÁ LA ORDEN
*/
Id consumerId = '001DI00000K5LULYA3';

/** CONFIGURAR ORDEN:
* Solo si es necesario, ajustar los valores de acuerdo a la orden que se desea crear:
* 1. TMX_VNT_Tipo_de_alta__c
* 2. vlocity_cmt__OriginatingChannel__c
* 3. TMX_VNT_Tipo_de_Cliente__c
* 4. TMX_VNT_iDSpwA__c
*/
String tipoAlta = 'Alta nueva';
String canal = 'ctek';
String tipoCliente = 'Hogar';
String iDSpwA = 'UM201901221120590681';

Account cuenta = [SELECT Id, Name, TMX_VNT_Apellido_Paterno__c, 
    TMX_VNT_Apellido_Materno__c, TMX_VNT_Calle__c, TMX_VNT_Colonia__c, TMX_VNT_Estado__c,
    TMX_VNT_Numero_de_Exterior__c, Phone,
    TMX_VNT_Tipo_de_Calle__c, TMX_VNT_Tipo_de_Cliente__c,
    TMX_VNT_Ubicacion_Geografica__Latitude__s, TMX_VNT_Ubicacion_Geografica__Longitude__s,
    TMX_VNT_Numero_interior__c, TMX_VNT_Edificio__c,
    vlocity_cmt__PrimaryContactId__r.MobilePhone, 
    vlocity_cmt__PrimaryContactId__r.Email,
    vlocity_cmt__PrimaryContactId__r.MailingCity, 
    vlocity_cmt__PrimaryContactId__r.MailingCountry, 
    vlocity_cmt__PrimaryContactId__r.FirstName,
    TMX_VNT_Municipio_Alcaldia__c
    FROM Account WHERE Id = :consumerId];

Order queriedOrder = [SELECT Id, TMX_VNT_Codigo_Postal__c,
    vlocity_cmt__DefaultBillingAccountId__c,
    TMX_VNT_IdDomicilio__c, 
    Pricebook2Id, 
    RecordTypeId 
    FROM Order 
    WHERE AccountId = :consumerId AND RecordType.DeveloperName = 'StandardOrder'
    ORDER BY CreatedDate DESC
    LIMIT 1];

Account serviceOld = [SELECT Name, ParentId, TMX_VNT_Billing_Account__c, TMX_VNT_Calle__c, 
    TMX_VNT_Ciudad__c, TMX_VNT_Colonia__c, TMX_VNT_Estado__c, TMX_VNT_Municipio_Alcaldia__c, 
    TMX_VNT_Numero_de_Exterior__c, TMX_VNT_Tipo_de_Calle__c, TMX_VNT_Ubicacion_Geografica__Latitude__s, 
    TMX_VNT_Ubicacion_Geografica__Longitude__s, vlocity_cmt__IsRootResolved__c, 
    vlocity_cmt__RootAccountId__c, vlocity_cmt__Status__c, TMX_VNT_Tipo_de_Cliente__c, 
    TMX_VNT_CodigoEstado__c, TMX_VNT_IdDomicilio__c, TMX_VNT_Numero_interior__c, 
    TMX_VNT_Lote__c, TMX_VNT_Manzana__c, TMX_VNT_Entre_Calle_1__c, TMX_VNT_Entre_Calle_2__c, 
    TMX_VNT_Referencias__c, TMX_VNT_Central__c, TMX_VNT_Libreria__c, TMX_VNT_Equipo__c, 
    TMX_VNT_Esquema_DDS__c, TMX_VNT_Esquema_DB2__c, RecordTypeId
    FROM Account
    WHERE ParentId = :consumerId 
    AND RecordType.DeveloperName = 'Service' 
    ORDER BY CreatedDate DESC 
    LIMIT 1];

Account newService = serviceOld.clone(false, false, false, false);
newService.vlocity_cmt__Status__c = 'Active';
newService.IsActive = true;
insert newService;

Order orden = new Order();
orden.AccountId = cuenta.Id;
orden.EffectiveDate = Date.today();
orden.Status = 'Draft';
orden.Pricebook2Id = queriedOrder.Pricebook2Id;
orden.TMX_VNT_Apellido_Materno__c = cuenta.TMX_VNT_Apellido_Materno__c;
orden.TMX_VNT_Apellido_Paterno__c = cuenta.TMX_VNT_Apellido_Paterno__c;
orden.TMX_VNT_ApellidoMaternoTarjetahabiente__c = cuenta.TMX_VNT_Apellido_Materno__c;
orden.TMX_VNT_ApellidoPaternoTarjetahabiente__c = cuenta.TMX_VNT_Apellido_Paterno__c;
orden.TMX_VNT_ApellidoTitularEntrega__c = cuenta.TMX_VNT_Apellido_Paterno__c;
orden.TMX_VNT_Calle__c = cuenta.TMX_VNT_Calle__c.toUpperCase();
orden.TMX_VNT_CelularTarjetahabiente__c = cuenta.vlocity_cmt__PrimaryContactId__r.MobilePhone;
orden.TMX_VNT_CelularTitularEntrega__c = cuenta.vlocity_cmt__PrimaryContactId__r.MobilePhone;
orden.TMX_VNT_Codigo_Postal__c = queriedOrder.TMX_VNT_Codigo_Postal__c;
orden.TMX_VNT_Colonia__c = cuenta.TMX_VNT_Colonia__c.toUpperCase();
orden.TMX_VNT_Correo_Contacto__c = cuenta.vlocity_cmt__PrimaryContactId__r.Email;
orden.TMX_VNT_CorreoElectronicoTarjetahabiente__c = cuenta.vlocity_cmt__PrimaryContactId__r.Email;
orden.TMX_VNT_CorreoTitularEntrega__c = cuenta.vlocity_cmt__PrimaryContactId__r.Email;
orden.TMX_VNT_CreditoDisponible__c = 851;
orden.TMX_VNT_DeviceQuantity__c = '0-15';
orden.TMX_VNT_Domiciliacion__c = true;
orden.TMX_VNT_Domicilio_Facturacion_definido__c = true;
orden.TMX_VNT_DomicilioContacto__c = cuenta.vlocity_cmt__PrimaryContactId__r.MailingCity+', '+cuenta.vlocity_cmt__PrimaryContactId__r.MailingCountry;
orden.TMX_VNT_Ejecutivo_de_Venta__c = userInfo.getUserId();
orden.TMX_VNT_Estado__c =  cuenta.TMX_VNT_Estado__c.toUpperCase();
orden.TMX_VNT_Estado_Consulta__c = 'Exitosa';
orden.TMX_VNT_EstadoDeReservaFacilidad__c = 'Reservada';
orden.TMX_VNT_EstadoReservaNumero__c = 'Reservado';
orden.TMX_VNT_Factibilidad_Status__c = 'Completada';
orden.TMX_VNT_FechaFactibilidad__c = System.now();
orden.TMX_VNT_FechaReservaDeFacilidad__c = System.now();
orden.TMX_VNT_FormaPagoInstalacion__c = 'A';
orden.TMX_VNT_HasCheckout__c = true;
orden.TMX_VNT_idCorrelationSpwA__c = '29b61fd8-43a1-3f05-41af-4d328a3a2a71';
orden.TMX_VNT_IdReserva__c = '65767644';
orden.TMX_VNT_InternetUsage__c = 'Navegar en internet';
orden.TMX_VNT_LimiteCredito__c = 	4850;
orden.TMX_VNT_MismoTitular__c = true;
orden.TMX_VNT_Municipio_Alcaldia__c = cuenta.TMX_VNT_Municipio_Alcaldia__c.toUpperCase();
orden.TMX_VNT_Nombre__c = cuenta.vlocity_cmt__PrimaryContactId__r.FirstName;
orden.TMX_VNT_NombreTarjetahabiente__c = cuenta.vlocity_cmt__PrimaryContactId__r.FirstName;
orden.TMX_VNT_NombreTitularEntrega__c = cuenta.vlocity_cmt__PrimaryContactId__r.FirstName;
orden.TMX_VNT_Numero_de_Exterior__c = cuenta.TMX_VNT_Numero_de_Exterior__c;
orden.TMX_VNT_Numero_Telefonico__c = cuenta.Phone;
orden.TMX_VNT_Order_Stage__c = 'Validación del Cliente';
orden.TMX_VNT_PrivacidadNumero__c  = 'PB';
orden.TMX_VNT_ReciboSinPapel__c = true;
orden.TMX_VNT_Tecnologia_Voz__c = 'VoIP';
orden.TMX_VNT_Telefono_Contacto__c = cuenta.vlocity_cmt__PrimaryContactId__r.MobilePhone;
orden.TMX_VNT_Tipo_de_alta__c = tipoAlta;
orden.TMX_VNT_Tipo_de_Calle__c = cuenta.TMX_VNT_Tipo_de_Calle__c;
orden.TMX_VNT_Tipo_de_cliente__c = cuenta.TMX_VNT_Tipo_de_Cliente__c;
orden.TMX_VNT_Tipo_de_facturacion__c = 'Electronica';
orden.TMX_VNT_TipoDomicilio__c = 'Domicilio existente';
orden.TMX_VNT_Ubicacion_Geografica__Latitude__s = cuenta.TMX_VNT_Ubicacion_Geografica__Latitude__s;
orden.TMX_VNT_Ubicacion_Geografica__Longitude__s = cuenta.TMX_VNT_Ubicacion_Geografica__Longitude__s;
orden.vlocity_cmt__DefaultBillingAccountId__c = queriedOrder.vlocity_cmt__DefaultBillingAccountId__c;
orden.vlocity_cmt__DefaultServiceAccountId__c = newService.Id;
orden.vlocity_cmt__OriginatingChannel__c = canal;
orden.TMX_VNT_IdDomicilio__c = queriedOrder.TMX_VNT_IdDomicilio__c; 
orden.TMX_VNT_iDSpwA__c = iDSpwA;
orden.TMX_VNT_Numero_interior__c = cuenta.TMX_VNT_Numero_interior__c;
orden.TMX_VNT_Edificio__c = cuenta.TMX_VNT_Edificio__c;
orden.TMX_VNT_ProductoTelmex__c = 'PFR26';
orden.TMX_VNT_Item__c = 'IFR05';
orden.TMX_VNT_Modem__c = 'PFM15';
orden.RecordTypeId = queriedOrder.RecordTypeId;
insert orden;

TMX_VNT_Agendamiento__c agendamiento = new TMX_VNT_Agendamiento__c();
agendamiento.Name = 'Agendamiento - '+orden.Id;
agendamiento.TMX_VNT_FechaInstalacion__c = Datetime.now().addDays(2);
agendamiento.TMX_VNT_RangoHorario__c = 'Matutino';
agendamiento.TMX_VNT_EstadoAgendamiento__c = 'Confirmada';
agendamiento.TMX_VNT_OrderId__c = orden.Id;
agendamiento.TMX_VNT_IdAgenda__c = '123456';
insert agendamiento;