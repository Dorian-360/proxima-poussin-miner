# Modifications locales de ProxiChorizo 0.5.8 (pas de suprnova.cc)

Version `0.5.8-mod2`. Originaux dans `_original_0.5.8/`. Chaque changement est marqué `[modified]` dans le code.
Défaut Blackwell (v1.1.0) : `fe32c_wnaf_s16s_c`, 192 blocs/SM. Mesuré sur RTX 5070 Ti : 23,1 -> 24,5 MH/s (+5,9 %).

| Variante | Ajout (cumulatif) | 5070 Ti |
|---|---|---|
| s16 | origine | 23,10 |
| s16x | état intermédiaire SHA-512 par job (hash-to-curve), départ wNAF au chiffre de tête, table en additions cachées | 23,49 |
| s16y | doublement à 6 additions au lieu de 8 (coordonnées négées), addition sans T dans la boucle | 23,96 |
| s16z | choix par clé du scalaire équivalent le moins cher (+-s + j*8L) | 23,90-24,02 |
| s16u | réduction du carré : un mad.wide + une chaîne de retenues (2 instr./mot au lieu de 4) | 24,41 |
| s16t | racine carrée sans le 3e test inutile | 24,45 ; 24,47 à 192 blocs/SM |
| s16s | 2Z² calculé dans le carré lui-même (une addition de moins par doublement) | +6,2 % vs origine (+0,7 % vs s16t) — défaut v1.1.0 |
| s16r | s16s + inversion partagée sur 32 points | instable, non retenu |
| s16w / s16v | repli 38 sans multiplication (sub / add) : pas de gain, non utilisées | 23,65 / 23,77 |

Vérifié : émulateur CPU (vecteurs Go, 24 clés aléatoires, 10 000 sorties) et sur GPU `--selftest`, `--fetest`, `--verify`.
Banc : `./bench-mod.sh 30`.

## v1.2.0 — boucle de minage en pipeline
La boucle d'origine attendait la fin de chaque lot avant de copier le job, remettre le compteur à zéro et lancer
le suivant : le GPU restait inactif ~12 ms par lot de ~140 ms sous WSL (24,9 MH/s dans le noyau, 22,9 MH/s en
moyenne). Deux lots sont maintenant en vol : le lot N+1 est mis en file avant d'attendre le lot N (tampons de job,
de hits et de compteur séparés, copies asynchrones depuis la mémoire épinglée). Les calculs GPU sont inchangés.

## v2.0.0
Nouvel affichage récapitulatif (tableau par GPU : hashrate, température, ventilateur, conso, efficacité ;
total, solutions, uptime, nœud) dès ~6 s puis toutes les 30 s ; messages de job / « no job » retirés du log ;
hashrate sur fenêtre glissante de 30 s. Inclut v1.1 (s16s) et v1.2 (pipeline). Binaire RTX 20/30/40/50.
