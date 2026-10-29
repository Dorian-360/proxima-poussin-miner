#!/usr/bin/env bash
set -Eeuo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================================================
#                    PROXIMA POUSSIN MINER - CONFIGURATION
#                    Modifier les valeurs ici si necessaire
# ============================================================================
# GPU : valeurs par defaut, modifiables aussi via variables d'environnement
PROXI_POWER_LIMIT="${PROXI_POWER_LIMIT:-250}"  # Limite de puissance, W

# NVIDIA RTX 30xx
PROXI_CORE30="${PROXI_CORE30:-1550}"         # Coeur, MHz
PROXI_MEM30="${PROXI_MEM30:-5001}"           # Memoire, MHz
PROXI_OFFSET30="${PROXI_OFFSET30:-250}"      # Offset coeur, MHz

# NVIDIA RTX 50xx
PROXI_CORE50="${PROXI_CORE50:-2650}"         # Coeur, MHz
PROXI_MEM50="${PROXI_MEM50:-7001}"           # Memoire, MHz
PROXI_OFFSET50="${PROXI_OFFSET50:-300}"      # Offset coeur, MHz

# Ventilation et options
PROXI_ENABLE_OFFSET="${PROXI_ENABLE_OFFSET:-1}"  # 1 = oui, 0 = non
PROXI_FAN="${PROXI_FAN:-75}"                    # 0 = automatique, 30-100 = fixe

# X11 : laisser vides pour detection automatique
PROXI_DISPLAY="${PROXI_DISPLAY:-}"             # Ex. :0
PROXI_XAUTHORITY="${PROXI_XAUTHORITY:-}"       # Ex. /run/user/120/gdm/Xauthority

# Mineur / coordinateur
PROXI_API_BIND="${PROXI_API_BIND:-0.0.0.0:4078}"
PROXI_NODE_URL="${PROXI_NODE_URL:-}"           # Vide = config enregistree / demande IP
PROXI_KEY_FILE="${PROXI_KEY_FILE:-}"           # Vide = recherche *.key
# ============================================================================

fail() { printf '[ERREUR] %s\n' "$*" >&2; exit 1; }
log() { printf '%s\n' "$*"; }
if (( EUID == 0 )); then ROOT=(); else ROOT=(sudo); fi

# Chemins absolus, car sudo peut avoir un PATH different.
SMI="$(command -v nvidia-smi || true)"
SETTINGS="$(command -v nvidia-settings || true)"

# L'acces X11 peut dependre de GDM, LightDM, Xorg ou de l'utilisateur.
# On verifie chaque combinaison en utilisant les memes privileges que pour l'OC.
XDISPLAY=""; XAUTH=""; XMODE=""
try_x11() {
  local disp="$1" auth="$2" mode="$3"
  if [[ "$mode" == auth ]]; then
    [[ -n "$auth" ]] || return 1
    "${ROOT[@]}" test -f "$auth" 2>/dev/null || return 1
    "${ROOT[@]}" env DISPLAY="$disp" XAUTHORITY="$auth" "$SETTINGS" -q gpus >/dev/null 2>&1 || return 1
  else
    env DISPLAY="$disp" "$SETTINGS" -q gpus >/dev/null 2>&1 || return 1
  fi
  XDISPLAY="$disp"; XAUTH="$auth"; XMODE="$mode"
  return 0
}

