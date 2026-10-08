# Testy wymagające Roblox Studio

Testy CLI wykonują kod Luau oraz badają zbudowane instancje. Nie renderują obrazu, nie symulują silnika fizycznego Roblox, prawdziwych połączeń klient–serwer ani usług DataStore. Poniższe testy trzeba wykonać przed publikacją.

## Pierwsze uruchomienie i świat

1. Otwórz `build/EternalForge.rbxlx`, włącz Output i Play. Postać ma pojawić się w wiosce, po załadowaniu podłoża; Output ma zawierać `[Eternal Forge] Ready` bez błędów czerwonych.
2. Oceń wioskę: proporcje budynków, przejścia pod dachami, widoczność znaków, przytulne światło, kuźnię, stragany, tablicę i wejście do lochu. Dostosuj grafikę do niskiej i wysokiej jakości renderowania.
3. Przejdź do stref 1 i 2. Sprawdź wejścia, pięć osiągalnych stanowisk, numery i swobodę poruszania się. Podłoże musi być ciągłe bez szczelin i progów blokujących avatar.
4. Powtórz dla 30 stref. Szczególnie obejrzyj mosty nad rzeką, pęknięcia w lodzie, łuki, filary i końcową salę. Nie wolno wymagać teleportu do następnej strefy.
5. Zatrzymaj i ponownie uruchom Play. Ma istnieć jeden `Workspace.AetherWorld` i jeden folder `AetherMonsters`. Każdy `ZoneXX.Spawns` zawiera dokładnie pięć markerów; rezerwa bossa nie ma dodatkowego zwykłego spawnu.

## Walka i progresja

1. Podejdź na mniej niż 16 studów. Kliknięcie/F/przycisk na ekranie powinny wywołać atak treningowy. Przy aktualnej najwyższej strefie około trzech trafień zabija przeciwnika.
2. Sprawdź celownik, pasek HP, liczby obrażeń, śmierć, zniknięcie modelu i odrodzenie po około 12 s. Nie powinny pozostawać stare etykiety nad usuniętymi potworami.
3. Nie atakuj i pozwól przeciwnikowi podejść. Powinien zadawać skonfigurowane obrażenia graczowi z zachowaniem cooldownu. Wycofanie poza aggro powinno zakończyć pościg.
4. Zabij wielokrotnie to samo stanowisko: cel pozostaje `1/5`. Zabij pozostałe cztery: pojawia się odblokowanie następnej strefy. Przejdź tam pieszo i wróć do poprzedniej.
5. Ukończ strefę 30: stan ukończony, brak strefy 31, HP zwykłych potworów `800Qa`. Arena przyszłego bossa pozostaje rezerwą.
6. Zgiń i odrodź się. Powrót do wioski jest zwykłym respawnem postaci; zdobyte odblokowania w tej sesji pozostają.

## Dwóch graczy i próby niedozwolonych działań

1. Uruchom lokalny serwer z dwoma klientami. Gracz A zabija pięć potworów, B nie bierze udziału. Tylko A ma dostać dostęp do strefy 2.
2. A przechodzi przez bramę, B próbuje wejść za nim, obok bramy, po skoku lub wzdłuż zewnętrznej krawędzi. Serwer powinien cofnąć B i odmówić obrażeń zadawanych w zablokowanej strefie.
3. Obaj zadają rzeczywiste obrażenia pięciu potworom w swojej bieżącej strefie i pozostają przy życiu na miejscu. Obaj otrzymują własny postęp. Nieobecny gracz i obserwator bez udziału nie dostają odblokowania.
4. Podczas walki A opuszcza strefę, B zostaje. Potwory B nie znikają. Po wyjściu wszystkich i upływie okresu wygaszenia modele powinny zniknąć; ponowne wejście przywraca pięć stanowisk bez dublowania stanu.
5. Z konsoli testowej klienta wyślij niewłaściwy identyfikator, bardzo szybkie żądania, cel z daleka i dodatkowy argument `1e18` do `Attack`. Serwer ma odrzucić nieprawidłowe trafienia, a dodatkowa liczba nie może zmienić obrażeń. Zrób to tylko w swoim lokalnym miejscu testowym.
6. Wykonaj atak przez kolidującą ścianę. Sprawdzenie linii widzenia ma zatrzymać obrażenia.

## Zapis

1. W oddzielnym opublikowanym miejscu testowym włącz dostęp Studio do API. Odblokuj nową strefę, zaczekaj na stan zapisu, wyjdź i dołącz ponownie. Najwyższa strefa ma zostać zachowana.
2. Ukończenie strefy 30 ma przetrwać ponowne dołączenie. Częściowy cel `3/5` celowo nie jest trwały.
3. Wyłącz dostęp API w miejscu testowym. Gra powinna wyświetlić informację o braku trwałego zapisu i pozwolić na test sesji. Błąd odczytu nie może nadpisać istniejącego profilu wartościami domyślnymi.
4. Sprawdź Output po błędzie zapisu: kontrolowane ostrzeżenie i ponowienie, brak nieobsłużonego błędu zatrzymującego pętlę gry. Testy CLI obejmują wymuszone błędy usług i scalanie danych; ich wynik nie dowodzi dostępności prawdziwej usługi.

## Telefon, streaming i budżety

1. Użyj emulatora urządzenia w pionie 320×568 i w poziomie. HUD, komunikaty, przycisk walki i natywne przyciski skoku/joystick nie powinny się nakładać. Tekst musi pozostać czytelny.
2. Przetestuj prawdziwy telefon, słabszą grafikę i opóźnienie sieci. Oceń czas budowania świata, FPS i skoki pamięci podczas szybkiego przechodzenia stref.
3. Zwiększ odległość między dwoma klientami. Każdy powinien dostać własne streamowane modele, paski HP i aktualne bramy; wyjście i ponowne wejście w zasięg nie może mnożyć połączeń i GUI.
4. Użyj Developer Console/MicroProfiler: statyczne dekoracje nie mają pętli na każdą klatkę, a AI ma jeden wspólny harmonogram. Sprawdź obciążenie przy kilku oddzielnie zajętych strefach.

Wyniki tych prób należy zapisać po rzeczywistym uruchomieniu w Studio. W tym repozytorium nie ma deklaracji, że zostały już wykonane.
