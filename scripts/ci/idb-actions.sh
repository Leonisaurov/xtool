#!/usr/bin/env bash
# Ejecuta una secuencia de acciones contra el simulador arrancado usando idb,
# dejando una captura DESPUES de cada accion.
#
# Uso: idb-actions.sh <archivo-de-acciones> [dir-salida]
#
# Acciones (una por linea, '#' comenta):
#   tap <marcador>                 toca el elemento con esa etiqueta de accesibilidad
#   tapxy <x> <y>                  toca coordenadas en puntos
#   text <cadena...>               escribe texto
#   setvalue <marcador> <valor>    fija el valor de un campo (ej. texto)
#   swipe <x1> <y1> <x2> <y2>      desliza
#   button <HOME|LOCK|SIDE_BUTTON|SIRI|APPLE_PAY>
#   key <codigo>                   pulsa una tecla
#   describe                       vuelca el arbol de accesibilidad al log
#   sleep <segundos>
#   shot [nombre]                  captura extra sin accion
set -uo pipefail

ACCIONES="${1:?uso: idb-actions.sh <archivo-de-acciones> [dir-salida]}"
OUT="${2:-capturas}"
UDID="${SIM_UDID:-booted}"
mkdir -p "$OUT"

PASO=0
capturar() {
    PASO=$((PASO + 1))
    local nombre
    nombre="$(printf '%02d' "$PASO")-${1:-paso}"
    if xcrun simctl io "$UDID" screenshot "$OUT/$nombre.png" >/dev/null 2>&1; then
        echo "   [captura] $nombre.png"
    else
        echo "   [captura] FALLO $nombre"
    fi
}

echo "=== arbol de accesibilidad al arrancar (marcadores disponibles) ==="
idb ui describe-all 2>&1 | head -80 || echo "(describe-all no disponible)"
echo

while IFS= read -r linea || [ -n "$linea" ]; do
    linea="${linea%$'\r'}"
    [ -z "${linea//[[:space:]]/}" ] && continue
    case "$linea" in \#*) continue ;; esac

    cmd="${linea%% *}"
    resto="${linea#* }"
    [ "$resto" = "$linea" ] && resto=""

    echo ">> $linea"
    case "$cmd" in
        tap)
            if [[ "$resto" =~ ^[0-9]+[[:space:]]+[0-9]+$ ]]; then
                idb ui tap $resto || echo "   (tap por coordenadas fallo)"
            else
                idb ui tap "$resto" || echo "   (tap por marcador '$resto' fallo)"
            fi
            ;;
        tapxy)    idb ui tap $resto || echo "   (tapxy fallo)" ;;
        text)     idb ui text "$resto" || echo "   (text fallo)" ;;
        setvalue) idb ui set-value $resto || echo "   (set-value fallo)" ;;
        swipe)    idb ui swipe $resto || echo "   (swipe fallo)" ;;
        button)   idb ui button "$resto" || echo "   (button fallo)" ;;
        key)      idb ui key "$resto" || echo "   (key fallo)" ;;
        describe) idb ui describe-all 2>&1 | head -60 ;;
        sleep)    sleep "$resto" ;;
        shot)     capturar "${resto:-manual}"; continue ;;
        *)        echo "   accion desconocida: $cmd" ;;
    esac
    capturar "$cmd"
done < "$ACCIONES"

echo
echo "=== capturas en $OUT ==="
ls -la "$OUT"
