# Rozszerzanie Eternal Forge

## Granica zaufania

Klient wysyła wyłącznie identyfikator celu przez `Attack`. Serwer sprawdza format celu, częstotliwość żądań, żywego gracza, jego aktualne i odblokowane miejsce, zasięg, linię widzenia i zaufane statystyki broni. Klient nie może przyznać HP, obrażeń, waluty ani odblokowania. `State`, `Notify` i `DamageFeedback` służą do prezentacji.

Brama jest elementem wizualnym bez globalnej kolizji. `ProgressionService:ValidatePosition()` kontroluje położenie każdego gracza z osobna, również bezpośrednio przed walką i przyznaniem postępu. Wejście poza odblokowany zakres +Z, wyjście poza granice świata i zbyt duży skok położenia powodują cofnięcie do ostatniej prawidłowej pozycji. Inny odblokowany gracz nie zmienia tych reguł. Przy opóźnieniu sieci możliwa jest krótka korekta pozycji przy zamkniętej bramie; nie jest to zezwolenie na walkę w zablokowanej strefie.

Odblokowania łączą się monotonicznie podczas zapisu (`max` dla strefy, zachowanie ukończenia). Ta polityka jest właściwa dla trwałych odblokowań, lecz **nie nadaje się bez zmian do salda waluty ani transakcyjnego ekwipunku**. Przyszłą ekonomię należy oprzeć na odrębnej, odpowiednio blokowanej sesji danych.

## Podłączenie broni

Nowy Script w `ServerScriptService` może poczekać na gotowość i zastąpić dostawcę broni treningowej:

```lua
local runtime = require(game.ServerScriptService.AetherDungeon.Runtime).WaitReady()

runtime.Damage:SetWeaponProvider(function(player, monster)
    -- Własny InventoryService musi zwracać dane należące do SERWERA.
    local weapon = InventoryService:GetEquippedWeapon(player)
    local definition = WeaponDefinitions[weapon.DefinitionId]
    return {
        Damage = definition.BaseDamage * UpgradeRules.DamageMultiplier(weapon.Level),
        Cooldown = definition.Cooldown,
        Range = definition.Range,
        CritChance = definition.CritChance,
        CritMultiplier = definition.CritMultiplier,
    }
end)
```

`InventoryService`, `WeaponDefinitions` i `UpgradeRules` w przykładzie to przyszłe moduły użytkownika; nie są częścią obecnej gry. Provider uruchamia się na serwerze i powinien korzystać z pamięci bieżącej sesji, bez wykonywania yieldów, sieci lub DataStore w środku pojedynczego ataku. Pola numeryczne muszą pozostać dodatnie i skończone; szansa krytyczna mieści się w `[0,1]`. Brak arbitralnego niskiego limitu obrażeń blokującego wartości T, Qa lub Qi.

Po zmianie zasięgu i cooldownu zaktualizuj prezentację w kliencie albo dodaj ograniczoną, serwerową replikację tych parametrów. Klient może wiedzieć, jak pokazać zasięg; decyzja o trafieniu pozostaje na serwerze. Rzadkość, ulepszenia, crafting i mnożniki mogą być obliczane we własnych modułach przed zwróceniem statystyk.

## Zdarzenie śmierci i przyszły loot

```lua
local runtime = require(game.ServerScriptService.AetherDungeon.Runtime).WaitReady()
runtime.Monsters.MonsterDied.Event:Connect(function(death)
    -- death: MonsterId, ZoneId, SlotId, Generation, Position, MaxHP,
    --        Contributors = {{UserId, Damage}, ...}, KillerUserId
    -- Przyszły LootService przyznaje nagrody WYŁĄCZNIE na serwerze.
end)
```

Jedna śmierć emituje jedno zdarzenie. `MonsterId + Generation` pozwalają rozróżnić kolejne odrodzenia tego samego stanowiska. Obecna lista `Contributors` obejmuje żywych, obecnych w danej strefie graczy, którzy faktycznie zadali dodatnie obrażenia i dla których jest to aktualny etap progresji. Nie jest to jeszcze ogólna lista odbiorców dropów podczas powrotów do starszych stref. Przed dodaniem farmienia zmień świadomie politykę nagród, pozostawiając oddzielne reguły postępu.

Zdarzenie `RegisterKill` deduplikuje pięć stanowisk osobno dla każdego gracza. Nie zapisuje częściowego licznika zabójstw; po ponownym dołączeniu trzeba ukończyć bieżącą piątkę od początku. Odblokowane strefy oraz ukończenie strefy 30 są trwałe, jeśli DataStore działa.

## Rozszerzanie mapy i bossów

Każda strefa ma szerokość 128 i długość 180 studów. Wspólna droga jest na wysokości `Y=0`, strefa 1 zaczyna się od `Z=0`, a strefa 30 kończy się przy `Z=5400`. Dalej, do `Z=5570`, znajduje się rezerwa końcowej areny przypisana do strefy 30. To miejsce na bossa, bez szóstego zwykłego spawnu.

Zachowaj pięć znaczników w `ZoneXX.Spawns`, ciągłość podłoża i wolne wejścia. Rozszerzenie granic, nowe podesty albo większe skoki wymagają uzgodnienia z walidacją ruchu w `ProgressionService`. Nie ustawiaj bram globalnie na `CanCollide=false` jako sposobu przyznania dostępu — są takie od początku, a uprawnienia weryfikuje serwer.

`WorldGenerator.Generate(DungeonConfig)` odtwarza wyłącznie własny korzeń świata, a `LightingController` zarządza własnymi efektami. Nie wywołuj regeneracji świata podczas aktywnej walki; w Studio zatrzymaj Play, zmień recepturę i uruchom ponownie. `MonsterService:Destroy()` usuwa dynamiczne modele i połączenia; same pliki świata nie tworzą pętli animacji dekoracji.

## Wydajność

`Workspace.StreamingEnabled` jest zapisane w projekcie Rojo. Modele potworów są atomowo streamowane. GUI reaguje na pojawianie się i usuwanie tagowanych instancji, a etykiety HP mają ograniczony dystans. Serwer zachowuje lekkie stany 150 stanowisk, symuluje wyłącznie aktywne strefy i stosuje krótki okres wygaszenia aktywności. Aktywność jest sumą potrzeb wszystkich graczy.

Obecne AI podąża w stronę gracza i omija przeszkodę krótkim ruchem bocznym. Nie jest pełnym nawigatorem `PathfindingService`; przy dodawaniu wielopoziomowych labiryntów należy rozszerzyć nawigację. Zakotwiczone modele nie wymagają osobnych Humanoidów ani symulacji fizycznej kończyn. Przed publikacją sprawdź płynność ruchu, opóźnienia replikacji, strumieniowanie i budżety na docelowym telefonie.
