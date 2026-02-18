/**
 * @description       : 
 * @author            : rosa.alayon@nespon.com
 * @group             : 
 * @last modified on  : 31-03-2025
 * @last modified by  : rosa.alayon@nespon.com
**/

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
 * 3. Asegurarse tenga los permisos necesarios para crear registros de tipo Account, Contact y Order
 * 4. Actualizar los valores de las variables del primer bloque de codigo
 */

 //SCRIPT

/** CAMBIAR SIEMPRE ESTOS DATOS PARA EVITAR LA DUPLICIDAD 
*/
String nombre = 'Patroclo';
String apellidoP = 'Menecio';
String apellidoM = 'Homero';
String tipoDocumento = 'INE';
String numeroDocumento = '1357901117811';
String correo = 'patroclo.telmex@yopmail.com';
String telefono = '526241430901';
Double telefonoAdicional = Double.valueOf('524499787200');
String movil = '9999262111';

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

/** CONFIGURAR DOMICILIO:
* Solo si es necesario, ajustar los valores de acuerdo a la direccion que se desea crear:
*/
String codigoPostal = '32390';
String codigoPostalFiscal = '06500';
Double latitud = 31.71232402776295;
Double longitud = -106.44018149030119;
String estado = 'Chihuahua';
String codEstado = 'CHH';
String municipio = 'Juarez';
String ciudad = 'Juarez';
String colonia = 'San José';
String calle = 'Avenida Ejército Nacional';
String tipoCalle = 'CALLE';
String numeroExterior = '5562';
String numeroInterior = '';
String lote = '';
String manzana = '';
String calificador = '';
String subnumero = '';
String edificio = '';
String domicilio1 = '';
String domicilio2 = '';
String domicilio3 = '';
String entreCalle1 = 'Del Jaral';
String entreCalle2 = 'Av. Plutarco Elías Calles';
String referencias = '';
String pais = 'México';
String idDomicilio = '21553';

Pricebook2 pricebook = [SELECT Id, Name FROM Pricebook2 WHERE Name = 'Standard Price Book' LIMIT 1];

List<RecordType> recordTypes = [SELECT Id, DeveloperName 
    FROM RecordType 
    WHERE SObjectType IN ('Account', 'Order') 
    AND DeveloperName IN ('Consumer', 'Billing', 'Service', 'StandardOrder')
];

Map<String, Id> recordTypeMap = new Map<String, Id>();
for (RecordType rt : recordTypes) {
    recordTypeMap.put(rt.DeveloperName, rt.Id);
}

Account cuenta = new Account();
cuenta.Name = nombre + ' ' + apellidoP;
cuenta.TMX_VNT_Apellido_Paterno__c = apellidoP;
cuenta.TMX_VNT_Apellido_Materno__c = apellidoM;
cuenta.TMX_VNT_Calle__c = calle;
cuenta.TMX_VNT_Ciudad__c = ciudad;
cuenta.TMX_VNT_Colonia__c = colonia;
cuenta.TMX_VNT_Estado__c = estado;
cuenta.TMX_VNT_Municipio_Alcaldia__c = municipio;
cuenta.TMX_VNT_Numero_de_Exterior__c = numeroExterior;
cuenta.TMX_VNT_Numero_Documento__c = numeroDocumento;
cuenta.TMX_VNT_Tipo_de_Calle__c = tipoCalle;
cuenta.TMX_VNT_Tipo_de_Cliente__c = tipoCliente;
cuenta.BillingCity = ciudad;
cuenta.BillingCountry = pais;
cuenta.TMX_VNT_Ubicacion_Geografica__Latitude__s = latitud;
cuenta.TMX_VNT_Ubicacion_Geografica__Longitude__s = longitud;
cuenta.Phone = telefono;
cuenta.TMX_VNT_Tipo_de_alta__c = tipoAlta;
cuenta.vlocity_cmt__Active__c = 'Yes';
cuenta.vlocity_cmt__Status__c = 'Active';
cuenta.TMX_OM_CUC__c = 'E052830412';
cuenta.TMX_VNT_Numero_interior__c = numeroInterior;
cuenta.TMX_VNT_Lote__c = lote;
cuenta.TMX_VNT_Manzana__c = manzana;
cuenta.TMX_VNT_Entre_Calle_1__c = entreCalle1;
cuenta.TMX_VNT_Entre_Calle_2__c = entreCalle2;
cuenta.TMX_VNT_Referencias__c = referencias;
cuenta.TMX_VNT_CodigoEstado__c = codEstado;
cuenta.TMX_VNT_Calificador__c = calificador;
cuenta.TMX_VNT_Subnumero__c = subnumero;
cuenta.TMX_VNT_Edificio__c = edificio;
cuenta.RecordTypeId = recordTypeMap.get('Consumer');
cuenta.IsActive = true;
insert cuenta;

