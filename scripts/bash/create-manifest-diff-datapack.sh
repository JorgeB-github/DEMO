#!/bin/bash

# @description       : 
#  Script para generar un manifiesto YAML basado en los cambios entre dos ramas de Git.
#  Extrae los IDs de metadatos de los archivos modificados y los agrega al manifiesto.
#  Uso:
# 1. Abre un terminal y navega al directorio donde guardaste el archivo (carpeta raíz de git)
# 2. Ejecuta el siguiente comando para hacerlo ejecutable en su maquina:
#      chmod +x scripts/bash/create-manifest-diff-datapack.sh
# 3. Ahora puedes ejecutar el script usando:
#      ./scripts/bash/create-manifest-diff-datapack.sh <rama_antigua> <rama_nueva>
# 
# Ejemplo:
# ./scripts/bash/create-manifest-diff-datapack.sh main feature_branch
# 
# El manifiesto resultante tendrá un nombre basado en la fecha y hora actuales.
# 
# @author            : fernanda.barbosa@salesforce.com
# @last modified on  : 01-03-2025
# @last modified by  : fernanda.barbosa@salesforce.com

# Define las ramas para la comparación
BRANCH_OLD=$1
BRANCH_NEW=$2

# Ruta base para los archivos de metadatos
BASE_PATH="dataPack"

# Generar nombre del manifiesto con la fecha y hora actual
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M")
NEW_MANIFEST="datapack_$TIMESTAMP.yaml"

# Verifica si se han proporcionado las ramas
if [ -z "$BRANCH_OLD" ] || [ -z "$BRANCH_NEW" ]; then
  echo "Uso: $0 <rama_antigua> <rama_nueva>"
  exit 1
fi

# Cambia a la rama antigua y compara con la nueva
echo "Cambiando a la rama antigua ($BRANCH_OLD)..."
echo "Comparando cambios con la rama nueva ($BRANCH_NEW)..."
echo " "
MODIFIED_FILES=$(git diff --name-only "$BRANCH_OLD" "$BRANCH_NEW")

# Si no hay archivos modificados, finalizar
if [ -z "$MODIFIED_FILES" ]; then
  echo "No se detectaron cambios en los metadatos."
  exit 0
fi

# Extraer los IDs de metadatos basados en la estructura de las rutas
echo "Extrayendo IDs de metadatos de los archivos modificados..."
METADATA_IDS=$(echo "$MODIFIED_FILES" | grep "$BASE_PATH" | awk -F"$BASE_PATH/" '{print $2}' | cut -d'/' -f1-2)

# Si no se encuentran IDs válidos, finalizar
if [ -z "$METADATA_IDS" ]; then
  echo "No se encontraron IDs de metadatos válidos en los archivos modificados."
  exit 0
fi

# Remover duplicados
UNIQUE_METADATA_IDS=$(echo "$METADATA_IDS" | sort | uniq)

# Generar el nuevo manifiesto
echo "Generando nuevo manifiesto con metadatos alterados..."
{
  echo "projectPath: ./dataPack"
  echo "maxDepth: -1"
  echo "manifest:"
} > "$NEW_MANIFEST"

# Añadir cada ID único al manifiesto sin espacio antes del guión
while IFS= read -r ID; do
  echo "- $ID" >> "$NEW_MANIFEST"
done <<< "$UNIQUE_METADATA_IDS"

echo " "
echo "Nuevo manifiesto generado en: $NEW_MANIFEST"
