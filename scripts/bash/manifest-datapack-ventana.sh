#!/bin/bash

# @description       : 
#  Script para generar un manifiesto YAML completo basado en todos los elementos
#  en la carpeta dataPack actual, excluyendo SObject_CustomFilter, Flexcards y OmniScript.
#  No requiere comparación entre ramas.
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
# @last modified on  : 14-04-2025
# @last modified by  : fernanda.barbosa@salesforce.com

# Ruta base para los archivos de metadatos
BASE_PATH="dataPack"

# Tipos de dataPack a excluir
EXCLUDED_TYPES=(
  "SObject_CustomFilter"
  "FlexCard"
  "OmniScript"
)

# Verifica si la carpeta dataPack existe
if [ ! -d "$BASE_PATH" ]; then
  echo "Error: La carpeta $BASE_PATH no existe."
  exit 1
fi

# Generar nombre del manifiesto con la fecha y hora actual
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M")
NEW_MANIFEST="datapack_ventana_$TIMESTAMP.yaml"

echo "Buscando todos los metadatos en la carpeta $BASE_PATH (excluyendo tipos específicos)..."

# Encuentra todos los subdirectorios que están exactamente 2 niveles por debajo de BASE_PATH
# y filtra los tipos excluidos
METADATA_IDS=$(find "$BASE_PATH" -mindepth 2 -maxdepth 2 -type d | sed "s|$BASE_PATH/||g")

# Filtrar los tipos excluidos
FILTERED_IDS=""
excluded_count=0
while IFS= read -r ID; do
  # Extraer el tipo (la primera parte antes del /)
  TYPE=$(echo "$ID" | cut -d '/' -f 1)
  
  # Verificar si el tipo está en la lista de excluidos
  exclude=0
  for excluded in "${EXCLUDED_TYPES[@]}"; do
    if [ "$TYPE" = "$excluded" ]; then
      exclude=1
      ((excluded_count++))
      break
    fi
  done
  
  # Añadir el ID a la lista filtrada si no está excluido
  if [ $exclude -eq 0 ]; then
    FILTERED_IDS+="$ID"$'\n'
  fi
done <<< "$METADATA_IDS"

# Eliminar la última línea en blanco
FILTERED_IDS=$(echo "$FILTERED_IDS" | sed '/^$/d')

# Si no se encuentran IDs válidos después del filtrado, finalizar
if [ -z "$FILTERED_IDS" ]; then
  echo "No se encontraron IDs de metadatos válidos en la carpeta $BASE_PATH después de aplicar los filtros."
  exit 0
fi

# Generar el nuevo manifiesto con configuración completa
echo "Generando manifiesto filtrado..."
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

# Añadir cada ID filtrado al manifiesto sin espacio antes del guión
while IFS= read -r ID; do
  echo "- $ID" >> "$NEW_MANIFEST"
done <<< "$FILTERED_IDS"

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

total_items=$(echo "$FILTERED_IDS" | wc -l)
echo "Manifiesto filtrado generado en: $NEW_MANIFEST"
echo "Se excluyeron $excluded_count elementos de tipo: ${EXCLUDED_TYPES[*]}"
echo "El manifiesto contiene $total_items elementos."
