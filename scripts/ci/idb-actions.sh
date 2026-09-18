#!/usr/bin/env bash
# Ejecuta una secuencia de acciones contra el simulador arrancado usando idb,
# dejando una captura DESPUES de cada accion.
#
# Uso: SIM_UDID=<udid> idb-actions.sh <archivo-de-acciones> [dir-salida]
#
# Acciones (una por linea, '#' comenta):
#   tap <patron>                   busca el elemento (AXLabel/AXValue/AXUniqueId) y toca su centro
#   tap <x> <y>                    toca coordenadas en puntos
#   text <cadena...>               escribe texto en el campo enfocado
#   setvalue <patron> <valor>      fija el valor de un elemento (slider, campo)
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

# idb necesita saber el objetivo: sin --udid ni companion responde
# "No udid provided and there no companions, unclear which target to run against".
IDB_ARGS=()
if [ -n "$UDID" ]; then
    IDB_ARGS=(--udid "$UDID")
    echo "=== levantando idb_companion para $UDID ==="
    idb_companion --udid "$UDID" >/tmp/idb_companion.log 2>&1 &
    sleep 5
fi

idb_do() { idb "$@" "${IDB_ARGS[@]+"${IDB_ARGS[@]}"}"; }

# Busca por patron en el arbol de accesibilidad y devuelve "x y" del centro.
# No usamos `idb ui tap <marcador>` porque solo compara AXLabel: los TextField
# exponen el texto en AXValue y los elementos con accessibilityIdentifier en
# AXUniqueId, y esos taps fallaban.
resolver_centro() {
    local patron="$1" json
    json=$(idb_do ui describe-all 2>/dev/null) || return 1
    printf '%s' "$json" | python3 -c '
import json, re, sys
raw = sys.stdin.read()
m = re.search(r"\[.*\]", raw, re.S)
if not m:
    sys.exit(1)
try:
    datos = json.loads(m.group(0))
except Exception:
    sys.exit(1)
patron = sys.argv[1].lower()

def caja(e):
    f = e.get("frame")
    if isinstance(f, dict):
        return f.get("x", 0), f.get("y", 0), f.get("width", 0), f.get("height", 0)
    nums = [float(x) for x in re.findall(r"-?\d+\.?\d*", str(e.get("AXFrame") or ""))]
    if len(nums) == 4:
        return nums[0], nums[1], nums[2], nums[3]
    return None

for e in datos:
    valores = [str(e.get(k) or "") for k in ("AXLabel", "AXValue", "AXUniqueId", "title")]
    if any(patron in v.lower() for v in valores):
        fr = caja(e)
        if fr:
            etiqueta = str(e.get("AXLabel") or e.get("AXUniqueId") or e.get("title") or "")
            print("%d %d|%s" % (fr[0] + fr[2] / 2, fr[1] + fr[3] / 2, etiqueta))
            sys.exit(0)
sys.exit(1)
' "$patron"
}

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
echo "=== elementos al arrancar ==="
idb_do ui describe-all 2>&1 | python3 -c '
import json, re, sys
raw = sys.stdin.read()
m = re.search(r"\[.*\]", raw, re.S)
if not m:
    print("(describe-all no disponible)"); sys.exit(0)
for e in json.loads(m.group(0)):
    etiqueta = e.get("AXLabel") or e.get("title") or e.get("AXValue")
    ident = e.get("AXUniqueId") or ""
    if etiqueta or ident:
        print("   %-12s label=%r id=%r" % (e.get("type"), etiqueta, ident))
' || true
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
                info=$(resolver_centro "$resto") || { echo "   elemento no encontrado: $resto"; rc=1; info=""; }
                if [ -n "$info" ]; then
                    xy="${info%%|*}"; etiqueta="${info#*|}"
                    echo "   centro=$xy etiqueta='$etiqueta'"
                    if [ -n "$etiqueta" ]; then
                        # el tap por marcador usa la accion de accesibilidad (AXPress):
                        # imprescindible para Toggle/Switch, donde un toque HID crudo
                        # sobre la etiqueta no cambia el estado.
                        idb_do ui tap "$etiqueta" || idb_do ui tap $xy || rc=$?
                    else
                        idb_do ui tap $xy || rc=$?
                    fi
                fi
            fi
            ;;
        tapxy)    idb_do ui tap $resto || rc=$? ;;
        text)     idb_do ui text "$resto" || rc=$? ;;
        setvalue)
            patron="${resto%% *}"; valor="${resto#* }"
            info=$(resolver_centro "$patron") || { echo "   elemento no encontrado: $patron"; rc=1; info=""; }
            if [ -n "$info" ]; then
                xy="${info%%|*}"; etiqueta="${info#*|}"
                idb_do ui set-value "$patron" --value "$valor" || idb_do ui tap $xy || rc=$?
                [ -n "$etiqueta" ] && idb_do ui tap "$etiqueta" >/dev/null 2>&1 || true
            fi
            ;;
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
ls "$OUT" | tail -5
echo "=== estado final (para verificar que la interaccion cambio la app) ==="
idb_do ui describe-all 2>&1 | python3 -c '
import json, re, sys
raw = sys.stdin.read()
m = re.search(r"\[.*\]", raw, re.S)
if not m:
    print("(sin describe)"); sys.exit(0)
for e in json.loads(m.group(0)):
    etiqueta = e.get("AXLabel") or e.get("title")
    if etiqueta:
        print("   %r valor=%r" % (etiqueta, e.get("AXValue")))
' || true
[ "$FALLOS" = 0 ] || exit 1