Account accBilling = new Account();
accBilling.Name = 'PUBLICO EN GENERAL';
accBilling.ParentId = cuenta.Id;
accBilling.TMX_VNT_Billing_Account__c = cuenta.Id;
accBilling.TMX_VNT_Calle__c = calle;
accBilling.TMX_VNT_Ciudad__c = ciudad;
accBilling.TMX_VNT_Codigo_Postal_fiscal__c = codigoPostalFiscal;
accBilling.TMX_VNT_Colonia__c = colonia;
accBilling.TMX_VNT_Estado__c = estado;
accBilling.TMX_VNT_Municipio_Alcaldia__c = municipio;
accBilling.TMX_VNT_NombreRazonSocial__c = 'PUBLICO EN GENERAL';
accBilling.TMX_VNT_Numero_de_Exterior__c = numeroExterior;
accBilling.TMX_VNT_Regimen_Fiscal__c = '616 - Sin obligaciones fiscales';
accBilling.TMX_VNT_RFC__c = 'XAXX010101000';
accBilling.TMX_VNT_RFC_Estado_Validacion__c = 'Sin Validar';
accBilling.TMX_VNT_RFC_Fecha_Validacion__c = Date.today();
accBilling.TMX_VNT_Sin_RFC__c = true;
accBilling.TMX_VNT_Tipo_Persona__c = 'Persona Fisica';
accBilling.TMX_VNT_Uso_de_CDFI__c = 'S01 - SIN EFECTOS FISCALES';
accBilling.vlocity_cmt__IsRootResolved__c = true;
accBilling.vlocity_cmt__RootAccountId__c = cuenta.Id;
accBilling.TMX_VNT_Tipo_de_Cliente__c = tipoCliente;
accBilling.TMX_VNT_Domicilio_1__c = domicilio1;
accBilling.TMX_VNT_Domicilio_2__c = domicilio2;
accBilling.TMX_VNT_Domicilio_3__c = domicilio3;
accBilling.RecordTypeId = recordTypeMap.get('Billing');
accBilling.IsActive = true;
insert accBilling;

vlocity_cmt__Party__c party = new vlocity_cmt__Party__c();
party.Name = 'PUBLICO EN GENERAL';
party.vlocity_cmt__AccountId__c = accBilling.Id;
party.vlocity_cmt__PartyEntityType__c = 'Account';
insert party;

accBilling.vlocity_cmt__PartyId__c = party.Id;
update accBilling;

