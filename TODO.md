# LukyPurr TODO

## [DONE] Baixar faixa atual como MP3 (modo offline / carro)
Objetivo: botao na barra do player que pega a faixa tocando (videoId) e salva um MP3
na pasta que o usuario escolhe em Settings. Reusa yt-dlp nightly + ffmpeg do sistema.

- [x] Criar `services/download_service.py` (DownloadService: yt-dlp + FFmpegExtractAudio mp3)
- [x] Expor `downloadService` no `main.py` (context property)
- [x] Plugar `DownloadService` no `Controller` (instancia + Slot `download_current_as_mp3`)
- [x] SettingsService: persistir `download_folder` (get/set) em settings.json
- [x] QML SettingsView: seletor de pasta (FolderDialog nativo)
- [x] QML PlayerBar: botao "baixar MP3" + indicador de status
- [x] Rodar app e validar download ponta-a-ponta (smoke test: clip -> MP3 457KB OK)
- [x] Rebuild do .exe (pyinstaller --onefile --windowed) - feito 23/08, Endrius validou

Concluido 23/08: feature MP3 commitada. Seletor de pasta trocado de QML FolderDialog
(que nao abria no Wayland/KDE) para QFileDialog nativo. Endrius confirmou funcionamento.

## [DONE] Aba Offline (ouvir os MP3 baixados sem internet)
Objetivo: nova aba "Offline" na sidebar (abaixo do Queue) que varre a pasta de
download e lista os arquivos de audio para ouvir offline. Reusa o AudioPlayer,
que ja toca arquivo local (QUrl.fromLocalFile).

- [x] Controller: `scan_offline()` lista MP3/m4a/flac/ogg/wav da pasta e monta `offline_tracks`
- [x] Controller: `play_offline(index)` toca o arquivo local (seta `_offline_mode`)
- [x] Controller: `_load_current_track` toca path local quando `_offline_mode` (sem stream YT)
- [x] Main.qml: NavButton "Offline" + view OfflineView
- [x] OfflineView.qml: lista, botao Rescan, aviso se pasta vazia/sem config
- [x] Capa: download baixa thumbnail (writethumbnail + EmbedThumbnail) e scan_offline mapeia o .jpg ao lado
- [x] FIX: capa embutida nao aparecia (EmbedThumbnail escreve nao-padrao; ffprobe/QML nao veem). scan_offline agora faz carve dos bytes da imagem do MP3 pro cache
- [x] Smoke test (MP3 reais): scan extraiu capa dos 3 arquivos, arquivos reais e magic JPEG valido
- [ ] Endrius validar no app (build/venv) e commitar

Proximo passo: rebuildar (build.sh/pyinstaller) se for rodar o .exe; no venv ja funciona.

## [WIP] Controles da fila Offline (shuffle / repeat / transicao online)
Objetivo (pedido Endrius, 23/08): na aba Offline adicionar
  1. botao Shuffle: gera ordem aleatoria (nao toca sempre a mesma sequencia)
  2. botao Repeat: ao terminar a lista, repete (se shuffle ligado, reembaralha)
  3. sem repeat + fim da lista: se houver internet, gera fila ONLINE baseada
     na ultima faixa tocada (busca artista+titulo -> videoId -> watch playlist)

- [x] controller: flags `_offline_shuffle`, `_offline_repeat` + Property expostas
- [x] controller: `shuffle_offline()` embaralha `offline_tracks` e toca do inicio
- [x] controller: `toggle_offline_repeat()` liga/desliga repeat
- [x] controller: `_auto_next` respeita shuffle+repeat no fim da lista offline
- [x] controller: `_has_internet()` (socket rapido p/ YouTube) + transicao online
- [x] music_service: `search_video_id(artist, title)` -> primeiro videoId do YTMusic
- [x] OfflineView.qml: botoes Shuffle + Repeat (toggle) no header
- [x] smoke test: shuffle gera ordem diferente; repeat reembaralha; fim sem repeat dispara busca online
- [x] VALIDADO: py_compile OK; qmllint OK; smoke test 4 casos (shuffle/repeat/sem-net-para/transicao-online) PASS
- [ ] Endrius validar no app e commitar/pushar
