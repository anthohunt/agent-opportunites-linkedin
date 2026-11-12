#!/bin/bash
# Brouillons de premier contact pour les pistes LinkedIn du jour : Claude sur un poste IOMEGA prêté (perso-claude, sans trace),
# dans la file des agents du site ; recherche web publique seulement (jamais LinkedIn) ; dépôt dans le rapport du matin.
set -u
R=$(cd "$(dirname "$0")" && pwd); J=$(TZ=Europe/Paris date +%F)
[ -s "$R/etat/$J-fil.json" ] || exit 0
L="$R/logs/$J.log"; log() { echo "$(date -u +%FT%TZ) $*" >> "$L"; }
N=$(python3 -c "import json;print(len(json.load(open('$R/etat/$J-fil.json')).get('pistes',[])))")
if [ "$N" = 0 ]; then log "aucune piste ce soir"; python3 "$R/deposer.py" "$J" >> "$L" 2>&1; exit 0; fi
exec 8>/tmp/agents-site.lock; flock -w 3600 8 || { log "file des agents du site trop longue"; python3 "$R/deposer.py" "$J" >> "$L" 2>&1; exit 6; }
W=/home/claude/agent-prospects-passe; rm -rf "$W"; mkdir -p "$W/sortie"
mkdir -p "$R/rapports" "$R/envoyes" "$R/validations" "$R/etat" "$R/logs"
cp "$R/etat/$J-fil.json" "$W/fil.json"; cp "$R/modele-mail.txt" "$W/"; touch "$R/deja-vus.txt"; cp "$R/deja-vus.txt" "$W/"
export DATE="$J" PREFIXE="O$(date -d "$J" +%d%m)"; perl -pe 's/\{\{(\w+)\}\}/$ENV{$1}/g' "$R/consigne-redaction.md" > "$R/logs/$J.consigne.md"
CPT=$(/usr/local/bin/compte-agents 2>/dev/null | tr -d "[:space:]"); CPT=${CPT:-$(cat /home/claude/maintenance/compte-actif)}
TOKF=/home/claude/.claude-tokens/account-$CPT.env; CFG=/home/claude/.claude-$CPT-iomega; mkdir -p "$CFG"
log "rédaction de $N brouillon(s) (compte $CPT)"
( cd "$W" && env -u ANTHROPIC_API_KEY -u CLAUDECODE CLAUDE_CONFIG_DIR="$CFG" PERSO_NOM=opportunites-linkedin \
    CLAUDE_CODE_OAUTH_TOKEN="$(grep -oP '(?<=CLAUDE_CODE_OAUTH_TOKEN=).*' "$TOKF" | tr -d "\"'")" \
    timeout 50m /home/claude/perso-iomega/perso-claude -p "$(cat "$R/logs/$J.consigne.md")" --model claude-opus-5-5 --effort high \
    --allowedTools "Read" "WebSearch" "WebFetch" "Write(/sortie/rapport.json)" "Edit(/sortie/rapport.json)" --disallowedTools "Bash" "WebFetch(domain:linkedin.com)" "WebFetch(domain:www.linkedin.com)" < /dev/null ) >> "$L" 2>&1
RC=$?; log "claude fini : code $RC"
if python3 -c "import json,sys;json.load(open(sys.argv[1]))" "$W/sortie/rapport.json" 2>/dev/null; then
  cp "$W/sortie/rapport.json" "$R/rapports/$J.json"
  python3 -c "import json;[print(p['lien']) for p in json.load(open('$R/etat/$J-fil.json'))['pistes']]" >> "$R/deja-vus.txt"
else log "pas de rapport de rédaction"; fi
rm -rf "$W"
python3 "$R/deposer.py" "$J" >> "$L" 2>&1