Account accService = new Account();
accService.Name = 'Domicilio Instalación ' + nombre + ' ' + apellidoP;
accService.ParentId = cuenta.Id;
accService.TMX_VNT_Billing_Account__c = accBilling.Id;
accService.TMX_VNT_Calle__c = calle;
accService.TMX_VNT_Ciudad__c = ciudad;
accService.TMX_VNT_Colonia__c = colonia;
accService.TMX_VNT_Estado__c = estado;
accService.TMX_VNT_Municipio_Alcaldia__c = municipio;
accService.TMX_VNT_Numero_de_Exterior__c = numeroExterior;
accService.TMX_VNT_Tipo_de_Calle__c = tipoCalle;
accService.TMX_VNT_Ubicacion_Geografica__Latitude__s = latitud;
accService.TMX_VNT_Ubicacion_Geografica__Longitude__s = longitud;
accService.vlocity_cmt__IsRootResolved__c = true;
accService.vlocity_cmt__RootAccountId__c = cuenta.Id;
accService.vlocity_cmt__Status__c = 'Active';
accService.TMX_VNT_Tipo_de_Cliente__c = tipoCliente;
accService.TMX_VNT_CodigoEstado__c = codEstado;
accService.TMX_VNT_IdDomicilio__c = idDomicilio;
accService.TMX_VNT_Numero_interior__c = numeroInterior;
accService.TMX_VNT_Lote__c = lote;
accService.TMX_VNT_Manzana__c = manzana;
accService.TMX_VNT_Entre_Calle_1__c = entreCalle1;
accService.TMX_VNT_Entre_Calle_2__c = entreCalle2;
accService.TMX_VNT_Referencias__c = referencias;
accService.TMX_VNT_Central__c = 'TA_';
accService.TMX_VNT_CoberturaCentral__c = 'TA_';
accService.TMX_VNT_Libreria__c = 'QAS';
accService.TMX_VNT_CoberturaDireccionRNUM__c = 'METRO - SUR';
accService.TMX_VNT_CoberturaDireccionTelmex__c = 'METRO - SUR';
accService.TMX_VNT_CoberturaSubdireccionRNUM__c = 'METRO SUR';
accService.TMX_VNT_CoberturaSubdireccionTelmex__c = 'METRO SUR';
accService.TMX_VNT_districFO__c = 'AA_0001FO';
accService.TMX_VNT_Equipo__c = '';
accService.TMX_VNT_Esquema_DDS__c = 'MEXV9';
accService.TMX_VNT_Esquema_DB2__c = 'MEXRDBV9';
accService.RecordTypeId = recordTypeMap.get('Service');
accService.IsActive = true;
insert accService;

Contact contacto = new Contact();
contacto.FirstName = nombre;
contacto.LastName = apellidoP;
contacto.AccountId = cuenta.Id;
contacto.Email = correo;
contacto.Phone = telefono;  
contacto.MailingCity = ciudad;
contacto.MailingCountry = pais;
contacto.MiddleName = apellidoM;
contacto.MobilePhone = movil;
contacto.TMX_VNT_Correo_electronico_confirmacion__c = correo;
contacto.TMX_VNT_Numero_de_Documento__c = numeroDocumento;
contacto.TMX_VNT_Tipo_Documento__c = tipoDocumento;
contacto.TMX_VNT_Telefono_Adicional__c = telefonoAdicional;
contacto.vlocity_cmt__ContactNumber__c = telefono;
insert contacto;

cuenta.vlocity_cmt__PrimaryContactId__c = contacto.Id;
update cuenta;

