-- UI/OptionsText.lua: the settings pages' own copy, English + Italian. Setting labels live on their
-- definitions (`label` / `ja`: the Italian, under the field name the original Japanese project gave it); everything
-- else the pages say lives here. Addon interface text, not game text: no data/ entry, no provenance. `%s`
-- placeholders appear the same number of times, in the same order, in both. Longer help copy breaks between
-- sentences with "\n" (the same break in both languages) rather than wrapping mid-sentence.
local _, WFI = ...
local Text = {}
WFI.OptionsText = Text

Text.T = {
  ["page.main"] = { en = "WoW Forever Italian", ja = "WoW Forever Italian" },
  ["page.collector"] = { en = "English Collector", ja = "Raccolta testi inglesi" },
  ["page.about"] = { en = "About & Help", ja = "Informazioni e aiuto" },
  ["tagline"] = {
    en = "Italian quest, NPC and tooltip text. Hold a key for the game's English.",
    ja = "Quest, NPC e tooltip in italiano. Tieni premuto un tasto per l'inglese del gioco.",
  },

  ["section.translation"] = { en = "Translation", ja = "Traduzione" },
  ["section.areas"] = { en = "What to translate", ja = "Cosa tradurre" },
  ["section.markers"] = { en = "Markers", ja = "Indicatori" },
  ["section.collector"] = { en = "Collector", ja = "Raccolta" },
  ["section.files"] = { en = "Sending it in", ja = "Come inviarli" },
  ["section.help"] = { en = "How it works", ja = "Come funziona" },
  ["section.slash"] = { en = "Slash commands", ja = "Comandi" },

  ["toggleKey"] = { en = "Turn translation on / off", ja = "Attiva / disattiva la traduzione" },
  ["key.notSet"] = { en = "Not set", ja = "Non impostato" },

  ["button.capture"] = { en = "Change", ja = "Cambia" },
  ["button.capturing"] = { en = "Press a key", ja = "Premi un tasto" },
  ["button.setKey"] = { en = "Set key", ja = "Imposta tasto" },
  ["button.unbind"] = { en = "Unbind", ja = "Rimuovi" },
  ["button.replace"] = { en = "Replace", ja = "Sostituisci" },
  ["button.settings"] = { en = "Settings", ja = "Impostazioni" },

  ["warn.takeover"] = {
    en = "%s is used for \"%s\". While this addon is loaded, %s shows English instead.",
    ja = "%s è assegnato a \"%s\". Finché questo addon è attivo, %s mostra invece l'inglese.",
  },
  ["warn.toggleConflict"] = {
    en = "%s is already the key for turning translation on / off.",
    ja = "%s è già il tasto per attivare / disattivare la traduzione.",
  },
  ["warn.revealConflict"] = {
    en = "%s is already the key for showing English.",
    ja = "%s è già il tasto per mostrare l'inglese.",
  },
  ["warn.bindReplace"] = { en = "%s is used for \"%s\". Replace it?", ja = "%s è assegnato a \"%s\". Sostituirlo?" },
  ["warn.combat"] = { en = "Keys can't be changed in combat.",
    ja = "I tasti non si possono cambiare in combattimento." },
  ["warn.afterCombat"] = { en = "%s takes effect after combat.", ja = "%s avrà effetto dopo il combattimento." },
  ["warn.addonChanges"] = {
    en = "Apply or cancel your AddOn changes first.",
    ja = "Prima applica o annulla le modifiche agli AddOn.",
  },

  ["collector.explain"] = {
    en = "The addon notes English it has no translation for.\n"
      .. "Nothing is sent anywhere unless you send it yourself with the steps below.",
    ja = "L'addon annota il testo inglese che non ha ancora una traduzione.\n"
      .. "Non viene inviato niente, a meno che tu non lo invii con i passi qui sotto.",
  },
  ["collector.status"] = { en = "Status", ja = "Stato" },
  -- the status line in the page's language (the slash command keeps Collector.describe's English)
  ["collector.statusLine"] = { en = "%s · %s entries · %s of %s", ja = "%s · %s voci · %s di %s" },
  ["collector.on"] = { en = "on", ja = "attiva" },
  ["collector.off"] = { en = "off", ja = "disattivata" },
  ["collector.full"] = { en = "full", ja = "piena" },
  ["collector.paused"] = { en = "paused (file from a newer version)",
    ja = "in pausa (file di una versione più recente)" },
  ["collector.errors"] = { en = "%s errors", ja = "%s errori" },
  ["collector.path"] = {
    en = "Too long to paste? Zip this file and attach it to the same issue:",
    ja = "Troppo lungo da incollare? Comprimi questo file in zip e allegalo alla stessa issue:",
  },
  ["collector.steps"] = {
    en = "1. Click Send English.\n"
      .. "2. Copy the link in the window (click it, then Ctrl+C) and open it in your web browser.\n"
      .. "3. If the window shows a second box, copy that text into the form's box too.\n"
      .. "4. Submit the issue on GitHub, then click I sent it.",
    ja = "1. Clicca \"Invia l'inglese\".\n"
      .. "2. Copia il link nella finestra (cliccalo, poi Ctrl+C) e aprilo nel browser.\n"
      .. "3. Se la finestra mostra un secondo riquadro, copia anche quel testo nel modulo.\n"
      .. "4. Invia la issue su GitHub, poi clicca \"Inviato\".",
  },
  ["collector.send"] = { en = "Send English", ja = "Invia l'inglese" },
  ["send.title"] = { en = "Send collected English", ja = "Invia l'inglese raccolto" },
  ["send.summary.empty"] = {
    en = "Nothing new to send. /wfi collector send all sends every line again.",
    ja = "Niente di nuovo da inviare. /wfi collector send all invia di nuovo ogni riga.",
  },
  ["send.summary.unavailable"] = {
    en = "This game client cannot pack the text, so the saved file goes with the issue instead.",
    ja = "Questo client non riesce a impacchettare il testo: allega invece il file salvato alla issue.",
  },
  ["send.summary.readonly"] = {
    en = "The saved file is from a newer version of the addon. Update the addon to send it.",
    ja = "Il file salvato è di una versione più recente dell'addon. Aggiorna l'addon per inviarlo.",
  },
  ["send.summary"] = {
    en = "%s lines to send in one issue (%s already in Italian, left out).",
    ja = "%s righe da inviare in una issue (%s già in italiano, escluse).",
  },
  ["send.step1"] = {
    en = "1. Copy this link (click it, then Ctrl+C) and open it in your web browser:",
    ja = "1. Copia questo link (cliccalo, poi Ctrl+C) e aprilo nel browser:",
  },
  ["send.step2.link"] = { en = "2. The form opens filled in.", ja = "2. Il modulo si apre già compilato." },
  ["send.step2.paste"] = {
    en = "2. Copy this text too (click it, then Ctrl+C) and paste it into the form:",
    ja = "2. Copia anche questo testo (cliccalo, poi Ctrl+C) e incollalo nel modulo:",
  },
  ["send.step2.file"] = {
    en = "2. Zip this file and drag it into the form (/reload first saves it):",
    ja = "2. Comprimi questo file in zip e trascinalo nel modulo (prima /reload per salvarlo):",
  },
  ["send.step3"] = { en = "3. Submit the issue on GitHub.", ja = "3. Invia la issue su GitHub." },
  ["send.step4"] = { en = "4. Then click:", ja = "4. Poi clicca:" },
  ["send.sent"] = { en = "I sent it", ja = "Inviato" },
  ["send.later"] = {
    en = "%s new lines are not in the file yet: /reload, then open this again.",
    ja = "%s righe nuove non sono ancora nel file: fai /reload e riapri questa finestra.",
  },
  ["send.markedFull"] = {
    en = "%s lines marked as sent. Full: Clear collected English makes room.",
    ja = "%s righe segnate come inviate. Raccolta piena: \"Cancella l'inglese raccolto\" fa spazio.",
  },
  ["send.marked"] = {
    en = "%s lines marked as sent. The next send holds only new lines.",
    ja = "%s righe segnate come inviate. Il prossimo invio conterrà solo righe nuove.",
  },
  -- the report window (UI/ReportWindow): a bug or an idea; its link and I sent it reuse send.step1 / step4 / sent
  ["report.title"] = { en = "Report a bug or an idea", ja = "Segnala un bug o un'idea" },
  ["report.bug"] = { en = "Bug", ja = "Bug" },
  ["report.idea"] = { en = "Idea", ja = "Idea" },
  ["report.summary.errors"] = {
    en = "%s new Lua errors from this addon go with the report.",
    ja = "Con la segnalazione vanno %s nuovi errori Lua di questo addon.",
  },
  ["report.summary.none"] = {
    en = "No new Lua errors from this addon. Build and version go with it.",
    ja = "Nessun nuovo errore Lua di questo addon. Vanno build e versione.",
  },
  ["report.summary.other"] = {
    en = "Another addon (BugSack or similar) catches Lua errors: paste ours from it.",
    ja = "Un altro addon (es. BugSack) cattura gli errori Lua: copia da lì i nostri.",
  },
  ["report.summary.idea"] = {
    en = "Ideas and code changes go to GitHub.",
    ja = "Idee e modifiche al codice vanno su GitHub.",
  },
  ["report.step2.link"] = {
    en = "2. The form opens with build, version and errors filled in.",
    ja = "2. Il modulo si apre con build, versione ed errori già compilati.",
  },
  ["report.step2.paste"] = {
    en = "2. Copy this text (click, Ctrl+C) into the form's Lua errors box:",
    ja = "2. Copia questo testo (clic, Ctrl+C) nel campo errori Lua del modulo:",
  },
  ["report.step3"] = {
    en = "3. Write what happened, then submit the issue on GitHub.",
    ja = "3. Scrivi cosa è successo, poi invia la issue su GitHub.",
  },
  ["report.idea.step2"] = {
    en = "2. Write your idea, then submit the issue on GitHub.",
    ja = "2. Scrivi la tua idea, poi invia la issue su GitHub.",
  },
  ["report.marked"] = {
    en = "%s errors marked as sent. The next report holds only new ones.",
    ja = "%s errori segnati come inviati: la prossima volta solo quelli nuovi.",
  },
  ["about.bug"] = {
    en = "Something not working, or an idea? Send it from here.",
    ja = "Qualcosa non funziona, o hai un'idea? Invialo da qui.",
  },
  ["button.reportBug"] = { en = "Report a bug or idea", ja = "Segnala bug o idea" },
  ["collector.clear"] = { en = "Clear collected English", ja = "Cancella l'inglese raccolto" },
  ["collector.confirm"] = { en = "Click again to clear %s entries", ja = "Clicca ancora per cancellare %s voci" },
  ["collector.cleared"] = { en = "Cleared %s entries", ja = "Cancellate %s voci" },

  ["about.open"] = {
    en = "Open settings: Esc > Options > AddOns  /  the AddOn List's \"Settings\"  /  /wfi config",
    ja = "Aprire le impostazioni: Esc > Opzioni > AddOn  /  \"Impostazioni\" nell'elenco AddOn  /  /wfi config",
  },
  -- %s: the reveal key's name ("Alt", "Mouse Button 4")
  ["about.hold"] = {
    en = "Hold %s to see the game's own English; let go to return to Italian.",
    ja = "Tieni premuto %s per vedere l'inglese originale del gioco; rilascia per tornare all'italiano.",
  },
  -- %s, %s: the two markers as they show (WFI.MARKER.stale, .missing)
  ["about.markers"] = {
    en = "%s  the English changed after translation.\n%s  this line has no translation yet.",
    ja = "%s  l'inglese è cambiato dopo la traduzione.\n%s  questa riga non ha ancora una traduzione.",
  },
  -- the line under a page title: version, memory, how much data ships
  ["header.data"] = { en = "data: %s quests · %s items · %s spells · %s UI strings",
    ja = "dati: %s quest · %s oggetti · %s spell · %s testi dell'interfaccia" },
  ["header.noData"] = { en = "data: none", ja = "dati: nessuno" },
  ["header.noMemory"] = { en = "memory n/a", ja = "memoria n/d" },

  -- the fix window (UI/FixWindow) and the About page's way into it
  ["about.fix"] = {
    en = "Spotted a wrong or awkward line? Pick it from the lines you just saw.",
    ja = "Hai visto una riga sbagliata o poco naturale? Sceglila tra quelle appena mostrate.",
  },
  ["button.reportLine"] = { en = "Report a line", ja = "Segnala una riga" },
  ["fix.title"] = { en = "Report a translation", ja = "Segnala una traduzione" },
  ["fix.tab.recent"] = { en = "Translations", ja = "Traduzioni" },
  ["fix.tab.pending"] = { en = "Pending (%s)", ja = "In attesa (%s)" },
  ["fix.tab.copy"] = { en = "Send report", ja = "Invia segnalazione" },
  ["fix.recent.explain"] = {
    en = "Lines shown this session, newest first. Click the one to report.",
    ja = "Righe mostrate in questa sessione, dalla più recente. Clicca quella da segnalare.",
  },
  ["fix.filter.story"] = { en = "Quests & NPCs", ja = "Quest e NPC" },
  ["fix.filter.tooltips"] = { en = "Tooltips", ja = "Tooltip" },
  ["fix.filter.windows"] = { en = "Windows", ja = "Finestre" },
  ["fix.filter.all"] = { en = "All", ja = "Tutto" },
  ["fix.recent.empty"] = {
    en = "Nothing yet. Read some quest or NPC text, then open this again.",
    ja = "Ancora niente. Leggi qualche testo di quest o di NPC, poi riapri questa finestra.",
  },
  ["fix.edit.reason"] = { en = "What is wrong?", ja = "Cosa c'è che non va?" },
  ["fix.edit.note"] = { en = "Note (optional)", ja = "Nota (facoltativa)" },
  ["fix.edit.ja"] = { en = "The line. Rewrite it if you like (optional)",
    ja = "La riga. Riscrivila se vuoi (facoltativo)" },
  ["reason.wrong"] = { en = "Wrong meaning", ja = "Significato sbagliato" },
  ["reason.awkward"] = { en = "Awkward / unnatural", ja = "Italiano poco naturale" },
  ["reason.typo"] = { en = "Typo / broken text", ja = "Refuso / testo rovinato" },
  ["reason.name"] = { en = "A name was changed", ja = "Un nome è stato cambiato" },
  ["reason.other"] = { en = "Other", ja = "Altro" },
  ["button.saveFix"] = { en = "Save", ja = "Salva" },
  ["button.back"] = { en = "Back", ja = "Indietro" },
  ["button.delete"] = { en = "Delete", ja = "Elimina" },
  ["button.clearSent"] = { en = "Clear sent reports", ja = "Cancella le segnalazioni inviate" },
  ["fix.saved"] = { en = "Saved. Send it from Send report.", ja = "Salvata. Inviala da \"Invia segnalazione\"." },
  ["fix.unavailable"] = {
    en = "Saving is unavailable: the addon's saved settings did not load. Try /reload.",
    ja = "Impossibile salvare: le impostazioni salvate dell'addon non si sono caricate. Prova /reload.",
  },
  ["fix.noReason"] = { en = "Pick what is wrong first.", ja = "Prima scegli cosa c'è che non va." },
  ["fix.exists"] = {
    en = "This line is already saved. Click again to replace it.",
    ja = "Questa riga è già salvata. Clicca ancora per sostituirla.",
  },
  ["fix.full"] = {
    en = "%s reports are waiting. Send them and clear them first.",
    ja = "%s segnalazioni in attesa. Prima inviale e cancellale.",
  },
  ["fix.tooLong"] = { en = "The note or your version is too long.", ja = "La nota o la tua versione è troppo lunga." },
  ["fix.deleted"] = { en = "Deleted.", ja = "Eliminata." },
  ["fix.pending.explain"] = {
    en = "Saved reports, kept until you clear them. Click one to change or delete it.",
    ja = "Segnalazioni salvate, conservate finché non le cancelli. Clicca per modificarle o eliminarle.",
  },
  ["fix.pending.empty"] = { en = "Nothing saved yet.", ja = "Nessuna segnalazione salvata." },
  ["fix.copy.step1"] = {
    en = "1. Open the report form: click the address, Ctrl+C, paste it into your browser.",
    ja = "1. Apri il modulo: clicca l'indirizzo, Ctrl+C, incollalo nel browser.",
  },
  ["fix.copy.step2"] = {
    en = "2. Copy the report: click it (it selects itself), then Ctrl+C.",
    ja = "2. Copia la segnalazione: cliccala (si seleziona da sola), poi Ctrl+C.",
  },
  ["fix.copy.step3"] = {
    en = "3. Paste the report into the form's Report box and submit it.",
    ja = "3. Incolla la segnalazione nel riquadro \"Report\" del modulo e inviala.",
  },
  ["fix.copy.step4"] = {
    en = "4. Sent? Clear the reports you sent:",
    ja = "4. Inviata? Cancella le segnalazioni inviate:",
  },
  ["fix.copy.empty"] = {
    en = "Nothing to send yet. In Translations, click a line, choose what is wrong and click Save.",
    ja = "Ancora niente da inviare. In \"Traduzioni\" clicca una riga, scegli cosa non va e clicca \"Salva\".",
  },
  ["fix.clear.confirm"] = { en = "Click again to clear %s reports",
    ja = "Clicca ancora per cancellare %s segnalazioni" },
  ["fix.cleared"] = { en = "Cleared %s reports", ja = "Cancellate %s segnalazioni" },
  ["type.quest"] = { en = "Quest", ja = "Quest" },
  ["type.gossip"] = { en = "NPC talk", ja = "Dialogo NPC" },
  ["type.item"] = { en = "Item", ja = "Oggetto" },
  ["type.spell"] = { en = "Spell", ja = "Spell" },
  ["type.book"] = { en = "Book", ja = "Libro" },
  ["type.ui"] = { en = "Window text", ja = "Testo delle finestre" },
  ["type.objective"] = { en = "Objective", ja = "Obiettivo" },
  ["type.area"] = { en = "Area objective", ja = "Obiettivo di zona" },
  ["minimap.tip"] = {
    en = "Left-click: report a line · Right-click: menu",
    ja = "Clic sinistro: segnala una riga · Clic destro: menu",
  },
  ["minimap.enabled"] = { en = "Translation on", ja = "Traduzione attiva" },
  ["minimap.hide"] = { en = "Hide this button", ja = "Nascondi questo pulsante" },
  ["reminder.title"] = { en = "Untranslated English", ja = "Inglese non tradotto" },
  ["reminder.saved"] = { en = "While you played, the addon collected %s English lines it has no translation for.",
    ja = "Mentre giocavi, l'addon ha raccolto %s righe in inglese che non hanno ancora una traduzione." },
  ["reminder.ask"] = { en = "Send them in and they will be translated in a future update.",
    ja = "Inviale e verranno tradotte in un prossimo aggiornamento." },
  ["reminder.send"] = { en = "Send English", ja = "Invia l'inglese" },
  ["reminder.later"] = { en = "Later", ja = "Più tardi" },
  ["reminder.stop"] = { en = "Don't remind me again", ja = "Non ricordarmelo più" },
  -- the intro window a first install shows once (UI/IntroWindow): an Italian block above an English one, each point
  -- short enough for one line in its block; %s in intro.hold is the reveal key's name
  ["intro.lead"] = { en = "Quest text, NPC talk and tooltips now show in Italian.",
    ja = "Testi delle quest, dialoghi degli NPC e tooltip ora sono in italiano." },
  ["intro.hold"] = { en = "Hold %s to see the game's English.",
    ja = "Tieni premuto %s per vedere l'inglese del gioco." },
  ["intro.minimap"] = { en = "Minimap button: left-click to report a line, right-click for the menu.",
    ja = "Pulsante della minimappa: clic sinistro per segnalare una riga, clic destro per il menu." },
  ["intro.close"] = { en = "Close", ja = "Chiudi" },
  ["minimap.sendEnglish"] = { en = "Send collected English (%s)", ja = "Invia l'inglese raccolto (%s)" },
  ["minimap.version"] = { en = "Version %s", ja = "Versione %s" },
  ["minimap.collected"] = { en = "The collector has %s lines we need. Right-click to send them.",
    ja = "La raccolta ha %s righe che ci servono. Clic destro per inviarle." },
}

