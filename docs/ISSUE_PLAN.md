# Ýalňyşlyklaryň sanawy we düzediş meýilnamasy (step by step)

Bu faýl ulanyjynyň habar beren kemçiliklerini yzarlamak üçin ýöredilýär.
Her ädim aýratyn commit + test bilen tamamlanýar.

| # | Kemçilik | Ýagdaý | Çözülişi |
|---|----------|--------|----------|
| 1 | Ulanyjy döredilmeýär / token saklanmaýar | 🚧 işlenýär | Serwerde **hakyky token** (DB-de `users.token`) + programmada awtomatik gaýtadan hasap döretmek (401 bolsa) |
| 2 | Ses ýazdyranda tekstleriň nireden gelýändigi düşnüksiz | ⏳ meýilleşdirildi | Tekstiň çeşmesi UI-da görkeziler (paket ady / "öz sözlemim") + programmada lokal sözlem goraghana (offline) |
| 3 | Ulanyjynyň özi tekst ýazmaly | ⏳ meýilleşdirildi | "Öz sözlemim" düzgüni — el bilen tekst girizmek |
| 4 | Bir sözlemi ikinji gezek ýazdyrmaly däl | ⏳ meýilleşdirildi | Sözlem gaýtalanmasyn: lokal + serwer barlagy, 409 jogaby |
| 5 | Serwer bilen birikme problemalary | ⏳ meýilleşdirildi | Retry/backoff, saglyk barlagy, serwer adresini sazlamak |
| 6 | Türkmençe sözlemlerde ýalňyşlyklar | ⏳ meýilleşdirildi | Seed-däki näsaz sözlemleri düzedip, awtomatik barlag goşmak |
| 7 | Programma agyr açylýar | ⏳ meýilleşdirildi | Splash + background bootstrap, torda garaşýan çagyryşlary yza sürmek |
