
### ✅ Lista rápida antes de enviar el PR (Salesforce)
- [ ] Apex Code, LWC o Flows revisados y formateados correctamente.
- [ ] Todas las pruebas automáticas deben pasar localmente y en el sandbox de desarrollo.
- [ ] Cobertura de código mínima requerida (ej: 75%) alcanzada.
- [ ] Metadatos validados.
- [ ] Documentación actualizada (README, Wiki, Confluence, etc.), si aplica.
- [ ] No incluir credenciales, tokens o datos sensibles en el código o en los `*.xml`.
- [ ] Verificar que no se modifican perfiles/permission sets fuera del alcance del PR.
- [ ] Cambios probados en sandbox y validados por DEVs/QAs, segun corresponda.
- [ ] Revisión de accesibilidad en el LWC si hay cambios en la UI.
- [ ] Se incluyeron traducciones de *labels* y *custom metadata*, si aplica.
- [ ] Se actualizó el `package.xml` o `package-sfi.yaml` en caso de ser necesario para el despliegue.
- [ ] Revisar que la rama este bien nombrada segun el tipo de cambio: Nueva feature, Refactorización, Arreglo de fallo, DevOps o Pruebas.

----

## Descripción de la funcionalidad
Describe de forma clara y concisa la funcionalidad.

## Análisis y diseño
Analiza y adjunta la documentación de diseño.

## Descripción de la solución
Describe en detalle tus cambios de código para los revisores.

## Capturas de pantalla de salida
Publica las capturas de pantalla de la salida, si una interfaz de usuario se ve afectada o se añade debido a esta funcionalidad.

## Áreas afectadas y verificadas
Enumera las áreas afectadas por tus cambios de código.

## ¿Hay algún cambio de comportamiento existente de otras funcionalidades debido a este cambio de código?
Menciona Sí o No. Si es Sí, proporciona la explicación correspondiente.

## Casos de prueba unitarios cubiertos / casos de prueba E2E
¿Hay casos de prueba unitarios o E2E registrados para esta funcionalidad?

## ¿Se probó esta funcionalidad en todos los navegadores?
- [x] Chrome
- [x] Firefox
