# Mapa completo e marcadores no OTClient (tibiamaps)

O minimapa é do **cliente**: cada OTClient guarda o que você explorou (`minimap.otmm`) e os marcadores
(nas configurações). O servidor não participa. Este script importa para o OTClient Redemption o mapa
completo do Tibia global e os ~6.400 marcadores mantidos pelo projeto
[tibiamaps/tibia-map-data](https://github.com/tibiamaps/tibia-map-data) (licença MIT).

O mapa do servidor (OTServBR-Global) segue o mapa global, mas não é idêntico: pode haver áreas que
existem só no global (mais novas) ou só no servidor (como a área custom do `!trade`, fora do mapa principal).

## 1. Baixar os arquivos

No PowerShell, troque o caminho pela pasta do seu OTClient:

```powershell
$otc = "C:\caminho\do\otclient"
$dst = Join-Path $otc "data\tibiamaps"
New-Item -ItemType Directory -Force $dst | Out-Null
$base = "https://tibiamaps.github.io/tibia-map-data"
0..15 | ForEach-Object { $f = "floor-{0:D2}-map.png" -f $_; Invoke-WebRequest "$base/$f" -OutFile (Join-Path $dst $f) }
Invoke-WebRequest "$base/markers.json" -OutFile (Join-Path $dst "markers.json")
Invoke-WebRequest "https://raw.githubusercontent.com/rsdevigo/tibia-single-player/main/docs/tibiamaps/import.lua" -OutFile (Join-Path $dst "import.lua")
```

## 2. Importar

1. Abra o OTClient e **fique na tela de login** (não entre no jogo: o minimapa é gravado ao sair do jogo).
2. Abra o terminal com `Ctrl+T` e rode:
   ```lua
   dofile('/tibiamaps/import.lua')
   ```
3. Deve aparecer `tibiamaps: 16 andares importados, N marcadores adicionados`.
4. Entre no jogo e abra o mapa.

O que você já tinha explorado e os seus marcadores são mantidos. Para começar do zero, apague o
`minimap.otmm` da pasta de usuário do OTClient antes de importar.
