
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
      "preDestructiveChanges": "manifest/preDestructive/destructiveChanges.xml",
      "postDestructiveChanges": "manifest/postDestructive/destructiveChanges.xml",
      "timeout": "33",
      "ignoreWarnings": true,
      "disableTracking": true,
      "outputFormat": "json"
    },
    {
      "type": "datapack",
      "manifestFile": "manifest/sfi-package.yaml"
    },
    {
      "type": "anonymousApex",
      "apexScript": "scripts/apex/hello.apex"
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
