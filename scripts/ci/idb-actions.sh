#!/usr/bin/env bash
# Ejecuta una secuencia de acciones contra el simulador arrancado usando idb,
# dejando una captura DESPUES de cada accion.
#
# Uso: SIM_UDID=<udid> idb-actions.sh <archivo-de-acciones> [dir-salida]
#
# Acciones (una por linea, '#' comenta):
#   tap <marcador>                 toca el elemento con esa etiqueta de accesibilidad
#   tap <x> <y>                    toca coordenadas en puntos
#   text <cadena...>               escribe texto
#   setvalue <marcador> <valor>    fija el valor de un campo
#   swipe <x1> <y1> <x2> <y2>      desliza
#   button <HOME|LOCK|SIDE_BUTTON|SIRI|APPLE_PAY>
#   key <codigo>                   pulsa una tecla
#   describe                       vuelca el arbol de accesibilidad al log
#   sleep <segundos>
#   shot [nombre]                  captura extra sin accion
set -uo pipefail

ACCIONES="${1:?uso: idb-actions.sh <archivo-de-acciones> [dir-salida]}"
OUT="${2:-capturas}"
UDID="${SIM_UDID:-}"
mkdir -p "$OUT"

# idb necesita saber el objetivo: sin --udid ni companion da
# "No udid provided and there no companions, unclear which target to run against".
IDB_ARGS=()
if [ -n "$UDID" ]; then
    IDB_ARGS=(--udid "$UDID")
    echo "=== levantando idb_companion para $UDID ==="
    idb_companion --udid "$UDID" >/tmp/idb_companion.log 2>&1 &
    sleep 5
fi

idb_do() { idb "$@" "${IDB_ARGS[@]+"${IDB_ARGS[@]}"}"; }

PASO=0
FALLOS=0
capturar() {
    PASO=$((PASO + 1))
    local nombre
    nombre="$(printf '%02d' "$PASO")-${1:-paso}"
    if xcrun simctl io "${UDID:-booted}" screenshot "$OUT/$nombre.png" >/dev/null 2>&1; then
        echo "   [captura] $nombre.png"
    else
        echo "   [captura] FALLO $nombre"
    fi
}

echo "=== objetivo idb ==="
idb list-targets "${IDB_ARGS[@]+"${IDB_ARGS[@]}"}" 2>&1 | head -10 || true
echo "=== arbol de accesibilidad al arrancar (marcadores disponibles) ==="
idb_do ui describe-all 2>&1 | head -80 || echo "(describe-all no disponible)"
echo

while IFS= read -r linea || [ -n "$linea" ]; do
    linea="${linea%$'\r'}"
    [ -z "${linea//[[:space:]]/}" ] && continue
    case "$linea" in \#*) continue ;; esac

    cmd="${linea%% *}"
    resto="${linea#* }"
    [ "$resto" = "$linea" ] && resto=""

    echo ">> $linea"
    rc=0
    case "$cmd" in
        tap)
            if [[ "$resto" =~ ^[0-9]+[[:space:]]+[0-9]+$ ]]; then
                idb_do ui tap $resto || rc=$?
            else
                idb_do ui tap "$resto" || rc=$?
            fi
            ;;
        tapxy)    idb_do ui tap $resto || rc=$? ;;
        text)     idb_do ui text "$resto" || rc=$? ;;
        setvalue) idb_do ui set-value $resto || rc=$? ;;
        swipe)    idb_do ui swipe $resto || rc=$? ;;
        button)   idb_do ui button "$resto" || rc=$? ;;
        key)      idb_do ui key "$resto" || rc=$? ;;
        describe) idb_do ui describe-all 2>&1 | head -60 ;;
        sleep)    sleep "$resto" ;;
        shot)     capturar "${resto:-manual}"; continue ;;
        *)        echo "   accion desconocida: $cmd" ;;
    esac
    if [ "$rc" != 0 ]; then
        echo "   !! la accion fallo (rc=$rc)"
        FALLOS=$((FALLOS + 1))
    fi
    capturar "$cmd"
done < "$ACCIONES"

echo
echo "=== resultado: $PASO capturas, $FALLOS acciones fallidas ==="
ls -la "$OUT"
[ "$FALLOS" = 0 ] || exit 1
