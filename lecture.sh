#!/bin/bash
# Agent Opportunités, canal LinkedIn (12/11/2026, choix A d'Anthony : lecture seule de son LinkedIn personnel par la tour, un
# passage court par jour). Lit le fil des dernières 24 h par le relais de la tour (navigateur dédié, écran virtuel), garde les
# publications où quelqu'un cherche un prestataire, puis lance la rédaction des brouillons (redaction.sh, poste IOMEGA).
# La tour : si elle était éteinte avant le passage, elle est rééteinte après (sauf jeu ou autre travail en cours).
set -u
R=$(cd "$(dirname "$0")" && pwd); J=$(TZ=Europe/Paris date +%F)
[ "${FORCE:-0}" = 1 ] || case "$(TZ=Europe/Paris date +%H)" in 19|20) ;; *) exit 0;; esac
[ "${FORCE:-0}" = 1 ] || [ ! -e "$R/logs/$J.lu" ] || exit 0
mkdir -p "$R/verrous" "$R/etat" "$R/logs"; exec 9>"$R/verrous/lecture.lock"; flock -n 9 || exit 1
L="$R/logs/$J.log"; log() { echo "$(date -u +%FT%TZ) $*" >> "$L"; }
ETEINTE=0; ssh -o BatchMode=yes -o ConnectTimeout=8 tour true 2>/dev/null || ETEINTE=1
log "lecture du fil (tour éteinte avant : $ETEINTE)"
RELAIS_DUREE=1500 timeout 1700 /home/claude/agents-site/relais-x.sh "$(cat "$R/consigne-lecture.md")" > "$R/etat/$J-relais.txt" 2>> "$L"; RC=$?
log "relais fini : code $RC"
python3 - "$R/etat/$J-relais.txt" "$R/etat/$J-fil.json" <<'PY' >> "$L" 2>&1
import json, re, sys
t = open(sys.argv[1], encoding="utf-8", errors="replace").read()
if "NON CONNECTÉ" in t:
    json.dump({"erreur": "non connecté"}, open(sys.argv[2], "w")); print("LinkedIn non connecté"); sys.exit(3)
m = re.findall(r"RESULTAT_JSON:\s*(\{.*\})", t)
if not m: print("pas de résultat lisible"); sys.exit(4)
d = json.loads(m[-1])
d["pistes"] = [p for p in d.get("pistes", []) if re.match(r"https://(www\.)?linkedin\.com/(feed/update|posts)/", p.get("lien", ""))]
age = str(d.get("plus_ancienne", "")); d["fil_complet"] = bool(re.search(r"\b([1-9]\d*)\s*(j|sem|mois|an|d|w)", age))   # critère : les 24 h lues en entier
json.dump(d, open(sys.argv[2], "w"), ensure_ascii=False, indent=1); print(f"{d.get('lues')} lues jusqu'à {age} ({'24 h couvertes' if d['fil_complet'] else 'FIL INCOMPLET'}), {len(d['pistes'])} piste(s) avec un vrai lien")
PY
OK=$?
if [ "$ETEINTE" = 1 ] && ! ssh -o BatchMode=yes -o ConnectTimeout=8 tour 'pgrep -fi "dolphin|steam|proton|nucleus|retroarch|claude -p" >/dev/null' 2>/dev/null; then
  ssh -o BatchMode=yes tour 'sudo -n systemctl poweroff' >/dev/null 2>&1 && log "tour rééteinte"
fi
[ "$OK" = 3 ] && { /home/claude/bin/signaler-maintenance "Opportunités LinkedIn : non connecté" "Anthony doit se connecter une fois à LinkedIn dans le navigateur dédié de la tour (écran :60, RustDesk) ; aucun mot de passe enregistré par un agent" --source agent-prospects >/dev/null 2>&1; }
[ "$OK" = 0 ] || exit 1
touch "$R/logs/$J.lu"
"$R/redaction.sh" >> "$L" 2>&1 &
