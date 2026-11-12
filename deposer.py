#!/usr/bin/env python3
"""Partie « Opportunités (LinkedIn) » du rapport du matin : pistes de la veille, brouillons complets (De / À / Objet / Corps),
à valider un par un en session : decider O<jjmm>-n oui|non. Usage : deposer.py <date de la lecture> [--apercu]"""
import datetime, json, subprocess, sys
from pathlib import Path
R = Path(__file__).resolve().parent; J = sys.argv[1]
fil = {}
try: fil = json.loads((R / "etat" / f"{J}-fil.json").read_text())
except Exception: pass
rap = {}
try: rap = json.loads((R / "rapports" / f"{J}.json").read_text())
except Exception: pass
L = []
if fil.get("erreur"):
    L.append("LinkedIn n'était pas connecté dans le navigateur dédié de la tour : rien n'a été lu. Il faut s'y connecter une fois, à la main, dans ce navigateur.")
else:
    L.append(f"Fil lu : {fil.get('lues', '?')} publications (jusqu'à {fil.get('plus_ancienne', '?')}) ; {len(fil.get('pistes', []))} personne(s) qui cherchent un prestataire.")
    if fil and not fil.get("fil_complet", True):
        L.append("Attention : le fil n'a pas été lu jusqu'à 24 h en arrière cette fois (critère non tenu).")
P = rap.get("propositions") or []
if P:
    L += ["", f"À VALIDER, mail par mail ({len(P)}) — en session : « oui O…-n » envoie CE mail tel quel depuis anthony@ingevision.cloud (signature Ingevision) ; « non O…-n » l'écarte :"]
    for p in P:
        L += ["", f"[{p['id']}] {p.get('auteur')} — {p.get('organisation')} : {p.get('besoin')}",
              f"Publication : {p.get('lien_publication')}" + (f" (recommandé par {p['recommande_par']})" if p.get("recommande_par") else ""),
              "De : Anthony Hunt <anthony@ingevision.cloud>",
              f"À : {p['contact']} (adresse publiée sur {p.get('source_contact')})" if p.get("contact") else "À : aucune adresse publique trouvée — ce mail ne peut pas partir tel quel",
              f"Objet : {p.get('objet')}", "", p.get("texte", ""), "", f"Pourquoi : {p.get('pourquoi', '')}"]
elif fil.get("pistes") and not rap:
    L += ["", "Les brouillons n'ont pas pu être écrits (pas de poste libre) : les pistes brutes :"]
    L += [f"• {x.get('auteur')} : {x.get('besoin')} — {x.get('lien')}" for x in fil["pistes"]]
for x in rap.get("ecartees") or []:
    L.append(f"Écartée : {x.get('lien')} — {x.get('raison')}")
sujet = f"Opportunités LinkedIn : {len(P)} mail(s) à valider" if P else "Opportunités LinkedIn : rien à valider"
t = R / "logs" / f"{J}-depot.txt"; t.write_text("\n".join(L), encoding="utf-8")
if "--apercu" in sys.argv: print(sujet + "\n" + "\n".join(L)); sys.exit()
lendemain = (datetime.date.fromisoformat(J) + datetime.timedelta(days=1)).isoformat()
sys.exit(subprocess.run(["/home/claude/mail-du-matin/deposer.py", "opportunites", "--date", lendemain, "--sujet", sujet, "--text-file", str(t)]).returncode)
