# Guia de Compatibilização e Build no Windows (Fase 4)

O código da **Fase 4** (daemon headless + tray nativo + UI sob demanda) já foi implementado para suportar Windows e Linux. Como a compilação cruzada de binários Windows nativos (`hub_audio_helper.exe`, `hub_agent_daemon.exe` e `cms_app.exe`) precisa ser feita em uma máquina Windows, siga este guia para gerar e validar o bundle final no Windows.

---

## 1. O Que Já Está Implementado no Código para Windows

- **Daemon Headless (`packages/agent_core/bin/hub_agent_daemon.dart`)**:
  - Usa lock exclusivo de instância em `<appSupport>\hub_agent_daemon.lock` (`%APPDATA%\com.example\cms_app\hub_agent_daemon.lock`).
  - Sobe `DaemonIpcServer` em `127.0.0.1:0` com Bearer token em `daemon.ipc.json`.
  - Mantém o `AgentRuntime`, MQTT, VoiceMeeter autostart, hotkey global e tray nativo sem nenhuma dependência de Flutter.
- **Tray Nativo + Helper Unificado (`apps/cms_app/windows/hub_audio_helper/main.cpp`)**:
  - Modo `daemon` (NDJSON via `stdin`/`stdout` gerenciado por `WindowsHelperBridge`) agora inclui `Shell_NotifyIconW` com menu nativo (`Abrir Editor CMS`, `Publicar Layout Agora`, `Reconectar Broker MQTT`, `Pomodoro: Iniciar / Pausar`, `Sair`) e `shell32.lib`.
  - Unifica no mesmo processo: WASAPI callbacks, GSMTC (mídia), `SetWinEventHook` (janela ativa), stats Win32 sem `Sleep(120)`, OSD, hotkey global e notificações WinRT.
- **UI Sob Demanda (`apps/cms_app/lib/main.dart`)**:
  - `cms_app.exe` (ou `--show`) conecta ao `hub_agent_daemon.exe` via IPC local (auto-iniciando o daemon se não estiver rodando).
  - Ao fechar a janela do CMS (ou fechar o Spotlight `--spotlight=search` / `--spotlight=todo`), faz flush das edições e encerra com `exit(0)`, liberando **100% da RAM gráfica**.
  - `AutostartController` registra `hub_agent_daemon.exe` no Registro do Windows quando o binário existe ao lado do `cms_app.exe` (com fallback automático para `cms_app.exe --hidden`).

---

## 2. Pré-requisitos no Windows

1. **Flutter / Dart SDK** instalado (ex.: `C:\Users\ryck3\flutter-sdk\flutter\bin\`).
2. **Visual Studio 2022** (ou Build Tools) com workload **Desktop development with C++** e **Windows 10/11 SDK** (necessário para C++/WinRT e `cl.exe`).
3. **`nircmd.exe`** já presente em `apps/cms_app/windows/runner/resources/nircmd.exe` (copiado automaticamente pelo CMake).

---

## 3. Passo a Passo de Compilação no Windows

Abra o **Developer PowerShell for VS 2022** (ou **x64 Native Tools Command Prompt for VS** para ter o `cl.exe` e o SDK no `PATH`) na raiz do repositório:

### Passo 1 — Validar testes no Windows
```powershell
cd packages\agent_core
& "C:\Users\ryck3\flutter-sdk\flutter\bin\dart.bat" analyze
& "C:\Users\ryck3\flutter-sdk\flutter\bin\dart.bat" test
```

### Passo 2 — Compilar `hub_agent_daemon.exe` (Dart AOT puro)
```powershell
cd packages\agent_core
& "C:\Users\ryck3\flutter-sdk\flutter\bin\dart.bat" compile exe bin\hub_agent_daemon.dart -o ..\..\apps\cms_app\windows\runner\resources\hub_agent_daemon.exe
```

### Passo 3 — Recompilar `hub_audio_helper.exe` (com `Shell_NotifyIconW` / `shell32.lib`)
> Importante: compile com `/W4 /WX` para garantir 0 warnings no C++.
```powershell
cd ..\..\apps\cms_app\windows\hub_audio_helper
cl /std:c++20 /EHsc /O2 /W4 /WX /DUNICODE /D_UNICODE main.cpp /Fe:..\runner\resources\hub_audio_helper.exe ole32.lib oleaut32.lib propsys.lib psapi.lib dxva2.lib mfplat.lib mfreadwrite.lib mfuuid.lib windowsapp.lib gdiplus.lib user32.lib gdi32.lib dwmapi.lib shell32.lib
```

### Passo 4 — Compilar `cms_app.exe` (Flutter Windows Release)
```powershell
cd ..\..
& "C:\Users\ryck3\flutter-sdk\flutter\bin\flutter.bat" pub get
& "C:\Users\ryck3\flutter-sdk\flutter\bin\flutter.bat" build windows --release
```

### Passo 5 — Copiar `hub_agent_daemon.exe` para o bundle final
O `apps/cms_app/windows/runner/CMakeLists.txt` já copia `nircmd.exe` e `hub_audio_helper.exe` para `Release\`, mas ainda é necessário garantir `hub_agent_daemon.exe` na mesma pasta do `cms_app.exe`:

```powershell
Copy-Item windows\runner\resources\hub_agent_daemon.exe build\windows\x64\runner\Release\hub_agent_daemon.exe -Force
```

*(Opcional: se quiser automatizar essa cópia em builds futuros, adicione mais um `copy_if_different` para `hub_agent_daemon.exe` no `add_custom_command` de `apps/cms_app/windows/runner/CMakeLists.txt`.)*

Estrutura esperada em `apps\cms_app\build\windows\x64\runner\Release\`:
- `cms_app.exe`
- `hub_agent_daemon.exe`
- `hub_audio_helper.exe`
- `nircmd.exe`
- `flutter_windows.dll` + `data\`

---

## 4. Checklist de Validação no Windows

1. **Subir o daemon direto**:
   - Execute `hub_agent_daemon.exe` em `Release\`.
   - Confirme que aparece o ícone nativo na bandeja do Windows (`Shell_NotifyIconW`) e o arquivo `%APPDATA%\com.example\cms_app\daemon.ipc.json` é criado.
2. **Testar menu da bandeja**:
   - Clique direito no ícone da bandeja -> `Abrir Editor CMS` deve abrir o `cms_app.exe` conectado ao daemon.
   - Feche a janela do `cms_app.exe` (`X`): no Gerenciador de Tarefas, `cms_app.exe` deve desaparecer por completo (**0 MB**), permanecendo apenas `hub_agent_daemon.exe` e `hub_audio_helper.exe` (~20–30 MB totais).
3. **Testar `--hidden` e Spotlight**:
   - `cms_app.exe --hidden`: garante que o daemon está rodando e encerra imediatamente.
   - Atalho global (ex.: `Alt+Space`): deve abrir o Spotlight e encerrar o `cms_app.exe` ao fechar/confirmar.
4. **Atualizar Autostart**:
   - Abra as Configurações do CMS -> aba **Sistema** -> desative e reative **"Iniciar com o sistema"** para atualizar a chave do Registro para `hub_agent_daemon.exe`.
5. **Fallback `--standalone`**:
   - Se precisar depurar tudo em um único processo (`flutter run -d windows`), use `--standalone` (ou remova temporariamente `hub_agent_daemon.exe` da pasta).
