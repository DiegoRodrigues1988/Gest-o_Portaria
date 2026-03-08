# gestao_portaria

Aplicativo de gerenciamento de encomendas para portaria.

## 🛠️ Build / Distribuição

### Gerar artefatos de download (Windows / Android)

No Windows PowerShell, execute:

```powershell
.\scripts\build_and_package.ps1 -Platforms windows,android
```

Isso irá:

- Gerar build **release** para Windows (`flutter build windows`) e copiar o executável + dependências para `dist/windows`.
- Gerar build **release** para Android (`flutter build apk`) e copiar o APK para `dist/android`.
- Compactar cada artefato em `dist/gestao_portaria_windows.zip` e `dist/gestao_portaria_android.zip`.

Depois de rodar, os arquivos resultantes estarão em:

- `dist/windows/`
- `dist/android/`

> Esses arquivos podem ser enviados para qualquer host (servidor, drive, etc.) para download.

---

## 📦 Instalação local (Windows)

Abra a pasta `dist/windows` e execute `gestao_portaria.exe`.

---

## 📦 Instalação local (Android)

Copie o APK em `dist/android/*.apk` para um dispositivo Android e instale.
