#!/usr/bin/env bash
###############################################################################
#                          SMPTUser: Descubre usuarios válidos SMTP           #
#  ================================================================          #
#  Autor: Tuch0         |  GitHub: https://github.com/Tuch0                #
#  Descripción: Escanea un servidor SMTP para localizar buzones válidos.      #
#               Usa VRFY o RCPT, soporta concurrencia, verbose y timeouts.   #
#  Uso:                                                                        #
#    ./SMPTUser.sh -d <TARGET> -w <WORDLIST> [opciones]                       #
###############################################################################

# ──────────────────────────────────────────────────────────────────────────────
#                            Configuración de colores
# ──────────────────────────────────────────────────────────────────────────────
LRED='\033[91m'     # Rojo claro
LGREEN='\033[92m'   # Verde claro
LYELLOW='\033[93m'  # Amarillo claro
LCYAN='\033[96m'    # Cian claro
LMAGENTA='\033[95m' # Magenta claro
NC='\033[0m'        # Sin color

# ──────────────────────────────────────────────────────────────────────────────
#                           Variables por defecto
# ──────────────────────────────────────────────────────────────────────────────
PORT=25                  # Puerto SMTP por defecto
THREADS=5                # Hilos concurrentes por defecto
TIMEOUT=7                # Timeout en segundos por petición SMTP
METHOD="VRFY"            # Método de verificación: VRFY o RCPT
VERBOSE=0                # Modo verbose apagado por defecto
TARGET=""                # IP/domino SMTP objetivo (obligatorio)
WORDLIST=""              # Ruta al wordlist de usuarios (obligatorio)
FOUND_FILE="/tmp/SMPTUser_found.$$"  # Archivo temporal para indicar usuario encontrado

# ──────────────────────────────────────────────────────────────────────────────
#                       Funciones de limpieza y uso
# ──────────────────────────────────────────────────────────────────────────────

# Limpieza al recibir Ctrl+C
cleanup_on_sigint() {
  echo -e "\n${LRED}[!] Interrupción recibida. Saliendo...${NC}"
  [[ -f "$FOUND_FILE" ]] && rm -f "$FOUND_FILE"
  exit 1
}
trap cleanup_on_sigint SIGINT

# Limpieza al terminar normalmente
cleanup_on_exit() {
  [[ -f "$FOUND_FILE" ]] && rm -f "$FOUND_FILE"
  exit 0
}
trap cleanup_on_exit EXIT

# Mostrar ayuda
usage() {
  echo -e "
${LCYAN}SMPTUser${NC}: Descubre buzones SMTP válidos

${LCYAN}Uso:${NC} $0 -d <TARGET> -w <WORDLIST> [OPCIONES]

${LCYAN}Obligatorio:${NC}
  -d ${LYELLOW}<TARGET>${NC}      IP o dominio del servidor SMTP a escanear.
  -w ${LYELLOW}<WORDLIST>${NC}    Ruta al archivo con los posibles usuarios.

${LCYAN}Opciones:${NC}
  -p ${LYELLOW}<PORT>${NC}        Puerto SMTP (por defecto: ${PORT}).
  -t ${LYELLOW}<THREADS>${NC}     Hilos concurrentes (por defecto: ${THREADS}).
  -T ${LYELLOW}<TIMEOUT>${NC}     Timeout en segundos (por defecto: ${TIMEOUT}).
  -m ${LYELLOW}<METHOD>${NC}      Método de verificación: ${LYELLOW}VRFY${NC} o ${LYELLOW}RCPT${NC} (por defecto: ${METHOD}).
  -v                            Modo verbose. Muestra cada intento en pantalla.
  -h, --help                    Mostrar esta ayuda y salir.

${LCYAN}Ejemplos:${NC}
  # Escanear con VRFY, 10 hilos, timeout 10s:
  $0 -d mail.ejemplo.com -w usuarios.txt -t 10 -T 10 -m VRFY -v

  # Escanear usando RCPT TO (si VRFY está deshabilitado):
  $0 -d mail.ejemplo.com -w usuarios.txt -m RCPT
"
  exit 1
}

