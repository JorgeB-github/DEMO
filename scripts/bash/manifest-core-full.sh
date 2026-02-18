#!/bin/bash

# @description       : 
#  Script para generar un manifiesto XML completo basado en todos los elementos
#  en la carpeta force-app actual. No requiere comparación entre ramas.
#  Utiliza el comando sf project generate manifest para crear un manifiesto XML
#  que incluye todos los componentes de metadatos existentes.
# 
#  Uso:
# 1. Abre un terminal y navega al directorio donde guardaste el archivo (carpeta raíz de git).
# 2. Ejecuta el siguiente comando para hacerlo ejecutable en tu máquina:
#      chmod +x scripts/bash/generate-manifest-full-core.sh
# 3. Ahora puedes ejecutar el script usando:
#      ./scripts/bash/generate-manifest-full-core.sh
# 
# El manifiesto resultante tendrá un nombre basado en la fecha y hora actuales,
# guardado en el directorio actual.
# 
# @author            : fernanda.barbosa@salesforce.com
# @last modified on  : 12-03-2025
# @last modified by  : fernanda.barbosa@salesforce.com

# Ruta base para los archivos de metadatos
BASE_PATH="force-app"

# Verifica si la carpeta force-app existe
if [ ! -d "$BASE_PATH" ]; then
  echo "Error: La carpeta $BASE_PATH no existe."
  exit 1
fi

# Generar nombre del manifiesto con la fecha y hora actual
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M")
NEW_MANIFEST="package_full_$TIMESTAMP.xml"

echo "Verificando la estructura de la carpeta $BASE_PATH..."

# Verifica si hay archivos de metadatos en la carpeta
if [ -z "$(find "$BASE_PATH" -type f | head -1)" ]; then
  echo "No se encontraron archivos en la carpeta $BASE_PATH."
  exit 0
fi

# Genera el manifiesto directamente desde la carpeta force-app
echo "Generando manifiesto XML completo..."
sf project generate manifest --source-dir "$BASE_PATH" --output-dir "." --name "$NEW_MANIFEST"

# Verifica si el comando se ejecutó correctamente
if [ $? -eq 0 ]; then
  # Cuenta los componentes en el manifiesto generado
  COMPONENT_COUNT=$(grep -c "<members>" "$NEW_MANIFEST" 2>/dev/null || echo "desconocido")
  echo "Manifiesto completo generado en: $NEW_MANIFEST"
  echo "El manifiesto contiene aproximadamente $COMPONENT_COUNT componentes."
else
  echo "Error al generar el manifiesto."
  exit 1
fi
