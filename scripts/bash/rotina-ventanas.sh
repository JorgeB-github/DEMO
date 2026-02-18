#!/bin/bash

# @description       : 
#  Script para automatizar el proceso de preparación para despliegue:
#  - Cambiar a la rama release-1
#  - Generar ramas para ventana de despliegue
#  - Generar manifiestos necesarios (core, datapack, omniscript, flexcards)
# 
# @author            : fernanda.barbosa@salesforce.com
# @last modified on  : 14-04-2025
# @last modified by  : fernanda.barbosa@salesforce.com

# Colores para los mensajes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para mostrar mensajes de progreso
show_status() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

# Función para mostrar mensajes de éxito
show_success() {
  echo -e "${GREEN}[ÉXITO]${NC} $1"
}

# Función para mostrar mensajes de advertencia
show_warning() {
  echo -e "${YELLOW}[ADVERTENCIA]${NC} $1"
}

# Función para mostrar mensajes de error
show_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Función para ejecutar un script con manejo de errores
run_script() {
  local script_path=$1
  local script_description=$2
  
  show_status "Ejecutando: $script_description"
  
  # Verificar si el script existe
  if [ ! -f "$script_path" ]; then
    show_error "No se encontró el script: $script_path"
    return 1
  fi
  
  # Hacer el script ejecutable
  chmod +x "$script_path"
  
  # Ejecutar el script
  "$script_path"
  
  # Verificar el resultado
  if [ $? -eq 0 ]; then
    show_success "Completado: $script_description"
    return 0
  else
    show_error "Falló la ejecución de: $script_description"
    return 1
  fi
}

# Banner de inicio
echo -e "\n${BLUE}=======================================================${NC}"
echo -e "${BLUE}  PREPARACIÓN AUTOMÁTICA PARA VENTANA DE DESPLIEGUE    ${NC}"
echo -e "${BLUE}=======================================================${NC}\n"

# Mostrar información inicial
show_status "Iniciando proceso de preparación para ventana de despliegue"
show_status "Fecha y hora: $(date)"
echo

# Paso 1: Cambiar a la rama release-1
show_status "Cambiando a la rama release-1..."
if git checkout release-1; then
  show_success "Ahora estás en la rama release-1"
else
  show_error "No se pudo cambiar a la rama release-1. Abortando."
  exit 1
fi
echo

# Paso 2: Generar rama para ventana de despliegue
show_status "Generando rama para ventana de despliegue..."
if run_script "scripts/bash/branch-ventana.sh" "Generación de rama"; then
  BRANCH_NAME=$(git branch --show-current)
  show_success "Rama creada: $BRANCH_NAME"
else
  show_warning "Continuando con el proceso a pesar del error"
fi
echo

# Paso 3: Generar manifiestos
show_status "Generando manifiestos necesarios..."

# Generar manifiesto core
run_script "scripts/bash/manifest-core-ventana.sh" "Manifiesto Core"

# Generar manifiesto datapack
run_script "scripts/bash/manifest-datapack-ventana.sh" "Manifiesto DataPack"

# Generar manifiesto omniscript
run_script "scripts/bash/manifest-omniscript.sh" "Manifiesto OmniScript"

# Generar manifiesto flexcards
run_script "scripts/bash/manifest-flexcards.sh" "Manifiesto FlexCards"

echo

# Mostrar recordatorio importante
echo -e "${YELLOW}=======================================================${NC}"
echo -e "${YELLOW}  RECORDATORIO IMPORTANTE                             ${NC}"
echo -e "${YELLOW}=======================================================${NC}"
echo -e "${YELLOW}Revisar si hay nuevos contenidos de:${NC}"
echo -e " - Custom Metadata"
echo -e " - Named Credential"
echo -e " - Decision Matrices"
echo -e " - Expression Sets"
echo -e " - Authentication Providers"
echo -e "${YELLOW}Si hay cambios en estos componentes, evaluar si deben incluirse${NC}"
echo -e "${YELLOW}en el despliegue manualmente.${NC}"

# Resumen final
echo -e "\n${GREEN}=======================================================${NC}"
echo -e "${GREEN}  PROCESO COMPLETADO                                  ${NC}"
echo -e "${GREEN}=======================================================${NC}"
echo -e "Los siguientes archivos fueron generados:"
echo -e " - Manifiesto Core (package_*.xml)"
echo -e " - Manifiesto DataPack (datapack_*.yaml)"
echo -e " - Manifiesto OmniScript (omniscript_*.yaml)"
echo -e " - Manifiesto FlexCards (flexcards_*.yaml)"
echo -e "\nVerifique los manifiestos generados antes de continuar con el despliegue."
echo -e "Fecha y hora de finalización: $(date)"
