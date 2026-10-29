# :hatched_chick: Proxima Poussin Miner v2.0.0 — 0 % fees

### :one: Installer et configurer le nœud Proxima

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

### :two: Lancer le Stratum

```bash
cd ~/proxima/bin && screen -S proxima-stratum ./proxi node mine --workers 0 --stream http://65.21.170.230:8001 --stream http://79.137.70.25:8001 --stream http://51.254.47.76:8001
```

### :three: Télécharger le mineur

:envelope_with_arrow: **Token GitHub fourni en MP.**

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

### :four: Ajouter la clé et lancer le mineur

Placer `proxima.key` (ou un autre fichier `*.key`) dans le dossier du mineur.

```bash
./start-proxima-poussin-miner.sh
```

Au premier lancement, saisir l'adresse IP du coordinateur Stratum (port `8200`).

:pick: **Bon minage !**
