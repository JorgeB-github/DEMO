#!/bin/bash

# @description       : 
#  Script para generar un manifiesto YAML específicamente para OmniScripts
#  en la carpeta dataPack actual. No requiere comparación entre ramas.
#  Uso:
# 1. Abre un terminal y navega al directorio donde guardaste el archivo (carpeta raíz de git)
# 2. Ejecuta el siguiente comando para hacerlo ejecutable en su máquina:
#      chmod +x scripts/bash/manifest-omniscript.sh
# 3. Ahora puedes ejecutar el script usando:
#      ./scripts/bash/manifest-omniscript.sh
# 
# El manifiesto resultante tendrá un nombre basado en la fecha y hora actuales.
# 
# @author            : fernanda.barbosa@salesforce.com
# @last modified on  : 14-04-2025
# @last modified by  : fernanda.barbosa@salesforce.com

# Ruta base para los archivos de metadatos
BASE_PATH="dataPack"
# Tipo específico que queremos incluir
INCLUDED_TYPE="OmniScript"

# Verifica si la carpeta dataPack existe
if [ ! -d "$BASE_PATH" ]; then
  echo "Error: La carpeta $BASE_PATH no existe."
  exit 1
fi

# Verifica si la subcarpeta OmniScript existe
if [ ! -d "$BASE_PATH/$INCLUDED_TYPE" ]; then
  echo "Error: La carpeta $BASE_PATH/$INCLUDED_TYPE no existe."
  exit 1
fi

# Generar nombre del manifiesto con la fecha y hora actual
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M")
NEW_MANIFEST="omniscript_$TIMESTAMP.yaml"

echo "Buscando OmniScripts en la carpeta $BASE_PATH/$INCLUDED_TYPE..."

# Encuentra todos los subdirectorios que están exactamente 1 nivel por debajo de BASE_PATH/OmniScript
# Esto asume que la estructura es dataPack/OmniScript/ID
METADATA_IDS=$(find "$BASE_PATH/$INCLUDED_TYPE" -mindepth 1 -maxdepth 1 -type d | sed "s|$BASE_PATH/||g")

# Si no se encuentran IDs válidos, finalizar
if [ -z "$METADATA_IDS" ]; then
  echo "No se encontraron OmniScripts en la carpeta $BASE_PATH/$INCLUDED_TYPE."
  exit 0
fi

# Generar el nuevo manifiesto con configuración completa
echo "Generando manifiesto para OmniScripts..."
{
  echo "projectPath: ./dataPack"
  echo "continueAfterError: true"
  echo "autoUpdateSettings: true"
  echo "autoRetryErrors: true"
  echo "compileOnBuild: true"
  echo "npmAuthKey: Y3VzdG9tZXJfdGVsbWV4X2IyYzo3eF9Wa1ZpQU82SWppTjJY"
  echo "activate: true"
  echo "maxDepth: -1"
  echo "manifest:"
} > "$NEW_MANIFEST"

# Añadir cada ID al manifiesto sin espacio antes del guión
while IFS= read -r ID; do
  echo "- $ID" >> "$NEW_MANIFEST"
done <<< "$METADATA_IDS"

# Añadir configuración adicional al final del manifiesto
{
  echo "OverrideSettings:"
  echo "  DataPacks:"
  echo "    OmniScript:"
  echo "      MaxDeploy: 5"
} >> "$NEW_MANIFEST"

echo "Manifiesto de OmniScripts generado en: $NEW_MANIFEST"
echo "Contiene $(wc -l < <(echo "$METADATA_IDS")) OmniScripts."
