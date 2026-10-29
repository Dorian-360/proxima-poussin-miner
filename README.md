# 🐣 Proxima Poussin Miner v2.0.0 — 0 % fees

Mineur GPU NVIDIA pour le réseau **Proxima**, basé sur une version modifiée de **ProxiChorizo**, développé par suprnova.cc.

**100 % gratuit — 0 % developer fees.**

### 1️⃣ Installer et configurer le nœud Proxima

```bash
mkdir -p ~/proxima && cd ~/proxima
wget https://github.com/lunfardo314/proxima/releases/download/v1.3.8p2/proxima-v1.3.8p2-linux.zip
unzip proxima-v1.3.8p2-linux.zip
cd bin
./proxi config node
./proxi config wallet -v
```

Dans `proxima.yaml`, mettre :

```yaml
api:
  port: 8000
  host: 0.0.0.0
```

À la fin de `proxi.yaml`, ajouter :

```yaml
mine:
  seeker:
    listen: 0.0.0.0:8200
    token:
    spawn: false
    binary:
    threads: 0
```

Démarrer le nœud et attendre sa synchronisation.

### 2️⃣ Lancer le Stratum

```bash
cd ~/proxima/bin && screen -S proxima-stratum ./proxi node mine --workers 0 --stream http://65.21.170.230:8001 --stream http://79.137.70.25:8001 --stream http://51.254.47.76:8001
```

### 3️⃣ Télécharger le mineur

📩 **Token GitHub fourni en MP.**

```bash
read -rsp "Token GitHub : " TOKEN; echo
export TOKEN

mkdir -p /home/user/proxima-poussin-miner && \
cd /home/user/proxima-poussin-miner && \
ASSET_ID=$(curl -fsSL \
  -H "Authorization: Bearer $TOKEN" \
  "https://api.github.com/repos/Dorian-360/proxima-poussin-miner/releases/tags/v2.0.0" \
  | python3 -c 'import json,sys; d=json.load(sys.stdin); print(next(a["id"] for a in d["assets"] if a["name"]=="proxima-poussin-miner-v2.0.0.tar.gz"))') && \
curl -fL \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/octet-stream" \
  -o proxima-poussin-miner-v2.0.0.tar.gz \
  "https://api.github.com/repos/Dorian-360/proxima-poussin-miner/releases/assets/$ASSET_ID" && \
tar xzf proxima-poussin-miner-v2.0.0.tar.gz && \
chown -R user:user /home/user/proxima-poussin-miner

unset TOKEN
```

### 4️⃣ Ajouter la clé et lancer le mineur

Placer `proxima.key` (ou un autre fichier `*.key`) dans le dossier du mineur.

```bash
./start-proxima-poussin-miner.sh
```

Au premier lancement, saisir l'adresse IP du coordinateur Stratum (port `8200`).

### 📜 Licence et crédits

**Proxima Poussin Miner** est un projet communautaire dérivé de **ProxiChorizo**, développé par **suprnova.cc**.

Copyright © 2026 suprnova.cc — droits sur le logiciel original.

Les modifications spécifiques à Proxima Poussin Miner sont réalisées par **Dorian-360**.

Ce projet est distribué sous la **ProxiChorizo License 1.0**, conformément aux conditions de redistribution prévues par cette licence.

Conditions de redistribution :

- Le logiciel dérivé doit conserver la ProxiChorizo License 1.0.
- Le code source complet correspondant doit accompagner toute distribution d'une version modifiée.
- Les mentions de copyright, d'attribution et le fichier `NOTICE` doivent être conservés.
- Les modifications apportées au logiciel original doivent être clairement identifiées.
- L'intégration du code dans un autre mineur commercial ou fermé peut nécessiter l'autorisation écrite préalable de suprnova.cc, conformément à la section 3 de la licence.

**Proxima Poussin Miner est distribué gratuitement et ne prélève aucun frais développeur.**

Ce projet est indépendant et n'est ni officiel, ni affilié, ni approuvé par suprnova.cc.

Licence complète : consulter le fichier `LICENSE` fourni avec le code source.

### 🐣 Bon minage !
