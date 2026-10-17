# ATX Panel iOS — Build 1 (SwiftUI nativa)

Progetto iniziale iOS **senza WebView**. Usa le API PHP AtlantiX esistenti.

## Installazione

1. Caricare `server_optional/csrf.php` nel server come `api/mobile/csrf.php` (creare la cartella `mobile`). Non modificare `config.php`.
2. Caricare l'intera cartella `ATXPanel_iOS` su GitHub e aprire `ATXPanel.xcodeproj` su Xcode/Xcloud.
3. Selezionare il proprio Team di firma in Signing & Capabilities, impostare un bundle identifier disponibile e compilare su iPhone.

## Funzioni presenti

Login username/password/codice AtlantiX con sessione PHP e CSRF, dashboard, elenco linee (prime 50 + ricerca), connessioni, reseller, movimenti crediti, logout. Le liste sono **in sola lettura** in questa build. Nessuna password o codice è salvato in UserDefaults o inserito nel sorgente.

## Limiti e verifiche

- Non testato su un server autenticato né compilato con Xcode in questo ambiente. La compatibilità effettiva richiede test su Xcloud.
- Se il server richiede 2FA per un account, questa build lo segnala ma non implementa il secondo passaggio.
- I permessi restano applicati dalle API server, non dal client.
- Le schermate di creazione/rinnovo/modifica sono previste per la build successiva dopo test delle operazioni in ambiente sicuro.
- Non caricare file di configurazione NXT o segreti nell'app.
- La funzione `api/auth/logout.php` effettua redirect: URLSession segue il redirect e la sessione viene invalidata lato server.
