#!/bin/bash

# @description       : 
#  Script para generar un manifiesto XML basado en los cambios entre dos ramas de Git.
#  Copia los archivos modificados a un directorio temporal y utiliza el comando
#  sf project generate manifest para crear un manifiesto XML que refleja los cambios.
# 
#  Uso:
# 1. Abre un terminal y navega al directorio donde guardaste el archivo (carpeta raíz de git).
# 2. Ejecuta el siguiente comando para hacerlo ejecutable en tu máquina:
#      chmod +x scripts/bash/generate-manifest-diff-core.sh
# 3. Ahora puedes ejecutar el script usando:
#      ./scripts/bash/generate-manifest-diff-core.sh <rama_antigua> <rama_nueva>
# 
# Ejemplo:
# ./scripts/bash/generate-manifest-diff-core.sh develop feature_branch
# 
# El manifiesto resultante tendrá un nombre basado en la fecha y hora actuales,
# guardado en el directorio actual.
# 
# @author            : fernanda.barbosa@salesforce.com
# @last modified on  : 01-07-2025
# @last modified by  : fernanda.barbosa@salesforce.com


# Define las ramas para la comparación
BRANCH_OLD=$1
BRANCH_NEW=$2

# Ruta base para los archivos de metadatos
BASE_PATH="force-app"

# Generar nombre del manifiesto y temporal con la fecha y hora actual
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M")
NEW_MANIFEST="package_$TIMESTAMP.yaml"
TEMP_DIR="temp_force_app_$TIMESTAMP"
TEMP_DIFF_FILE="temp_diff_$TIMESTAMP.txt"

# Verifica si se han proporcionado las ramas
if [ -z "$BRANCH_OLD" ] || [ -z "$BRANCH_NEW" ]; then
  echo "Uso: $0 <rama_antigua> <rama_nueva>"
  exit 1
fi

# Cambia a la rama antigua y compara con la nueva
echo "Comparando cambios con la rama nueva ($BRANCH_NEW)..."
echo "Generando archivo temporal con las diferencias..."
git diff --name-only "$BRANCH_OLD" "$BRANCH_NEW" | grep "^$BASE_PATH/" > "$TEMP_DIFF_FILE"


# Verificar si el archivo temporal tiene contenido
if [ ! -s "$TEMP_DIFF_FILE" ]; then
  echo "No se detectaron cambios en la ruta base $BASE_PATH."
  rm -f "$TEMP_DIFF_FILE"
  exit 0
fi

# Crea el directorio temporal para los archivos modificados
echo "Creando directorio temporal para los cambios: $TEMP_DIR"
rm -rf "$TEMP_DIR"  # Elimina cualquier residuo de ejecuciones anteriores
mkdir -p "$TEMP_DIR"

# Copia los archivos modificados al directorio temporal
while IFS= read -r FILE; do
  DEST_FILE="$TEMP_DIR/${FILE#$BASE_PATH/}"  # Elimina el prefijo force-app/
  mkdir -p "$(dirname "$DEST_FILE")"        # Crea los directorios necesarios
  cp "$FILE" "$DEST_FILE"
done < "$TEMP_DIFF_FILE"

# Verifica si el directorio temporal contiene archivos
if [ -z "$(ls -A "$TEMP_DIR")" ]; then
  echo "No se encontraron cambios en la ruta base $BASE_PATH."
  rm -rf "$TEMP_DIR"
  exit 0
fi

# Genera el manifiesto basado en el directorio temporal
echo "Generando manifiesto XML basado en los cambios..."
sf project generate manifest --source-dir "$TEMP_DIR" --name "$NEW_MANIFEST"

# Limpia temporal
rm -rf "$TEMP_DIR"
rm -f "$TEMP_DIFF_FILE"

# Mensaje de éxito
if [ $? -eq 0 ]; then
  echo "Manifiesto generado con éxito: $NEW_MANIFEST"
else
  echo "Error al generar el manifiesto."
  exit 1
fi
