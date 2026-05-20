# Radiomarker Reaper - Installation rapide

Ce projet ajoute des boutons HTML pour poser des marqueurs Reaper par intervenant (P1 à P4) et type (Erreur, Citation, Note).

## Installation Windows (recommandée)

1. Compiler l’installeur : ouvre [`installer/RadiomarkerSetup.iss`](installer/RadiomarkerSetup.iss) dans **Inno Setup 6** puis *Build → Compile*. L’exécutable sort dans `dist/RadiomarkerSetup.exe`.
2. Lance `RadiomarkerSetup.exe`. Indique le **dossier ressources REAPER** :
   - installation classique : en général `%APPDATA%\REAPER` (proposé par défaut) ;
   - **REAPER portable** : le dossier de données de cette copie (celui où REAPER lit/écrit `Scripts`).
3. L’installeur copie les fichiers sous `Scripts\Radiomarker\` et fusionne `Scripts\__startup.lua` sans écraser un fichier existant : il ajoute un bloc marqué `Radiomarker bootstrap (installer)` une seule fois.
4. Au prochain lancement de REAPER, les scripts sont enregistrés et le HTML est synchronisé **sans fenêtres de réussite** (mode silencieux). En cas d’erreur, les messages s’affichent toujours.
5. Ouvre `podcast_4pistes.html` depuis l’interface web REAPER (option : raccourci Bureau si tu l’as coché à l’installation).

## Installation manuelle (sans installeur)

Place le dossier du projet (ou au minimum `reaper_lua_markers/` et `podcast_4pistes.html`) de façon à garder la structure : un répertoire parent contenant `reaper_lua_markers\` et `podcast_4pistes.html` au même niveau (comme dans ce dépôt).

Ensuite dans REAPER :

1. Ouvre la liste des actions (`?`).
2. Lance `ReaScript: Exécuter/éditer ReaScript (EEL2 ou Lua)..` et choisis :
   - d’abord `reaper_lua_markers/install_markers_actions.lua` ;
   - ensuite `reaper_lua_markers/sync_html_command_map.lua`.
3. Pour le démarrage automatique comme avec l’installeur, ajoute dans `Scripts\__startup.lua` l’appel décrit dans l’installeur (bloc `Radiomarker bootstrap (installer)`), ou lance une fois `reaper_lua_markers/radiomarker_bootstrap.lua` depuis un script de démarrage existant.

## Fichiers utiles

- `podcast_4pistes.html` : interface web des boutons
- `reaper_lua_markers/install_markers_actions.lua` : enregistre les scripts dans la liste d’actions
- `reaper_lua_markers/sync_html_command_map.lua` : injecte les `Command ID` dans le HTML
- `reaper_lua_markers/radiomarker_bootstrap.lua` : enchaîne install + sync en mode silencieux (utilisé au démarrage REAPER)