# ──────────────────────────────────────────────────────────────────────────────
#                       Verificar dependencias
# ──────────────────────────────────────────────────────────────────────────────
command -v nc      >/dev/null 2>&1 || { echo -e "${LRED}[!] Necesitas 'nc' (netcat) instalado.${NC}"; exit 1; }
command -v timeout >/dev/null 2>&1 || { echo -e "${LRED}[!] Necesitas 'timeout' instalado.${NC}"; exit 1; }
command -v awk     >/dev/null 2>&1 || { echo -e "${LRED}[!] Necesitas 'awk' instalado.${NC}"; exit 1; }

# ──────────────────────────────────────────────────────────────────────────────
#                        Parsear opciones con getopts
# ──────────────────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    -d)
      TARGET="$2"; shift 2 ;;
    -w)
      WORDLIST="$2"; shift 2 ;;
    -p)
      PORT="$2"; shift 2 ;;
    -t)
      THREADS="$2"; shift 2 ;;
    -T)
      TIMEOUT="$2"; shift 2 ;;
    -m)
      METHOD="$(echo "$2" | tr '[:lower:]' '[:upper:]')"
      if [[ "$METHOD" != "VRFY" && "$METHOD" != "RCPT" ]]; then
        echo -e "${LRED}[!] Método inválido: $2. Usa VRFY o RCPT.${NC}"
        exit 1
      fi
      shift 2 ;;
    -v)
      VERBOSE=1; shift ;;
    -h|--help)
      usage ;;
    *)
      echo -e "${LRED}[!] Opción desconocida: $1${NC}"
      usage ;;
  esac
done

# ──────────────────────────────────────────────────────────────────────────────
#                     Validar parámetros obligatorios
# ──────────────────────────────────────────────────────────────────────────────
if [[ -z "$TARGET" || -z "$WORDLIST" ]]; then
  echo -e "${LRED}[!] Debes indicar -d <TARGET> y -w <WORDLIST>.${NC}"
  usage
fi

if [[ ! -r "$WORDLIST" ]]; then
  echo -e "${LRED}[!] No se puede leer la wordlist: ${WORDLIST}${NC}"
  exit 1
fi

# ──────────────────────────────────────────────────────────────────────────────
#                           Banner de presentación
# ──────────────────────────────────────────────────────────────────────────────
echo -e "${LMAGENTA}"
echo " ██████  ███▄ ▄███▓▄▄▄█████▓ ██▓███   █    ██   ██████ ▓█████  ██▀███  "
echo "▒██    ▒ ▓██▒▀█▀ ██▒▓  ██▒ ▓▒▓██░  ██▒ ██  ▓██▒▒██    ▒ ▓█   ▀ ▓██ ▒ ██▒"
echo "░ ▓██▄   ▓██    ▓██░▒ ▓██░ ▒░▓██░ ██▓▒▓██  ▒██░░ ▓██▄   ▒███   ▓██ ░▄█ ▒"
echo "  ▒   ██▒▒██    ▒██ ░ ▓██▓ ░ ▒██▄█▓▒ ▒▓▓█  ░██░  ▒   ██▒▒▓█  ▄ ▒██▀▀█▄  "
echo "▒██████▒▒▒██▒   ░██▒  ▒██▒ ░ ▒██▒ ░  ░▒▒█████▓ ▒██████▒▒░▒████▒░██▓ ▒██▒"
echo "▒ ▒▓▒ ▒ ░░ ▒░   ░  ░  ▒ ░░   ▒▓▒░ ░  ░░▒▓▒ ▒ ▒ ▒ ▒▓▒ ▒ ░░░ ▒░ ░░ ▒▓ ░▒▓░"
echo "░ ░▒  ░ ░░  ░      ░    ░    ░▒ ░     ░░▒░ ░ ░ ░ ░▒  ░ ░ ░ ░  ░  ░▒ ░ ▒░"
echo "░  ░  ░  ░      ░     ░      ░░        ░░░ ░ ░ ░  ░  ░     ░     ░░   ░ "
echo "      ░         ░                        ░           ░     ░  ░   ░     "
echo -e "${NC}${LCYAN}                SMTPUser.sh  -  Enumerador de usuarios SMTP${NC}"
# alineamos "by tuch0" a la misma anchura que el banner (~80 columnas)
printf "%80s\n" "${LMAGENTA}by tuch0${NC}"
echo

