# 🛠️ MP4-Repair-Tool

> **⚠️ Prerequisiti:** PowerShell 7 o superiore, e **FFmpeg** o **Untrunc** (scaricabile automaticamente dallo script).

Un tool con interfaccia grafica (GUI Matrix) per riparare file MP4 danneggiati. 
Include una **modalità speciale per i video scaricati da X (Twitter)**, che usa Untrunc e un file di riferimento sano per recuperare l'intero contenuto del video, aggirando i problemi di indice corrotto che affliggono i file di X.

## ✨ Caratteristiche
- **Doppia Modalità:** Riparazione standard con FFmpeg e recupero avanzato X/Twitter con Untrunc.
- **Auto-Download:** Scarica automaticamente Untrunc se non lo trova.
- **Verifica Qualità:** Controlla che i file recuperati da Untrunc abbiano la stessa dimensione degli originali (scarta quelli incompleti).
- **Fallback Intelligente:** Se Untrunc non è disponibile o fallisce, usa FFmpeg come piano B.
- **GUI Matrix:** Riepilogo finale con colori ad alto contrasto.

## 🚀 Come si usa
1. Avvia lo script: `.\MP4-Repair-Tool.ps1`
2. Seleziona la cartella con i video.
3. Scegli la modalità (**Standard** o **X/Twitter**).
4. Se scegli X/Twitter, seleziona un video "sano" di riferimento (scarica un video da X che funziona bene e usalo come modello).
5. Attendi e controlla il riepilogo finale.

---
*Creato da Fabrizio per il progetto [Fabry Toolbox](https://github.com/fabrytoolbox).*
