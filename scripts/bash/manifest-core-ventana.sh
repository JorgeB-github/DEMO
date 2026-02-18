#!/bin/bash

# @description       : 
#  Script para generar un manifiesto XML completo basado en todos los elementos
#  en la carpeta force-app actual excluye los tipos de metadatos especificados 
#  del manifiesto final. No requiere comparación entre ramas.
#  Utiliza el comando sf project generate manifest para crear un manifiesto XML
#  que incluye todos los componentes de metadatos existentes.
#  
# 
# 
#  Uso:
# 1. Abre un terminal y navega al directorio donde guardaste el archivo (carpeta raíz de git).
# 2. Ejecuta el siguiente comando para hacerlo ejecutable en tu máquina:
#      chmod +x scripts/bash/manifest-core-ventana.sh
# 3. Ahora puedes ejecutar el script usando:
#      ./scripts/bash/manifest-core-ventana.sh
# 
# El manifiesto resultante tendrá un nombre basado en la fecha y hora actuales,
# guardado en el directorio actual.
# 
# @author            : fernanda.barbosa@salesforce.com
# @last modified on  : 14-04-2025
# @last modified by  : fernanda.barbosa@salesforce.com

# Ruta base para los archivos de metadatos
BASE_PATH="force-app"

# Verificar si la carpeta force-app existe
if [ ! -d "$BASE_PATH" ]; then
  echo "Error: La carpeta $BASE_PATH no existe."
  exit 1
fi

# Generar nombre del manifiesto con la fecha y hora actual
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M")
TEMP_MANIFEST="temp_manifest_$TIMESTAMP.xml"
NEW_MANIFEST="package_ventana_$TIMESTAMP.xml"

# Verificar estructura de la carpeta
echo "Verificando la estructura de la carpeta $BASE_PATH..."
if [ -z "$(find "$BASE_PATH" -type f | head -1)" ]; then
  echo "No se encontraron archivos en la carpeta $BASE_PATH."
  exit 0
fi

# Generar el manifiesto completo
echo "Generando manifiesto XML completo..."
sf project generate manifest --source-dir "$BASE_PATH" --output-dir "." --name "$TEMP_MANIFEST"

# Verificar si el comando se ejecutó correctamente
if [ $? -ne 0 ]; then
  echo "Error al generar el manifiesto."
  exit 1
fi

echo "Filtrando tipos de metadatos no deseados..."

# Comprobar si perl está instalado
if ! command -v perl &> /dev/null; then
  echo "Error: Este script requiere Perl para procesar el XML."
  exit 1
fi

# Lista de tipos de metadatos a excluir
TYPES_TO_EXCLUDE="AuthProvider DecisionMatrixDefinition DecisionMatrixDefinitionVersion EmailTemplate EntitlementProcess ExpressionSetDefinition ExpressionSetDefinitionVersion NamedCredential CustomLabel CustomLabels CustomMetadata"

# Crear script de perl temporal para filtrar el XML
PERL_SCRIPT=$(cat <<'EOF'
#!/usr/bin/perl
use strict;
use warnings;

# Leer los tipos a excluir de los argumentos
my @exclude_types = split(/\s+/, $ARGV[1]);
my $in_file = $ARGV[0];
my $out_file = $ARGV[2];

# Leer todo el contenido del archivo
open my $in_fh, '<', $in_file or die "No se puede abrir $in_file: $!";
my $content = do { local $/; <$in_fh> };
close $in_fh;

# Variables para el procesamiento
my $in_types = 0;
my $current_block = '';
my $skip_block = 0;
my $result = '';
my $count_excluded = 0;

# Dividir el contenido en líneas
my @lines = split(/\n/, $content);

# Primera pasada: identificar la cabecera XML
my $header = '';
foreach my $line (@lines) {
    if ($line =~ /<\?xml/ || $line =~ /<Package/) {
        $header .= $line . "\n";
    } else {
        last;
    }
}

# Segunda pasada: procesar los bloques <types>
my $current_type = '';
my @blocks;
my @excluded_blocks;

for (my $i = 0; $i < @lines; $i++) {
    my $line = $lines[$i];
    
    # Ignorar las líneas de cabecera ya procesadas
    next if $line =~ /<\?xml/ || $line =~ /<Package/;
    
    # Final del archivo
    if ($line =~ /<\/Package>/) {
        next;
    }
    
    # Inicio de un bloque <types>
    if ($line =~ /<types>/) {
        $in_types = 1;
        $current_block = $line . "\n";
        $skip_block = 0;
        $current_type = '';
        next;
    }
    
    # Final de un bloque </types>
    if ($in_types && $line =~ /<\/types>/) {
        $current_block .= $line . "\n";
        
        if (!$skip_block) {
            push @blocks, $current_block;
        } else {
            push @excluded_blocks, $current_type;
            $count_excluded++;
        }
        
        $in_types = 0;
        $current_block = '';
        next;
    }
    
    # Dentro de un bloque <types>
    if ($in_types) {
        $current_block .= $line . "\n";
        
        # Si encontramos un nombre de tipo
        if ($line =~ /<name>(.*?)<\/name>/) {
            $current_type = $1;
            foreach my $type (@exclude_types) {
                if ($current_type eq $type) {
                    $skip_block = 1;
                    last;
                }
            }
        }
    }
}

# Escribir el resultado
open my $out_fh, '>', $out_file or die "No se puede escribir $out_file: $!";

# Escribir la cabecera
print $out_fh $header;

# Escribir todos los bloques no excluidos
foreach my $block (@blocks) {
    print $out_fh $block;
}

# Cerrar el archivo XML
print $out_fh "</Package>\n";
close $out_fh;

# Imprimir información
print "Tipos excluidos ($count_excluded): " . join(", ", @excluded_blocks) . "\n";
print "Tipos incluidos: " . scalar(@blocks) . "\n";
EOF
)

# Escribir el script de perl en un archivo temporal
PERL_FILE=$(mktemp)
echo "$PERL_SCRIPT" > "$PERL_FILE"
chmod +x "$PERL_FILE"

# Ejecutar el script perl para filtrar el XML
perl "$PERL_FILE" "$TEMP_MANIFEST" "$TYPES_TO_EXCLUDE" "$NEW_MANIFEST"

# Verificar si el script de perl se ejecutó correctamente
if [ $? -ne 0 ]; then
  echo "Error al procesar el XML con Perl."
  exit 1
fi

# Limpiar archivos temporales
rm -f "$TEMP_MANIFEST" "$PERL_FILE"

# Contar componentes en el manifiesto filtrado
COMPONENT_COUNT=$(grep -c "<members>" "$NEW_MANIFEST" 2>/dev/null || echo "0")

echo "Manifiesto filtrado generado con éxito en: $NEW_MANIFEST"
echo "El manifiesto contiene aproximadamente $COMPONENT_COUNT componentes."