Order orden = new Order();
orden.AccountId = cuenta.Id;
orden.EffectiveDate = Date.today();
orden.Status = 'Draft';
orden.Pricebook2Id = pricebook.Id;
orden.TMX_VNT_Apellido_Materno__c = apellidoM;
orden.TMX_VNT_Apellido_Paterno__c = apellidoP;
orden.TMX_VNT_ApellidoMaternoTarjetahabiente__c = apellidoM;
orden.TMX_VNT_ApellidoPaternoTarjetahabiente__c = apellidoP;
orden.TMX_VNT_ApellidoTitularEntrega__c = apellidoP;
orden.TMX_VNT_Calle__c = calle.toUpperCase();
orden.TMX_VNT_CelularTarjetahabiente__c = movil;
orden.TMX_VNT_CelularTitularEntrega__c = movil;
orden.TMX_VNT_Codigo_Postal__c = codigoPostal;
orden.TMX_VNT_Colonia__c = colonia.toUpperCase();
orden.TMX_VNT_Correo_Contacto__c = correo;
orden.TMX_VNT_CorreoElectronicoTarjetahabiente__c = correo;
orden.TMX_VNT_CorreoTitularEntrega__c = correo;
orden.TMX_VNT_CreditoDisponible__c = 851;
orden.TMX_VNT_DeviceQuantity__c = '0-15';
orden.TMX_VNT_Domiciliacion__c = true;
orden.TMX_VNT_Domicilio_Facturacion_definido__c = true;
orden.TMX_VNT_DomicilioContacto__c = contacto.MailingCity+', '+contacto.MailingCountry;
orden.TMX_VNT_Ejecutivo_de_Venta__c = userInfo.getUserId();
orden.TMX_VNT_Estado__c =  estado.toUpperCase();
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
orden.TMX_VNT_Municipio_Alcaldia__c = municipio.toUpperCase();
orden.TMX_VNT_Nombre__c = nombre;
orden.TMX_VNT_NombreTarjetahabiente__c = nombre;
orden.TMX_VNT_NombreTitularEntrega__c = nombre;
orden.TMX_VNT_Numero_de_Exterior__c = numeroExterior;
orden.TMX_VNT_Numero_Telefonico__c = telefono;
orden.TMX_VNT_Order_Stage__c = 'Validación del Cliente';
orden.TMX_VNT_PrivacidadNumero__c  = 'PB';
orden.TMX_VNT_ReciboSinPapel__c = true;
orden.TMX_VNT_Tecnologia_Voz__c = 'VoIP';
orden.TMX_VNT_Telefono_Contacto__c = movil;
orden.TMX_VNT_Tipo_de_alta__c = tipoAlta;
orden.TMX_VNT_Tipo_de_Calle__c = tipoCalle;
orden.TMX_VNT_Tipo_de_cliente__c = tipoCliente;
orden.TMX_VNT_Tipo_de_facturacion__c = 'Electronica';
orden.TMX_VNT_TipoDomicilio__c = 'Domicilio existente';
orden.TMX_VNT_Ubicacion_Geografica__Latitude__s = latitud;
orden.TMX_VNT_Ubicacion_Geografica__Longitude__s = longitud;
orden.vlocity_cmt__DefaultBillingAccountId__c = accBilling.Id;
orden.vlocity_cmt__DefaultServiceAccountId__c = accService.Id;
orden.vlocity_cmt__OriginatingChannel__c = canal;
orden.TMX_VNT_IdDomicilio__c = idDomicilio;
orden.TMX_VNT_iDSpwA__c = iDSpwA;
orden.TMX_VNT_Numero_interior__c = numeroInterior;
orden.TMX_VNT_Edificio__c = edificio;
orden.TMX_VNT_ProductoTelmex__c = 'PFR26';
orden.TMX_VNT_Item__c = 'IFR05';
orden.TMX_VNT_Modem__c = 'PFM15';
orden.TMX_VNT_SiglaCope__c = 'CTLE_';
orden.RecordTypeId = recordTypeMap.get('StandardOrder');
insert orden;

TMX_VNT_Agendamiento__c agendamiento = new TMX_VNT_Agendamiento__c();
agendamiento.Name = 'Agendamiento - '+orden.Id;
agendamiento.TMX_VNT_FechaInstalacion__c = Datetime.now().addDays(2);
agendamiento.TMX_VNT_RangoHorario__c = 'Matutino';
agendamiento.TMX_VNT_EstadoAgendamiento__c = 'Confirmada';
agendamiento.TMX_VNT_OrderId__c = orden.Id;
agendamiento.TMX_VNT_IdAgenda__c = '123456';
insert agendamiento;