echo "                   Descubre usuarios válidos SMTP                        "
echo -e "${NC}${LCYAN}                      SMPTUser.sh                       ${NC}"
echo -e "${LMAGENTA}                           by tuch0${NC}"
echo
echo -e "${LCYAN}[*] Objetivo:        ${LYELLOW}${TARGET}:${PORT}${NC}"
echo -e "${LCYAN}[*] Wordlist:        ${LYELLOW}${WORDLIST}${NC}"
echo -e "${LCYAN}[*] Método:          ${LYELLOW}${METHOD}${NC}"
echo -e "${LCYAN}[*] Hilos:           ${LYELLOW}${THREADS}${NC}"
echo -e "${LCYAN}[*] Timeout (s):     ${LYELLOW}${TIMEOUT}${NC}"
[[ $VERBOSE -eq 1 ]] && echo -e "${LCYAN}[*] Modo verbose:    ${LYELLOW}ON${NC}"
echo

# ──────────────────────────────────────────────────────────────────────────────
#                    Función worker: prueba un único usuario
# ──────────────────────────────────────────────────────────────────────────────
worker() {
  local user="$1"

  # Si otro proceso ya encontró usuario, salir
  [[ -f "$FOUND_FILE" ]] && exit 0

  # Mostrar en verbose
  if [[ $VERBOSE -eq 1 ]]; then
    echo -e "${LCYAN}[>] Probando: ${LYELLOW}${user}${NC}"
  fi

  if [[ "$METHOD" == "VRFY" ]]; then
    # Enviar EHLO, luego VRFY y filtrar respuestas 250 2.* o 252
    response=$(
      {
        echo -e "EHLO fuzz.local\r\nVRFY ${user}\r\nQUIT"
      } | timeout "${TIMEOUT}" nc "${TARGET}" "${PORT}" 2>/dev/null \
        | awk '/^250 2\.[0-9]\./ || /^252/'
    )
  else
    # Enviar EHLO, MAIL FROM y RCPT TO; filtrar 250 2.*
    response=$(
      {
        echo -e "EHLO fuzz.local\r\nMAIL FROM:<fuzzer@local.test>\r\nRCPT TO:<${user}@${TARGET}>\r\nQUIT"
      } | timeout "${TIMEOUT}" nc "${TARGET}" "${PORT}" 2>/dev/null \
        | awk '/^250 2\.[0-9]\./'
    )
  fi

  # Si la respuesta no está vacía, se encontró usuario válido
  if [[ -n "$response" ]]; then
    echo -e "${LGREEN}[+] Encontrado:${NC} ${LYELLOW}${user}${NC} ${LCYAN}[SMTP OK]${NC}"
    echo -e "    ${LMAGENTA}------------------------${NC}"
    echo "$response" | sed 's/^/    /'
    echo -e "    ${LMAGENTA}------------------------${NC}"
    touch "$FOUND_FILE"
  fi

  exit 0
}

# ──────────────────────────────────────────────────────────────────────────────
#                Función para contar trabajos en segundo plano (jobs)
# ──────────────────────────────────────────────────────────────────────────────
active_jobs() {
  jobs -rp | wc -l
}

# ──────────────────────────────────────────────────────────────────────────────
#        Leer wordlist línea a línea y lanzar hilos para cada usuario
# ──────────────────────────────────────────────────────────────────────────────
while IFS= read -r user || [[ -n "$user" ]]; do
  # Saltar líneas vacías o comentarios
  [[ -z "$user" || "$user" =~ ^# ]] && continue

  # Esperar si alcanzamos el límite de hilos
  while [[ $(active_jobs) -ge $THREADS ]]; do
    sleep 0.1
    [[ -f "$FOUND_FILE" ]] && break 2
  done

  # Lanzar worker en segundo plano
  worker "$user" &

  # Si ya se halló usuario, salir del bucle principal
  [[ -f "$FOUND_FILE" ]] && break
done < "$WORDLIST"

# Esperar a todos los hilos
wait

# Si no se encontró ningún usuario
if [[ ! -f "$FOUND_FILE" ]]; then
  echo -e "${LRED}[!] Ningún usuario válido encontrado en la wordlist.${NC}"
fi

# Limpieza y salida
cleanup_exit
