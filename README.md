# Radiomarker Reaper - Installation rapide

Ce projet ajoute des boutons HTML pour poser des marqueurs Reaper par intervenant (P1 a P4) et type (Erreur, Citation, Note).

## Fichiers utiles

- `podcast_4pistes.html` : interface web des boutons
- `reaper_lua_markers/install_markers_actions.lua` : installe les 12 scripts dans la liste d'actions Reaper
- `reaper_lua_markers/sync_html_command_map.lua` : injecte automatiquement les `Command ID` dans le HTML

## Procedure 

1. Dans Reaper, ouvre la liste des actions (`?`).
2. Lance `ReaScript: Exécuter/éditer ReaScript (EEL2 ou Lua)..` et choisis:
   - d'abord `reaper_lua_markers/install_markers_actions.lua`
   - ensuite `reaper_lua_markers/sync_html_command_map.lua`
3. Ouvre `podcast_4pistes.html` depuis l'interface web Reaper 


