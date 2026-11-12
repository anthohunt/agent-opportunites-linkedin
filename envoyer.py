#!/usr/bin/env python3
"""Envoie UN mail de premier contact validé par Anthony (decider O<jjmm>-n oui) : texte exact du brouillon, gabarit Ingevision
(bandeau A, signature) + version texte, depuis anthony@ingevision.cloud ; copie dans Envoyés ; envoyes/<ID>.json.
Usage : envoyer.py <ID> [--essai]"""
import json, smtplib, ssl, sys, time, html
from email.message import EmailMessage
from email.utils import formatdate, make_msgid
from pathlib import Path
sys.path.insert(0, "/home/claude/site-anthony-hunt/serveur-avis")
from mail_gabarit import gabarit, paragraphe
R = Path(__file__).resolve().parent; I = sys.argv[1].upper()
BOITE = Path("/home/claude/.config/secrets/ingevision/boite-anthony.json")
p = next((x for f in sorted((R / "rapports").glob("*.json")) for x in json.loads(f.read_text()).get("propositions", []) if x["id"].upper() == I), None)
if not p: sys.exit(f"{I} : brouillon introuvable")
if not p.get("contact"): sys.exit(f"{I} : aucune adresse publique, rien n'est envoyé")
v = R / "validations" / f"{I}.json"
if not v.exists() or json.loads(v.read_text()).get("decision") != "oui": sys.exit(f"{I} : pas de oui d'Anthony")
if (R / "envoyes" / f"{I}.json").exists(): sys.exit(f"{I} : déjà envoyé")
(R / "envoyes").mkdir(exist_ok=True)   # avant l'envoi : la preuve doit pouvoir être écrite
SIG = "\n\nAnthony Hunt\nDéveloppement · Formation · Consulting\nanthony@ingevision.cloud · https://ingevision.cloud"
import re
gras = lambda s: re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", s)   # gras demandé par Anthony (12/11) : **…** → <b>…</b>
corps_html = "".join(paragraphe(gras(html.escape(b)).replace("\n", "<br>")) for b in p["texte"].split("\n\n"))
texte_brut = re.sub(r"\*\*(.+?)\*\*", r"\1", p["texte"])
m = EmailMessage(); b = json.loads(BOITE.read_text())
m["From"] = "Anthony Hunt <%s>" % b["adresse"]; m["To"] = p["contact"]; m["Subject"] = p["objet"]
m["Date"] = formatdate(localtime=True); m["Message-ID"] = make_msgid(domain="ingevision.cloud")
m.set_content(texte_brut + SIG)
m.add_alternative(gabarit(p["objet"], corps_html, variante="A", sous_titre=f"Pour {p.get('organisation') or p.get('auteur')}"), subtype="html")
if "--essai" in sys.argv: print(f"[essai] {I} → {p['contact']} : {p['objet']} ({len(p['texte'])} caractères)"); sys.exit()
with smtplib.SMTP_SSL("smtp.hostinger.com", 465, context=ssl.create_default_context(), timeout=60) as s:
    s.login(b["adresse"], b["mdp"]); s.send_message(m)
try:
    import imaplib
    i = imaplib.IMAP4_SSL("imap.hostinger.com"); i.login(b["adresse"], b["mdp"]); i.append("INBOX.Sent", "\\Seen", None, m.as_bytes()); i.logout()
except Exception as x: print("(copie dans Envoyés impossible : %s)" % type(x).__name__)
(R / "envoyes" / f"{I}.json").write_text(json.dumps({"id": I, "a": p["contact"], "objet": p["objet"], "message_id": m["Message-ID"], "envoye": time.strftime("%F %T")}, ensure_ascii=False))
print(f"Envoyé à {p['contact']} : {p['objet']}")