setup_x11() {
  [[ -n "$SETTINGS" ]] || return 1
  local -a displays=() candidates=()
  local d a proc auth
  [[ -n "$PROXI_DISPLAY" ]] && displays+=("$PROXI_DISPLAY")
  [[ -n "${DISPLAY:-}" ]] && displays+=("$DISPLAY")
  # Xorg -displayfd correspond habituellement a :0, mais essayer les autres aussi.
  displays+=(:0 :1 :2)

  [[ -n "$PROXI_XAUTHORITY" ]] && candidates+=("$PROXI_XAUTHORITY")
  # Extraire -auth depuis les processus Xorg/Xwayland (sans executer le texte trouve).
  while IFS= read -r proc; do
    auth="$(sed -nE 's/.*(^|[[:space:]])-auth[[:space:]]+([^[:space:]]+).*/\2/p' <<< "$proc")"
    [[ -n "$auth" ]] && candidates+=("$auth")
  done < <(ps -eo args= 2>/dev/null | grep -E '(^|/)(Xorg|Xwayland)([[:space:]]|$)' || true)

  # GDM (UID variable), LightDM, session utilisateur et root.
  shopt -s nullglob
  candidates+=(/run/user/*/gdm/Xauthority /run/gdm*/auth-for-*/database \
               /var/run/lightdm/root/:0 /run/lightdm/root/:0 \
               "${XAUTHORITY:-}" "$HOME/.Xauthority" /home/user/.Xauthority /root/.Xauthority)
  shopt -u nullglob

  # Ne jamais accepter un test fait avec un autre mode que celui utilise ensuite.
  for d in "${displays[@]}"; do
    [[ -n "$d" ]] || continue
    for a in "${candidates[@]}"; do
      [[ -n "$a" ]] || continue
      if try_x11 "$d" "$a" auth; then
        log "[X11] OK : DISPLAY=$XDISPLAY / XAUTHORITY=$XAUTH"
        return 0
      fi
    done
    if try_x11 "$d" "" user; then
      log "[X11] OK : DISPLAY=$XDISPLAY / session utilisateur"
      return 0
    fi
  done
  return 1
}

nvset() {
  if [[ "$XMODE" == auth ]]; then
    "${ROOT[@]}" env DISPLAY="$XDISPLAY" XAUTHORITY="$XAUTH" "$SETTINGS" "$@"
  else
    env DISPLAY="$XDISPLAY" "$SETTINGS" "$@"
  fi
}

# Adresse du coordinateur
NODE_FILE="$DIR/.proxima-node-url"
NODE_URL="$PROXI_NODE_URL"
if [[ -z "$NODE_URL" && -s "$NODE_FILE" ]]; then
  IFS= read -r NODE_URL < "$NODE_FILE" || true
