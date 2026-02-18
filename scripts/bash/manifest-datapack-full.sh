#!/bin/bash

# @description       : 
#  Script para generar un manifiesto YAML completo basado en todos los elementos
#  en la carpeta dataPack actual. No requiere comparación entre ramas.
#  Uso:
# 1. Abre un terminal y navega al directorio donde guardaste el archivo (carpeta raíz de git)
# 2. Ejecuta el siguiente comando para hacerlo ejecutable en su maquina:
#      chmod +x scripts/bash/manifest-datapack-full.sh
# 3. Ahora puedes ejecutar el script usando:
#      ./scripts/bash/manifest-datapack-full.sh
# 
# El manifiesto resultante tendrá un nombre basado en la fecha y hora actuales.
# 
# @author            : fernanda.barbosa@salesforce.com
# @last modified on  : 12-03-2025
# @last modified by  : fernanda.barbosa@salesforce.com

# Ruta base para los archivos de metadatos
BASE_PATH="dataPack"

# Verifica si la carpeta dataPack existe
if [ ! -d "$BASE_PATH" ]; then
  echo "Error: La carpeta $BASE_PATH no existe."
  exit 1
fi

# Generar nombre del manifiesto con la fecha y hora actual
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M")
NEW_MANIFEST="datapack_full_$TIMESTAMP.yaml"

echo "Buscando todos los metadatos en la carpeta $BASE_PATH..."

# Encuentra todos los subdirectorios que están exactamente 2 niveles por debajo de BASE_PATH
# Esto asume que la estructura es dataPack/tipo/ID
METADATA_IDS=$(find "$BASE_PATH" -mindepth 2 -maxdepth 2 -type d | sed "s|$BASE_PATH/||g")

# Si no se encuentran IDs válidos, finalizar
if [ -z "$METADATA_IDS" ]; then
  echo "No se encontraron IDs de metadatos válidos en la carpeta $BASE_PATH."
  exit 0
fi

# Generar el nuevo manifiesto con configuración completa
echo "Generando manifiesto completo..."
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
  echo "    Product2:"
  echo "      MaxDeploy: 1"
  echo "  SObjects:"
  echo "    vlocity_namespace__PromotionItem__c:"
  echo "      SourceKeyDefinition:"
  echo "        - vlocity_namespace__ProductId__c"
  echo "        - vlocity_namespace__PromotionId__c"
  echo "        - vlocity_namespace__OfferId__c"
} >> "$NEW_MANIFEST"

echo "Manifiesto completo generado en: $NEW_MANIFEST"
echo "Contiene $(wc -l < <(echo "$METADATA_IDS")) elementos."
