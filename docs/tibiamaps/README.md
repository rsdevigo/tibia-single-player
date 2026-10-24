# Mapa completo e marcadores no OTClient (tibiamaps)

O minimapa é do **cliente**: cada OTClient guarda o que você explorou (`minimap.otmm`) e os marcadores
(nas configurações). O servidor não participa. Aqui o OTClient Redemption recebe o mapa completo do Tibia
global e os ~6.400 marcadores do projeto
[tibiamaps/tibia-map-data](https://github.com/tibiamaps/tibia-map-data) (licença MIT):

- **Mapa:** o mod `game_tibiamaps` carrega as imagens por andar **a cada entrada no jogo**. Não dá para
  importar uma vez só: o OTClient grava no `minimap.otmm` apenas os blocos que o personagem viu, e o
  `g_minimap.loadImage` não marca os blocos como vistos (o mapa some ao deslogar).
- **Marcadores:** o `import.lua` acrescenta uma vez os marcadores às configurações, onde ficam salvos.

O mapa do servidor (OTServBR-Global) segue o mapa global, mas não é idêntico: pode haver áreas que
existem só no global (mais novas) ou só no servidor (como a área custom do `!trade`, fora do mapa principal).

## 1. Baixar os arquivos

No PowerShell, troque o caminho pela pasta do seu OTClient:

```powershell
$otc = "C:\caminho\do\otclient"
$data = Join-Path $otc "data\tibiamaps"
$mod = Join-Path $otc "mods\tibiamaps"
New-Item -ItemType Directory -Force $data, $mod | Out-Null
$base = "https://tibiamaps.github.io/tibia-map-data"
0..15 | ForEach-Object { $f = "floor-{0:D2}-map.png" -f $_; Invoke-WebRequest "$base/$f" -OutFile (Join-Path $data $f) }
Invoke-WebRequest "$base/markers.json" -OutFile (Join-Path $data "markers.json")
$repo = "https://raw.githubusercontent.com/rsdevigo/tibia-single-player/main/docs/tibiamaps"
Invoke-WebRequest "$repo/import.lua" -OutFile (Join-Path $data "import.lua")
Invoke-WebRequest "$repo/mod/tibiamaps.otmod" -OutFile (Join-Path $mod "tibiamaps.otmod")
Invoke-WebRequest "$repo/mod/tibiamaps.lua" -OutFile (Join-Path $mod "tibiamaps.lua")
```

## 2. Marcadores (uma vez)

1. Abra o OTClient e **fique na tela de login** (os marcadores são gravados ao sair do jogo).
2. Abra o terminal com `Ctrl+T` e rode:
   ```lua
   dofile('/tibiamaps/import.lua')
   ```
3. Deve aparecer `tibiamaps: N marcadores adicionados`. Rodar de novo não duplica.

## 3. Mapa (automático)

Com o mod em `mods/tibiamaps/`, reinicie o OTClient e entre no jogo. Cerca de 1 segundo depois o mapa
completo aparece no minimapa, e o terminal (`Ctrl+T`) mostra `tibiamaps: 16 andares carregados no minimapa`.
O que você já explorou tem prioridade sobre as imagens.
