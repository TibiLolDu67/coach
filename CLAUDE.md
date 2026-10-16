# Coach — appli perso de coaching muscu

## Contexte
Appli web personnelle (un seul utilisateur : Victor) qui centralise ce qui était éparpillé entre Notion (programme), Excel (macros) et les IA : programme, séance du jour avec coaching automatique, suivi du corps, nutrition, coût de l'entraînement.
Objectif : du suivi et de l'interaction, pas un simple journal. L'appli doit rester simple à utiliser (gros boutons, cases à cocher, peu de saisie).
Usage principal : iPhone (installée sur l'écran d'accueil), plus un PC. Toute l'interface est en français.

## Fichiers
- `index.html` : toute l'appli (HTML, CSS, JS dans un seul fichier, sans framework ni étape de build). C'est la source de vérité.
- `sw.js` : service worker (mode hors ligne). **Incrémenter la constante de cache `C` (ex. `cdl-v4` vers `cdl-v5`) à chaque modification de l'appli**, sinon l'iPhone garde l'ancienne version.
- `manifest.webmanifest`, `icon-192.png`, `icon-512.png` : installation sur l'écran d'accueil.
- `poste-controle-muscu.html` (s'il est présent) : ancienne copie autonome sans manifeste ni service worker, à ne plus modifier.

## Architecture du code
- Un objet d'état global `S`, sauvegardé en JSON dans `localStorage` sous la clé `pcm1` via `save()`.
- `render()` reconstruit `#app` en `innerHTML` à partir de fonctions de vue `vXxx()` qui renvoient des chaînes HTML. Toujours passer le texte saisi par l'utilisateur dans `esc()`.
- Clics : un seul écouteur délégué, l'action est dans `data-a` (puis `save(); render()`).
- Saisies : un seul écouteur `change`, le champ est dans `data-k`.
- Navigation : `T` (liste des vues) et `G` (4 onglets de la barre flottante : Accueil, Entraînement, Nutrition, Profil, avec sous-onglets).
- Schéma de `S` : `program[]` (séances avec `exos[]` : name, sets, min, max, charge, step, tip, verdict, why), `history[]`, `draft` (séance en cours), `profile`, `weights[]` ({t, w}), `food{ 'AAAA-MM-JJ': [ {m, n, k, p, g, l, q} ] }` (macros pour 100 g, `q` = coefficient), `favs[]`, `adj` (ajustement kcal du coach), `adjT` (date du dernier ajustement), `cost`, `theme`. Les entrées de `history[].exos[]` portent l'`id` de l'exercice (lien avec le programme).
- Depuis le lot 2 : chaque exercice a `rest` (repos en secondes, 0 = pas de minuteur) et éventuellement `cs[]` (charges par série ; `charge` vaut alors la plus lourde). Dans `draft.x[id]` : `ok[]` (séries cochées) et `cs[]`. `S.rest` = minuteur en cours ({end, tot}), `S.sound` = son de fin de repos. Programme est dans l'onglet Entraînement.
- Depuis le lot 3 : sous-onglet Progrès (`vStats`, 1RM estimé `orm()`, records calculés à la volée par `marks()`, rien de stocké), bilan hebdo `bilanCard()` (dans Corps, et sur l'Accueil le jour d'une pesée), adhérence dans `coach()` via `eaten(n)` (moyenne des jours saisis, aujourd'hui exclu ; écart toléré 5 %, vérifié à partir de 5 jours saisis sur 14).
- Bibliothèque d'aliments (13/10/2026) : `S.lib[]` ({n, k, p, g, l, u} ; `u` = nombre d'utilisations), alimentée par `libAdd()` à chaque ajout dans Jour, proposée en saisie semi-automatique (`sugHtml`, écouteur `input`) et gérée dans Nutrition > Aliments (`vLib`). Courbes kcal / poids / macros dans Nutrition > Historique (`trendCard`, `nchart`, `nser` : jours saisis hors aujourd'hui, moyenne glissante 7 jours ; trois panneaux empilés sur le même axe du temps, jamais de double axe ; couleurs de séries `--s1` à `--s3`).
- Fichier d'ajout : un JSON `{coach:'ajout', food:{date:[...]}, weights:[{d, w}]}` passé à l'import complète les données sans rien écraser (jours de repas absents, pesées absentes, aliments en bibliothèque). C'est ainsi que l'Excel « suivi macro » de Victor a été repris (`ajout-excel.json`, hors git car le dépôt est public : **ne jamais committer de données personnelles**).
- Repas types (lot 4) : `S.tpl[]` ({id, n, m, items[]}), créés par « ★ Repas type » à côté d'un repas du jour, ajoutés en un tap (`tplCard`), renommés et supprimés dans Aliments. Le bandeau flottant du bas s'appelle `#float` : ne pas réutiliser d'id déjà pris par un champ (le champ lipides est `#fl`).
- Synchronisation en ligne (16/10/2026) : Supabase (projet `jadbvtbbwlbnbpvtoqzj`, région Europe), appels `fetch` directs à l'API REST et Auth, sans bibliothèque. Table `public.coach_state` (user_id, data jsonb, rev, device, updated_at) protégée par RLS (chacun sa ligne, aucun accès anonyme, pas de suppression). La clé `sb_publishable_…` est publique par nature ; **ne jamais mettre de clé secret ou service_role dans le code**. `payload()` = données synchronisées et sauvegardées (pas l'onglet, la séance en cours ni le minuteur) ; `setData()` les applique. Session dans `localStorage['pcm1-auth']`, suivi dans `pcm1-sync` ({rev, h = empreinte `hsh()` des données synchronisées, at}). `syncNow()` : envoi seulement si la version en ligne n'a pas bougé (PATCH filtré `rev=eq.`), sinon récupération si rien n'a changé localement, sinon conflit (`SC`, choix « Garder cet appareil » ou « Garder la version en ligne », version écartée gardée dans `pcm1-prev`). Envoi 4 s après une modification (`syncSoon`, appelé par `save()`), synchro à l'ouverture, au retour dans l'appli et au retour du réseau. Carte dans Profil > Données (`syncHtml`), alerte sur l'Accueil (`syncAlert`). Liens reçus par e-mail (confirmation, nouveau mot de passe) traités au chargement via `location.hash`.
- Les migrations sont dans `migrate()` (appelée au chargement et après un import). Les suppressions passent par `undoable()` (bandeau « Annuler » 6 secondes).
- Test en local : `.claude/serve.ps1` sert l'appli sur http://localhost:8123 (nécessaire pour le service worker).
- **Ne jamais casser les données existantes** : toute évolution du schéma passe par une migration au chargement (valeurs par défaut, conversion), jamais par une réinitialisation.

## Règles métier
- Progression (double progression) : toutes les séries au max de la fourchette = AUGMENTER (+palier) ; sous le min deux séances de suite = RÉGRESSER (−palier) ; sinon MAINTENIR. Douleur articulaire = RÉGRESSER (à revoir, voir point 13).
- Corps : BMR Mifflin-St Jeor ; TDEE = BMR × activité + séances × 300 / 7 ; protéines 2 g/kg, lipides 0,9 g/kg, glucides = le reste ; cible jamais sous le BMR.
- Pesée **une fois par semaine** (tendance lissée sur 14 jours, analyse après 3 pesées). Le coach propose ±150 kcal si l'écart à l'objectif dépasse 0,2 kg/sem.
- Nutrition : saisie des macros **pour 100 g puis un coefficient de portion** (comme son Excel : 200 g mangés = coefficient 2). Garder ce fonctionnement.
- Le coach s'appelle « Coach ». Thème clair (défaut) ou sombre au choix dans Profil > Options.

## Design (refonte du 16/10/2026, version précédente sous le repère git `avant-refonte-visuelle`)
- Identité sombre et orange, « appli sportive haut de gamme » : fond `#0B0D0F`, surfaces `#14171A` / `#1D2126`, bordures `#2B3036`, texte `#F5F6F7` / `#A6ADB5`, accent orange `#FF7A2F` (survol `#FF914D`). Le thème clair garde les mêmes formes avec l'accent `#F06A1E`. Tous les tokens sont en tête du `<style>` (`:root` = sombre, `[data-theme=light]` = clair).
- L'orange est réservé aux actions principales, à la sélection, à la progression et aux données importantes. Vert, jaune et rouge gardent leur sens (succès, alerte, erreur) et sont toujours accompagnés d'un libellé.
- Cartes arrondies à 24 px (Plan du jour 28 px), contrôles à 14 px, zones tactiles d'au moins 44 px, transitions de 150 à 180 ms coupées si l'appareil demande moins d'animations. Voyants d'état en pastilles avec point lumineux (touche « salle de contrôle » conservée). Pas de glassmorphism ni de dégradé multicolore.
- Composition (16/10/2026) : chaque page a un en-tête `.ph` (petit « Coach » orange + titre de la section) ; l'Accueil met les actions en premier (Plan du jour, Reprendre la séance, + Repas / + Pesée, séances à démarrer via `sessList()`), puis les chiffres du jour, le Coach et le bilan. Listes en lignes `.li` dans une carte `.list`. Sur ordinateur (≥ 960 px) : barre de navigation en rail vertical à gauche, et `.split` en deux colonnes pour Accueil, Nutrition et Corps (`main.w`).
- Une refonte visuelle ne touche que la présentation : pas de logique, de textes métier, de parcours ni de données.

## Façon de travailler
- Victor débute avec Claude Code : expliquer simplement ce qui a été fait, en français, sans jargon inutile.
- Avancer par petits lots ; après chaque lot, tester l'appli dans un navigateur (ouvrir index.html, cliquer les parcours touchés, vérifier la console) avant de dire que c'est fini.
- Faire un commit git par lot avec un message clair en français.

## Backlog (numéros validés avec Victor)

### Lot 1 : corrections (fait le 09/10/2026, testé sur PC, à valider sur iPhone)
1. Masse grasse Navy : la formule actuelle est celle en pouces alors que la saisie est en cm (surestime d'environ 6,5 points pour un homme, 26 pour une femme). Passer à la formule métrique : homme 495 / (1,0324 − 0,19077·log10(taille − cou) + 0,15456·log10(hauteur)) − 450 ; femme 495 / (1,29579 − 0,35004·log10(taille + hanches − cou) + 0,22100·log10(hauteur)) − 450.
2. Bouton « Appliquer ±150 kcal » cumulable à l'infini : limiter à un ajustement par période de 14 jours (mémoriser la date du dernier ajustement).
3. La sensation (1 à 5) n'est pas utilisée : si toutes les séries sont au max mais sensation ≤ 2, MAINTENIR au lieu d'AUGMENTER.
4. Demander confirmation (ou proposer « Annuler » quelques secondes) avant de supprimer une séance du programme, un exercice, une séance de l'historique, une dépense.
5. L'historique est lié au nom de l'exercice : renommer casse le lien. Lier par l'id de l'exercice (avec migration de l'historique existant).
6. Export : remplacer la copie par `execCommand` par le téléchargement d'un fichier .json (et le menu Partager sur iPhone si dispo) ; import depuis un fichier ; inclure le thème.
7. Rappeler dans Données que l'appli doit être utilisée depuis l'écran d'accueil sur iPhone (stockage séparé de Safari ; Safari peut effacer les données d'un site non ouvert depuis 7 jours).
8. Service worker : passer de « réseau d'abord » à « cache d'abord + mise à jour en arrière-plan » pour une ouverture instantanée avec un mauvais réseau à la salle.
9. Petits bugs : le jour de nutrition reste sur la veille si l'appli est ouverte après minuit ; un aliment ajouté sans valeur crée une ligne « Repas » à 0 kcal.

Puis : hébergement (Cloudflare Pages ou GitHub Pages) et 1 à 2 semaines d'usage réel avant le lot 2.

### Lot 2 : séance (fait le 09/10/2026, testé sur PC, à valider sur iPhone)
10. Déplacer Programme dans Entraînement (sous-onglets Séance, Programme, Historique).
11. Charge par série en option (pyramides, échauffement).
15. Case à cocher pour valider chaque série, qui lance un minuteur de repos (vibration à la fin).

### Lot 3 : coach (fait le 09/10/2026, testé sur PC avec des données fictives, à valider en usage réel)
23. Bilan hebdo automatique le jour de la pesée (séances faites, moyenne kcal vs cible, tendance du poids, exercices en hausse ou en baisse, consigne pour la semaine).
24. Avant d'ajuster les calories, le coach vérifie l'adhérence : si la moyenne mangée s'écarte de la cible, il le dit au lieu de changer la cible.
16. Courbes de progression par exercice, 1RM estimé (Epley) et records personnels (voyant « RECORD »).

### Lot 4 : nutrition (fait le 16/10/2026, testé sur PC, à valider sur iPhone)
20. Bibliothèque d'aliments réutilisables avec recherche. (fait le 13/10/2026, avec la reprise de l'Excel et les courbes de nutrition ; à valider sur iPhone)
22. Repas types (petit-déjeuner habituel en un tap).
14. Afficher « il te reste X kcal et Y g de protéines ».

### Ensuite
- Synchronisation iPhone/PC et sauvegarde en ligne avec Supabase (offre gratuite, serveur en Europe).
- Chatbot intégré : d'abord un bouton « Copier mes données pour Claude » (27), puis un vrai chatbot via l'API avec la clé sur un petit serveur intermédiaire.

### Idées en réserve
12. Planning de la semaine avec jours de repos (l'anneau « Plan du jour » doit pouvoir atteindre 100 % un jour sans séance).
13. Douleur articulaire : demander quoi faire (baisser, changer d'exercice, amplitude réduite) au lieu de baisser automatiquement.
17. Volume hebdo par groupe musculaire. (fait le 16/10/2026 : carte en tête de Progrès, `volCard()`, groupe par exercice `grp` réglable dans Programme, sinon deviné par `guessG()`)
18. Semaine allégée proposée après 6 à 8 semaines ou si plusieurs exercices régressent. (fait le 16/10/2026, adapté au programme de Victor : 8 semaines d'entraînement puis 7 jours sans salle. `S.cycle` = {start, weeks, rest}, carte « Cycle d'entraînement » dans Programme, `cyc()` donne la semaine en cours ; Plan du jour, Coach et bilan en tiennent compte ; le coach suggère d'avancer la semaine sans salle si 3 exercices ou plus régressent)
19. Exercice de remplacement quand la machine est prise.
21. Recherche d'aliments dans Open Food Facts ou Ciqual, éventuellement scan de code-barres.
25. Suivi des mensurations dans le temps (tour de taille).
26. Rappel de sauvegarde si pas d'export depuis 7 jours. (fait le 16/10/2026 : `S.lastExp`, carte sur l'Accueil)
28. Import Notion et Excel : convertir ses fichiers une fois au format de sauvegarde plutôt que coder un importeur. (Excel fait le 13/10/2026 ; Notion reste à faire)
- Arrivée guidée, fiches d'exercices.