fi
if [[ -z "$NODE_URL" ]]; then
  [[ -t 0 ]] || fail 'Premier lancement interactif necessaire pour saisir le coordinateur'
  read -rp 'IP du coordinateur Proxima (port 8200) : ' NODE_URL
  [[ -n "$NODE_URL" ]] || fail 'Adresse vide'
  [[ "$NODE_URL" == http://* || "$NODE_URL" == https://* ]] || NODE_URL="http://$NODE_URL"
  hostpart="${NODE_URL#*://}"
  [[ "$hostpart" == *:* ]] || NODE_URL="$NODE_URL:8200"
  (umask 077; printf '%s\n' "$NODE_URL" > "$NODE_FILE") || fail "Impossible d'ecrire $NODE_FILE"
fi
log "[PROXI] Coordinateur : $NODE_URL"

# Cle : jamais afficher son contenu.
KEY_FILE="$PROXI_KEY_FILE"
if [[ -z "$KEY_FILE" && -r "$DIR/proxima.key" ]]; then KEY_FILE="$DIR/proxima.key"; fi
if [[ -z "$KEY_FILE" ]]; then
  shopt -s nullglob
  for f in "$DIR"/*.key "$DIR"/.*.key; do
    [[ -f "$f" && -r "$f" ]] || continue
    KEY_FILE="$f"; break
  done
  shopt -u nullglob
fi
[[ -n "$KEY_FILE" && -r "$KEY_FILE" ]] || fail 'Aucun fichier *.key lisible'
[[ -x "$DIR/proxima-poussin-miner" ]] || fail "Mineur introuvable : $DIR/proxima-poussin-miner"
python3 - "$KEY_FILE" <<'PY'
import json,sys
try:
    with open(sys.argv[1],encoding='utf-8') as f: d=json.load(f)
    assert isinstance(d.get('private_key'),str) and d['private_key']
except Exception as e:
    sys.exit('ERREUR : cle Proxima invalide : '+str(e))
PY

# Controle des entrees avant de toucher au GPU.
[[ "$PROXI_FAN" =~ ^(0|[3-9][0-9]|100)$ ]] || fail 'PROXI_FAN doit etre 0 ou compris entre 30 et 100'
[[ "$PROXI_ENABLE_OFFSET" == 0 || "$PROXI_ENABLE_OFFSET" == 1 ]] || fail 'PROXI_ENABLE_OFFSET doit valoir 0 ou 1'

if [[ -n "$SMI" ]]; then
  log '[GPU] Verification des autorisations NVIDIA...'
  if (( EUID != 0 )); then sudo -v || fail 'sudo refuse'; fi
  XREADY=0
  if [[ -n "$SETTINGS" ]]; then
    if setup_x11; then XREADY=1; else log '[X11] Aucun acces valide : offset/FAN ignores'; fi
  else
    log '[X11] nvidia-settings absent : offset/FAN ignores'
  fi
  GPU_COUNT="$($SMI --query-gpu=index --format=csv,noheader 2>/dev/null | grep -c '[0-9]' || true)"
  # Appliquer silencieusement la meme consigne a tous les GPU/ventilateurs.
  FAN_STATUS='[--]'
  FAN_VALUE='X11 indisponible'
  if (( XREADY == 1 )); then
    fan_error=0
    if [[ "$PROXI_FAN" == 0 ]]; then
      while IFS= read -r gi; do
        gi="${gi//[[:space:]]/}"
        [[ "$gi" =~ ^[0-9]+$ ]] || continue
        nvset -a "[gpu:$gi]/GPUFanControlState=0" >/dev/null 2>&1 || fan_error=1
      done < <("$SMI" --query-gpu=index --format=csv,noheader)
      FAN_VALUE='automatique'
    else
      while IFS= read -r gi; do
        gi="${gi//[[:space:]]/}"
        [[ "$gi" =~ ^[0-9]+$ ]] || continue
        nvset -a "[gpu:$gi]/GPUFanControlState=1" >/dev/null 2>&1 || fan_error=1
      done < <("$SMI" --query-gpu=index --format=csv,noheader)
      fan_ids="$(nvset -q fans 2>/dev/null | grep -oE '\[fan:[0-9]+\]' | sed -E 's/\[fan:([0-9]+)\]/\1/' | sort -nu || true)"
      if [[ -z "$fan_ids" ]]; then
        fan_error=1
      else
        while IFS= read -r fan; do
          [[ "$fan" =~ ^[0-9]+$ ]] || continue
          nvset -a "[fan:$fan]/GPUTargetFanSpeed=$PROXI_FAN" >/dev/null 2>&1 || fan_error=1
        done <<< "$fan_ids"
      fi
      FAN_VALUE="$PROXI_FAN %"
    fi
    if (( fan_error == 0 )); then FAN_STATUS='[OK]'; else FAN_STATUS='[!!]'; FAN_VALUE="$FAN_VALUE (echec partiel)"; fi
  fi
  while IFS= read -r index; do
    index="${index//[[:space:]]/}"
    [[ "$index" =~ ^[0-9]+$ ]] || continue
    name="$($SMI -i "$index" --query-gpu=name --format=csv,noheader 2>/dev/null || true)"
    case "$name" in
      *RTX\ 30*) core="$PROXI_CORE30"; mem="$PROXI_MEM30"; offset="$PROXI_OFFSET30" ;;
      *RTX\ 50*) core="$PROXI_CORE50"; mem="$PROXI_MEM50"; offset="$PROXI_OFFSET50" ;;
      *) log "[OC] GPU $index ($name) : famille non configuree"; continue ;;
    esac
    printf '\n%s\n' '=================================================================='
    printf ' GPU %s | %s\n' "$index" "$name"
    printf '%s\n' '------------------------------------------------------------------'
    gpu_setting() {
      local label="$1" value="$2"; shift 2
      local output
      if output=$("${ROOT[@]}" "$SMI" -i "$index" "$@" 2>&1); then
        printf '  [OK] %-20s %s\n' "$label" "$value"
      else
        printf '  [!!] %-20s %s (refuse)\n' "$label" "$value"
        printf '       %s\n' "$(printf '%s' "$output" | head -n 1)"
      fi
    }
    gpu_setting 'Mode persistant' 'active' -pm 1
    gpu_setting 'Limite puissance' "$PROXI_POWER_LIMIT W" -pl "$PROXI_POWER_LIMIT"
    gpu_setting 'Frequence coeur' "$core MHz" -lgc "$core,$core"
    gpu_setting 'Frequence memoire' "$mem MHz" -lmc "$mem,$mem"
    if (( XREADY != 1 )); then
      printf '  [--] %-20s %s\n' 'Offset coeur' 'X11 indisponible'
      printf '  %s %-20s %s\n' "$FAN_STATUS" 'Ventilation' "$FAN_VALUE"
      printf '%s\n' '=================================================================='
      continue
    fi

    if [[ "$PROXI_ENABLE_OFFSET" == 1 ]]; then
      if nvset -a "[gpu:$index]/GPUGraphicsClockOffsetAllPerformanceLevels=$offset" >/dev/null 2>&1; then
        printf '  [OK] %-20s %+d MHz\n' 'Offset coeur' "$offset"
      else
        printf '  [!!] %-20s %s\n' 'Offset coeur' 'refuse (pilote/CoolBits)'
      fi
    else
      printf '  [--] %-20s %s\n' 'Offset coeur' 'desactive'
    fi

    printf '  %s %-20s %s\n' "$FAN_STATUS" 'Ventilation' "$FAN_VALUE"
    printf '%s\n' '=================================================================='
  done < <("$SMI" --query-gpu=index --format=csv,noheader)


else
  log '[OC] nvidia-smi absent : reglages GPU ignores'
fi

# Garder la boucle de relance dans un script separe, sans exposer les secrets.
LOOP="$DIR/.run-miner-loop.sh"
if [[ -e "$LOOP" && ! -w "$LOOP" ]]; then
  fail "Impossible de mettre a jour $LOOP (proprietaire root ?) : sudo chown \"$(id -un):$(id -gn)\" \"$LOOP\""
fi
cat > "$LOOP" <<'RUN'
#!/usr/bin/env bash
set -Eeuo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"
export CUDA_DEVICE_ORDER=PCI_BUS_ID
while true; do
  rc=0
  args=(--proxi "${PROXI_NODE_URL:?Coordinateur manquant}" --key-file "${PROXI_KEY_FILE:?Cle manquante}" --name "$(hostname)" --api-bind "${PROXI_API_BIND:-0.0.0.0:4078}")
  [[ ! -s "$DIR/.seeker-token" ]] || args+=(--token-file "$DIR/.seeker-token")
  ./proxima-poussin-miner "${args[@]}" "$@" || rc=$?
  echo "[Mineur] Arret ($rc), relance dans 10 s (Ctrl+C pour stopper)"
  sleep 10
done
RUN
chmod 700 "$LOOP"
export PROXI_NODE_URL="$NODE_URL" PROXI_KEY_FILE="$KEY_FILE"
log "[PROXI] Cle : $KEY_FILE"
log '[PROXI] Demarrage direct du mineur (Ctrl+C pour arreter)'
log "[PROXI] API : http://IP_DU_MINEUR:${PROXI_API_BIND##*:}/"
exec "$LOOP" "$@"
