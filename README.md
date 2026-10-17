# Prism Admin 2.1.2 — iOS nativo

Interfaccia SwiftUI, API URLSession, sessione in Keychain, notifiche Firebase/APNs.
Bundle identifier: app.prism.admin. Team: B8SC92LPR5. iOS minimo: 16.

## Aggiornamento Xcode Cloud
1. Nel repository PRIVATO già collegato a PrismAdmin, sostituisci il progetto con tutti i file di questa cartella. Mantieni la struttura: PRISM, Config, ci_scripts e PrismAdmin.xcodeproj sono affiancati alla radice.
2. Rimuovi i vecchi PRISM/PrismViewController.swift e PRISM/LocalAccount.swift. Non sono più referenziati dal progetto.
3. Includi nel commit il workspace condiviso e Package.resolved dentro PrismAdmin.xcodeproj; Firebase è fissato alla versione 11.15.0.
4. Avvia il workflow esistente Xcode Cloud, con lo scheme PrismAdmin e la distribuzione TestFlight per il tuo account.
5. Versione 2.1.2; build locale 11, sostituita dal numero progressivo CI_BUILD_NUMBER in Xcode Cloud.

L’identificativo dell’app, il file GoogleService-Info.plist e la capability push sono gli stessi della precedente app admin. Accedi con le credenziali del pannello; la precedente sessione WebView non viene trasferita. La nuova sessione è protetta in Keychain e scade secondo la durata definita dal server (8 ore).

## Controlli sul dispositivo
Apri l’app a freddo; accedi; apri e modifica un profilo; verifica una foto; rispondi a un ticket. Porta l’app in background e prova le notifiche di assistenza, foto e segnalazioni, controllando anche l’apertura della sezione giusta.

Il progetto è stato controllato staticamente in questo ambiente, che non dispone di macOS/Xcode. Non è incluso un IPA firmato e non è stato eseguito un test su iPhone. La compilazione Xcode Cloud e la prova TestFlight restano necessarie.

## Badge profili
Richiede il backend 0.4.20. Apri Badge oppure la scheda utente per assegnazione, revoca e visibilità Extra. Verificato richiede una verifica reale confermata dal titolare.
