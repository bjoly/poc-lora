# Protocole de test des nœuds capteurs Waspmote (LoRa + GPS + radiation)

On souhaite évaluer 
* L’autonomie
* La précision du GPS
* La portée
Autant que possible, coupler les tests des modules LoRa et ieee 802.15.4 avec des programmes similaires.

## Test fonctionnel sur le campus

Programmer 2 ou 3 nœuds, programme asynchrone sans sommeil, config courte portée, périodicité courte (1min30). Faire un circuit à pied avec les nœuds, en s’arrêtant à certains points définis.

Tests GPS + portée en forêt 
Mission à la journée dans forêt proche (Comté par exemple) ou à Roffin. Si à Roffin, emporter compteur Geiger pour étalonnage relatif.
Programmer 3 nœuds avec le programme asynchrone, périodicité courte (3 min), 3 configs différentes.  

Power level	| Mode	| commentaire
----------------|-------|------------
L		| 10	| courte portée, basse conso
M		| 8	| portée et conso intermédiaires
H	 	| 5	| longue portée, conso max

Etalonnage : mesures longues (vérifier avec le compteur geiger que le débit de dose est uniforme dans une zone, pour y tester n balises).

## Tests d’autonomie, en laboratoire

Programmer les nœuds avec le programme asynchrone (GPS activé mais avec un timeout assez court). Périodicité de mesure : 1 h (5 min comptage).
 


Test sur site de Roffin
Une fois la fonctionnalité établie, déployer les nœuds et les laisser compter qq semaines / mois.
Périodicité = 1h ? 24 h ?
