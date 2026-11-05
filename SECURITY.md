# Security

## Reporting a problem

Please do not open a public issue for a security problem. Report it in private: open the repository's
**Security** tab on GitHub and choose **Report a vulnerability**. You get an answer there, and the report stays
private until a fix is released.

Useful in a report: the addon version (`/wfi version`), the client build, what happens, and the steps that make
it happen.

## What counts

- The addon: anything that lets game text, another addon or another player make the addon run code, break the
  client, or write something into the saved settings that the player did not choose.
- The report and the collector file: anything that puts a character name, a realm, an account name or another
  player's text into a file the player is asked to post.
- The pipeline and the workflows: anything in an issue, a pull request or a data file that makes the tools run
  code, write outside the repository, or publish a release.

A wrong translation is not a security problem: use the
[translation report](https://github.com/Dade9854/wow-forever-italian/issues/new?template=translation-report.yml).

## Supported versions

Fixes go into the next release. Only the latest release is supported.

## Italiano

Per un problema di sicurezza non aprire una issue pubblica: segnalalo in privato. Apri la scheda **Security** del
repository su GitHub e scegli **Report a vulnerability**. La risposta arriva lì, e la segnalazione resta privata
finché non esce una correzione.

Nella segnalazione scrivi la versione dell'addon (`/wfi version`), la build del client, cosa succede e i passi per
riprodurlo.

Una traduzione sbagliata non è un problema di sicurezza: usa il
[modulo di segnalazione della traduzione](https://github.com/Dade9854/wow-forever-italian/issues/new?template=translation-report.yml).

Le correzioni entrano nella versione successiva. È supportata solo l'ultima versione.
