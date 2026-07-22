# AYS3 — émulation PS3 sur iOS (RPCS3) : faisabilité & plan étagé

> Statut : **spike R&D**. Ce document pose les faits vérifiés et un plan de
> dé-risquage étagé. Il ne prétend pas qu'un émulateur PS3 jouable sur iOS
> existe aujourd'hui — il cadre le travail pour que chaque échec arrive **tôt
> et pas cher**.

## Décision de départ

Objectif : émulation PS3 sur iOS via **RPCS3** (github.com/RPCS3/rpcs3), en
réutilisant le savoir-faire d'AYS2 (JIT iOS via StikDebug, design system,
biblio de jeux, jaquettes). Choix explicite du user : **application séparée
« AYS3 »**, pas une fusion dans AYS2.

## Pourquoi AYS3 doit être une app SÉPARÉE (contrainte de licence)

- **RPCS3** est sous **GPL-2.0-only**.
- **AYS2** (base PCSX2) est sous **GPL-3.0-or-later**.
- GPL-2.0-only et GPL-3.0 sont **mutuellement incompatibles** : on ne peut pas
  lier les deux dans **un même binaire**. « Mettre le core PS3 dans AYS2 » =
  un seul binaire = **violation de licence**, donc non distribuable.
- Conséquence : AYS3 est un **binaire distinct**, bâti depuis RPCS3, qui
  **réutilise nos idées** (JIT, UI SwiftUI) en les **réécrivant**, sans jamais
  linker de code PCSX2 (GPLv3) avec du code RPCS3 (GPLv2). Toute UI partagée
  doit être re-implémentée côté AYS3, pas importée d'AYS2.

## Faits vérifiés (recherche)

**Côté RPCS3 :**
- **ARM64 natif** depuis décembre 2024 (Linux/macOS/Windows ARM, Apple
  Silicon). Le recompileur JIT LLVM (PPU/SPU) sait viser l'ARM64 — donc
  l'architecture CPU n'est PAS le mur.
- Rendu via **Vulkan → MoltenVK** sur Apple (pas de Metal natif) ou OpenGL 4.3.
- **RAM : 8 Go minimum, 16 Go recommandés** côté hôte. C'est le mur principal
  sur iOS (voir ci-dessous).
- L'équipe RPCS3 **refuse officiellement** iOS/Android et interdit le sujet ;
  il existe seulement une **alpha Android expérimentale** très récente,
  **rien pour iOS**. Aucune toolchain iOS n'existe dans leur build.
- Build : projet CMake massif, nombreux submodules (LLVM, Vulkan headers,
  FFmpeg, etc.). Ce n'est pas « échanger un core », c'est vendoriser un second
  émulateur complet avec son propre système de build.

**Le mur iOS (indépendant de la licence) :**
1. **Mémoire.** iOS tue une app (jetsam) autour de **2–4 Go** même sur un
   appareil 8 Go. RPCS3 vise 8–16 Go. → OOM/crash sur la quasi-totalité des
   appareils. Seuls des iPad M-series à forte RAM auraient une chance, et
   encore, sous la limite jetsam par app.
2. **Performance.** L'émulation PS3 sature déjà des Mac M-series **ventilés**.
   Sur ARM mobile passif, la majorité des titres seraient injouables.
3. **JIT.** RPCS3 mappe de gros segments exécutables (W^X) pour les recompileurs
   PPU/SPU. Notre handshake StikDebug donne du RWX, mais l'appétit mémoire
   exécutable de RPCS3 est bien supérieur à celui de PCSX2, ce qui compose avec
   le mur RAM.

**Conclusion honnête de faisabilité :** un AYS3 *jouable* sur iphone/ipad grand
public n'est pas atteignable aujourd'hui. Le travail a de la valeur comme
**recherche** (prouver ce qui build/boot, documenter les murs), pas comme
produit fini. On avance donc par phases avec un point d'arrêt net à chacune.

## Plan étagé (chaque phase = point d'arrêt / go-no-go)

### Phase 0 — Ce document + squelette de repo (fait ici)
Poser les faits et l'architecture. Aucun code émulateur. Livrable : ce fichier.

### Phase 1 — Dé-risquer la TOOLCHAIN (le vrai premier inconnu)
Prouver qu'on peut **cross-compiler RPCS3 (ou même juste son cœur) pour iОS
arm64** dans notre pipeline, isolé, sans rien casser.
- Repo/branche AYS3 séparés ; vendoriser RPCS3 (submodule).
- Écrire une **toolchain CMake iOS** pour RPCS3 (elle n'existe pas chez eux :
  ils n'ont que macOS). Cibler `arm64-apple-ios`, MoltenVK au lieu de Vulkan
  loader desktop.
- Critère de succès **binaire** : un objet/lib RPCS3 cœur qui *compile* pour
  iOS arm64 en CI. Pas de boot, pas d'UI — juste la preuve que ça build.
- **Si ça échoue** (deps incompatibles iOS, MoltenVK, LLVM cross) → on s'arrête,
  coût perdu minimal.

### Phase 2 — Boot sans écran (headless)
Faire **initialiser** la VM RPCS3 sur un device (firmware PS3 requis côté
user, comme le BIOS PS2), sans rendu, en mesurant la RAM. But : savoir si le
jetsam nous tue avant même le premier jeu. Go-no-go sur la RAM réelle.

### Phase 3 — Rendu MoltenVK + un premier homebrew
Brancher le rendu Vulkan→MoltenVK et tenter un **homebrew PS3 léger** (pas un
AAA). Mesure perf réelle.

### Phase 4 — Coque AYS3 (UI SwiftUI ré-écrite) + biblio/jaquettes PS3
Seulement si 1–3 passent : réécrire une UI façon AYS2 (indépendante, pas
importée), biblio de jeux PS3, téléchargement de jaquettes PS3 (sources de
covers PS3 dédiées).

## Prochaine action concrète

Démarrer **uniquement la Phase 1** dès accord : créer le repo/branche AYS3,
vendoriser RPCS3, écrire la toolchain iOS arm64, tenter un build CI isolé.
On s'arrête et on fait le point avant la Phase 2. Le reste attend le résultat
de la Phase 1 — c'est là que se joue le premier « ça passe / ça casse ».

## Vérification

- Phase 1 : CI verte sur le build cœur RPCS3 pour iOS arm64 = critère net.
- Aucune vérif sur device possible dans cette session (pas de Mac ni d'appareil
  de test) — la confirmation finale reste côté user via sideload, comme pour
  tout AYS2.
