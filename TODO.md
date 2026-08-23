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
