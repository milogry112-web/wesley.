# ETERNAL FORGE

Oryginalny projekt Roblox/Luau: przytulna wioska **Dawnrest**, 30 połączonych stref lochu i fundament pod przyszły system broni oraz wykuwania. Trasa biegnie fizycznie przed siebie, wzdłuż osi +Z. Przejścia między strefami nie teleportują gracza.

## Najszybszy start w Roblox Studio

1. Rozpakuj paczkę i otwórz `build/EternalForge.rbxlx` w Roblox Studio przez **File → Open from File**. Mapa jest już zapisana w pliku i widoczna przed Play; podczas gry skrypt odtwarza jej własny korzeń.
2. Włącz **View → Output**, następnie **Play**. Poczekaj na komunikat `[Eternal Forge] Ready`.
3. Ze środka wioski idź do dużej bramy. Podejdź do przeciwnika i kliknij, naciśnij **F** albo użyj przycisku **STRIKE** na ekranie. Kontroler: **R2**.
4. Pokonaj po jednym przeciwniku z każdego z pięciu stanowisk strefy. Po powiadomieniu o odblokowaniu przejdź do następnej strefy.
5. Do testów współpracy użyj **Test → Server & Clients**, z co najmniej dwoma klientami. Pełna lista scenariuszy znajduje się w [docs/STUDIO_TESTS.md](docs/STUDIO_TESTS.md).

Pierwsze uruchomienie bez dostępu do DataStore może pokazać `SESSION ONLY`. Gra pozwala wtedy testować walkę, lecz nie zapisuje postępu. Zapis sprawdź w oddzielnym, opublikowanym miejscu testowym z włączonym **Game Settings → Security → Enable Studio Access to API Services**. Nie są potrzebne klucze API ani hasła w kodzie.

**To projekt do uruchomienia i oceny w Studio, nie opublikowana gra.** Przeszło 69 testów automatycznych; zakres i ograniczenia opisuje [raport walidacji](docs/VALIDATION.md). Obraz, fizyka Roblox, rzeczywista replikacja, dostępność mobilna i prawdziwe DataStore wymagają sprawdzenia w silniku. Nie przeprowadzono tu wizualnego playtestu w Roblox Studio.

## Co zawiera projekt

- Wioska z kamiennym placem, dachami i konstrukcjami szachulcowymi, kuźnią, miejscami na sklep i crafting, straganami, latarniami, roślinnością, kryształami i tablicą przyszłego rankingu.
- Trzydzieści stref z osobnymi recepturami architektury i dekoracji, numerami, bramami oraz pięcioma znacznikami pojawiania się potworów. Końcowa sala rezerwuje przestrzeń pod przyszłego bossa.
- Serwerowy system HP, obrażeń, prostego AI, śmierci i odradzania. Potwory używają własnego HP zamiast `Humanoid.Health`.
- Osobisty postęp i kontrola dostępu do stref. Zabicie pięć razy tego samego stanowiska nie odblokowuje bramy. Postęp współgracza wymaga jego rzeczywistego udziału w walce.
- Zapis najwyższej strefy i ukończenia przez `UpdateAsync`, ponawianie błędów, scalanie wyższego postępu i zabezpieczenie przed nadpisaniem danych po nieudanym odczycie.
- HUD z celem, odblokowaniami, komunikatami zapisu, paskami HP i dotykowym przyciskiem walki; obsługa streamowania modeli.
- Jeden wspólny harmonogram AI. Nieobecne strefy nie mają aktywnych modeli przeciwników; krótkie opuszczenie strefy nie przerywa innemu graczowi walki.

Wszystkie modele powstają z lokalnych części Roblox. Projekt nie pobiera modeli z Toolboxa i nie wymaga płatnych assetów. Receptury generowania są deterministyczne. To autorska stylizowana geometria proceduralna, którą można dalej zastępować własnymi meshami i animacjami.

## Ważne: tymczasowa broń treningowa

Na potrzeby kompletnego testu progresji serwer daje atak o obrażeniach równych **34% HP potwora z najwyższej odblokowanej strefy**, z zasięgiem 16 studów i czasem między atakami 0,65 s. Dzięki temu każdy etap jest możliwy do przejścia przed dodaniem prawdziwego ekwipunku. To jawny mechanizm treningowy, nie docelowy balans gospodarki ani system zdobywania broni.

Nie zaimplementowano pełnego ekwipunku, dropów, walut, zakupów, ulepszeń ani bossa. Miejsca w świecie i interfejsy serwerowe są przygotowane pod te rozszerzenia. Szczegóły: [docs/INTEGRATION.md](docs/INTEGRATION.md).

## Praca z kodem

```sh
cd /workspace/wesley.
bash tools/bootstrap.sh
bash tools/validate.sh
```

Instalator pobiera przypięte oficjalne narzędzia Linux x86_64: Rojo, Luau i Lune, sprawdzając SHA-256. Domyślnie zapisuje je w `/workspace/.tools`; można ustawić `WESLEY_TOOLS_DIR`. Walidator uruchamia kompilator Luau, testy prawdziwych modułów oraz budowanie pliku Studio. Zamockowane usługi w testach nie zastępują silnika Roblox.

Na własnym komputerze można korzystać z Rojo i `default.project.json`, np. `rojo serve default.project.json`, łącząc plugin Rojo w Studio. Do otwarcia gotowego `.rbxlx` plugin nie jest potrzebny. Przy przenoszeniu do istniejącego miejsca zsynchronizuj tylko foldery projektu; ustawienia Workspace i Lighting z pliku projektu są przeznaczone dla tego nowego, pustego miejsca.

```text
src/shared/                  Konfiguracja 30 stref, HP, format liczb, reguły progresji
src/server/World/            Wioska, receptury stref, dekoracje, światło
src/server/Services/         HP, walka, AI, aktywacja, progresja, zapis
src/server/Bootstrap.server.luau   Uruchomienie i wspólny harmonogram
src/server/Runtime.luau      Serwerowy punkt integracji kolejnych systemów
src/client/                 HUD, efekty trafień i przekazywanie celu ataku
tests/                      Testy reguł, bezpieczeństwa i geometrii
tools/                      Odtwarzalna instalacja i walidacja
docs/                       Testy w Studio i rozszerzanie projektu
```

Istotne ustawienia:

- `MonsterConfig.HP` — jedyne źródło wszystkich 30 wartości HP, zapisanych jako liczby.
- `MonsterConfig.Get()` — nazwy, prędkość ruchu, aggro, obrażenia zadawane graczom i respawn.
- `DungeonConfig` — palety, nazwy, wysokości, położenie stref i pięciu stanowisk.
- `DamageService:SetWeaponProvider()` — podłączenie zaufanych danych prawdziwej broni.
- `ProgressionDataService` — wersja schematu i nazwa DataStore `AetherDungeon_Progression_v1`.

`800Qa = 800,000,000,000,000,000 = 8e17`. Luau używa liczb double; powyżej `2^53` nie zachowuje dokładności każdej liczby całkowitej. Przy `8e17` odstęp między sąsiednimi reprezentowalnymi wartościami wynosi 128. Cios zbyt mały, by zmienić HP, nie daje sztucznego udziału w zabiciu. Projekt nie udaje arytmetyki dowolnie dużych liczb całkowitych.
