
### Estructura del Archivo Buildfile:
El Buildfile está organizado en formato JSON y contiene una lista de tareas en el nodo builds. Cada tarea incluye detalles sobre el tipo de acción que se debe realizar y parámetros específicos para su ejecución.

```
{
  "builds": [
    {
      "type": "metadata",
      "manifestFile": "manifest/package.xml",
      "testLevel": "RunSpecifiedTests",
      "classPath": "force-app/main/default/classes",
      "timeout": "33",
      "ignoreWarnings": true,
      "disableTracking": true,
      "outputFormat": "json"
    },
    {
      "type": "anonymousApex",
      "apexScript": "scripts/apex/hello.apex"
    },
    {
      "type": "datapack",
      "manifestFile": "manifest/sfi-package.yaml"
    },
    {
      "type": "command",
      "command": "vlocity --nojob installVlocityInitial",
      "includeTargetOrg": true,
      "targetOrgFormat": "-sfdx.username"
    }
  ]
}
```
