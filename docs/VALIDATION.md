# Weryfikacja wykonana w środowisku chmurowym

Wykonano **69 testów automatycznych** i kompilację plików Luau. Rojo zbudował projekt, a Lune zapisał rzeczywiście wygenerowane instancje mapy w pliku `build/EternalForge.rbxlx`, tak aby geometria była widoczna także w trybie edycji Studio. Pełny log uruchomienia znajduje się w `build/validation.log` w paczce.

| Zestaw | Liczba | Zakres |
|---|---:|---|
| `tests/run.luau` | 17 | Wszystkie wartości HP, 800Qa, zaokrąglenia double, format liczb, unikalne zabójstwa i koniec na strefie 30 |
| `tests/server.luau` | 11 | Autorytet obrażeń, zasięg, cooldown, linia widzenia, kontrola stref i aktywność wielu graczy |
| `tests/combat.luau` | 10 | 150 stanów stanowisk, pięć modeli w aktywnej strefie, wszystkie warianty potworów, udział w zabiciu, śmierć, respawn i sprzątanie |
| `tests/services.luau` | 14 | Osobiste bramy, niedozwolone pozycje, wszystkie 30 etapów, błędy odczytu i zapisu, scalanie danych, ponawianie i zamknięcie serwera |
| `tests/client.luau` | 6 | Uruchomienie rzeczywistego skryptu HUD, komunikaty danych, parametry układu telefonu, streamowanie pasków, argumenty ataku, bramy i sprzątanie |
| `tests/bootstrap.luau` | 4 | Kolejność startu świata, jeden właściciel ładowania postaci, odrodzenie, wyjście gracza i wspólny harmonogram |
| `tests/world.luau` | 7 | Rzeczywiste instancje 30 stref, 150 markerów, ciągłość podłoża, wolna trasa, dojścia do stanowisk, budżety oraz brak duplikatów |

Wygenerowany świat ma **5432 zakotwiczone części, 5 źródeł światła i 1 emiter cząsteczek**. Modele potworów powstają oddzielnie w aktywnych strefach. Liczba części nie jest pomiarem FPS ani gwarancją wydajności telefonu.

Testy reguł wykonują rzeczywiste moduły projektu w oficjalnym interpreterze Luau. Lune zapewnia strukturę instancji i typy Roblox; w testach usług użyto kontrolowanych odpowiedników zegara, graczy, raycastów, sygnałów i DataStore. Test mapy sprawdza obwiednie kolizji oraz ciągłe podłoże. Test UI buduje instancje i wywołuje kod, lecz nie renderuje pikseli.

Wykryto ograniczenie Lune 0.10.1: jego `Instance:SetAttribute` potrafi przepełnić wartości wyglądające jak duże liczby całkowite. Dlatego dokładność serwerowej konfiguracji i arytmetyki `800Qa` jest sprawdzona bezpośrednio, a replikację liczbowych atrybutów HP należy potwierdzić w Roblox Studio. Testy nie przedstawiają tej luki jako udanej weryfikacji replikacji.

**Nie wykonano:** wizualnego playtestu w Roblox Studio, fizyki Roblox, rzeczywistej komunikacji kilku klientów, zapisu w prawdziwej usłudze DataStore ani pomiarów na urządzeniu mobilnym. Nie opublikowano gry. Konkretne kroki znajdują się w [STUDIO_TESTS.md](STUDIO_TESTS.md).

Po zmianach odtwórz narzędzia przez `bash tools/bootstrap.sh` i uruchom `bash tools/validate.sh`. Budowanie nadpisuje wyłącznie wygenerowany katalog `build`, a generator podczas Play odtwarza tylko swój oznaczony świat.