-- Slash reference on the About page (English: it is the literal grammar, like the chat output).
-- Every top-level verb of UI/Slash and every debug sub-verb (options_spec checks the list).
Text.SLASH = {
  "/wfi  (status)  ·  /wfi on | off | toggle  ·  /wfi version",
  "/wfi modifier <key>  (alt, lalt, button4, q …)",
  "/wfi togglekey [<key> | none]  (f5, ctrl-j …)",
  "/wfi area quests off  ·  /wfi marker missing on",
  "/wfi config [collector | about]  ·  /wfi fix  (report a line)",
  "/wfi bug  (report a bug or an idea)",
  "/wfi collector [on | off | status | path | clear | send [all]]",
  "/wfi log [<n>]  (the problem log)  ·  /wfi taint  (action-bar taint scan)",
  "/wfi debug [hash | quest <id> | item <id> | spell <id>]",
  "/wfi debug [gossip | book | objective | fonts | ui [scan]]",
  "/wfi debug tooltip [on | off]  (record spell / item tooltip passes)",
}

-- the translation-report issue form the fix window's report is pasted into
Text.FIX_URL = "https://github.com/Dade9854/wow-forever-italian/issues/new?template=translation-report.yml"

-- → en, ja; a missing key raises (a typo must fail the spec, not ship a blank).
function Text.get(key, ...)
  local t = Text.T[key]
  assert(t, "OptionsText: no copy for " .. tostring(key))
  if select("#", ...) == 0 then return t.en, t.ja end
  return t.en:format(...), t.ja:format(...)
end
