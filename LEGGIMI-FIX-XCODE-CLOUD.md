# Prism Admin iOS 1.1.1 — correzione Xcode Cloud

Corretto il file mancante Package.resolved per Firebase 11.15.0 e le sue dipendenze. Aggiunto il workspace condiviso del progetto. App e push mantengono la configurazione precedente.

1. Estrai questo ZIP e copia il contenuto di PrismAdmin-iOS nel repository privato della sola app Admin, sovrascrivendo i file precedenti.
2. Verifica che il commit includa il file:
   PrismAdmin.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
3. Esegui Commit e Push. Avvia il workflow sul NUOVO commit. Ricreare la build sul vecchio commit ripeterebbe l'errore.

Se Git ignora il file, nella cartella del repository esegui:

```bash
git add -f PrismAdmin.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
git add PrismAdmin.xcodeproj/project.xcworkspace/contents.xcworkspacedata Config/App.xcconfig ci_scripts/ci_post_clone.sh
git commit -m "Fix Prism Admin Firebase package resolution"
git push
```

Versione 1.1.1, build locale 3; Xcode Cloud imposta il proprio numero di build. Target e schema PrismAdmin. Backend e APK Android 1.1.0 già forniti restano validi: non serve aggiornarli per questa correzione.

Verifica effettuata: JSON Package.resolved valido, Firebase 11.15.0 coerente con la versione esatta richiesta dal progetto, 14 dipendenze bloccate con revisioni Git, posizione richiesta dal messaggio Xcode Cloud inclusa nello ZIP. Non è stata eseguita una compilazione iOS locale; il nuovo archivio va verificato tramite Xcode Cloud.
