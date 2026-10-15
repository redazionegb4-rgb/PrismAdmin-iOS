# Prism Admin iOS 1.1.2 — avvio con UIScene

Il rapporto di crash della versione 1.1.1, build 7 mostra SIGTRAP nel controllo UIKit `UIApplicationEvaluateRuntimeIssueForNoSceneLifecycleAdoption`. Il progetto precedente creava la finestra nel vecchio AppDelegate e non dichiarava UIScene.

Correzione: manifest delle scene in Info.plist, AdminSceneDelegate con UIWindow(windowScene:), finestra e navigazione gestite dalla scena, timer di registrazione push associato all'attivazione della scena. Le notifiche toccate all'avvio vengono inoltrate al pannello una volta disponibile, evitando aperture duplicate. Firebase, bundle, firma, Package.resolved e permessi push sono conservati.

1. Sostituisci i file del repository privato Prism Admin con il contenuto di questo progetto, inclusi Info.plist, AppDelegate.swift, Config e il workspace condiviso dentro PrismAdmin.xcodeproj.
2. Esegui Commit e Push.
3. Avvia Xcode Cloud sul nuovo commit, target/schema PrismAdmin.
4. Installa la nuova versione da TestFlight sopra la precedente e verifica apertura, login e apertura da notifica.

Versione 1.1.2, build locale 8; Xcode Cloud usa il proprio progressivo. Non occorrono modifiche al backend o all'APK Android già forniti.

Verifiche locali: collegamento del manifest alla classe compilata, singola finestra tramite UIWindowScene, assenza del vecchio avvio da UIScreen, conservazione di Firebase e delle dipendenze bloccate, plist validi e riferimenti del progetto coerenti. La compilazione iOS e il test sul dispositivo richiedono Xcode Cloud/TestFlight; non sono stati eseguiti in questo ambiente.
