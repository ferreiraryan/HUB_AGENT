#define NOMINMAX
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <mmdeviceapi.h>
#include <endpointvolume.h>
#include <audiopolicy.h>
#include <psapi.h>
#include <wrl/client.h>
#include <iostream>
#include <string>
#include <vector>
#include <map>
#include <algorithm>
#include <sstream>

#pragma comment(lib, "ole32.lib")
#pragma comment(lib, "psapi.lib")
#pragma comment(lib, "version.lib")

using Microsoft::WRL::ComPtr;

namespace {

std::string WideToUtf8(const std::wstring& wstr) {
    if (wstr.empty()) return "";
    int size = WideCharToMultiByte(CP_UTF8, 0, wstr.data(), (int)wstr.size(), NULL, 0, NULL, NULL);
    std::string result(size, 0);
    WideCharToMultiByte(CP_UTF8, 0, wstr.data(), (int)wstr.size(), &result[0], size, NULL, NULL);
    return result;
}

std::wstring ToLower(std::wstring str) {
    std::transform(str.begin(), str.end(), str.begin(), ::towlower);
    return str;
}

std::string EscapeJsonString(const std::string& s) {
    std::ostringstream o;
    for (char c : s) {
        if (c == '"') o << "\\\"";
        else if (c == '\\') o << "\\\\";
        else if (c == '\b') o << "\\b";
        else if (c == '\f') o << "\\f";
        else if (c == '\n') o << "\\n";
        else if (c == '\r') o << "\\r";
        else if (c == '\t') o << "\\t";
        else if ((unsigned char)c < ' ') {
            char buf[8];
            snprintf(buf, sizeof(buf), "\\u%04x", (unsigned char)c);
            o << buf;
        } else {
            o << c;
        }
    }
    return o.str();
}

std::wstring GetProcessPath(DWORD pid) {
    if (pid == 0) return L"";
    HANDLE hProcess = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
    if (!hProcess) return L"";
    wchar_t buffer[MAX_PATH] = { 0 };
    DWORD size = MAX_PATH;
    std::wstring path;
    if (QueryFullProcessImageNameW(hProcess, 0, buffer, &size)) {
        path = buffer;
    }
    CloseHandle(hProcess);
    return path;
}

std::wstring GetFileDescription(const std::wstring& filePath) {
    if (filePath.empty()) return L"";
    DWORD handle = 0;
    DWORD size = GetFileVersionInfoSizeW(filePath.c_str(), &handle);
    if (size == 0) return L"";

    std::vector<BYTE> data(size);
    if (!GetFileVersionInfoW(filePath.c_str(), 0, size, data.data())) return L"";

    struct LANGANDCODEPAGE {
        WORD wLanguage;
        WORD wCodePage;
    } *lpTranslate;
    UINT cbTranslate = 0;

    if (VerQueryValueW(data.data(), L"\\VarFileInfo\\Translation", (LPVOID*)&lpTranslate, &cbTranslate) && cbTranslate >= sizeof(LANGANDCODEPAGE)) {
        wchar_t subBlock[100];
        swprintf_s(subBlock, L"\\StringFileInfo\\%04x%04x\\FileDescription", lpTranslate[0].wLanguage, lpTranslate[0].wCodePage);
        LPWSTR lpBuffer = NULL;
        UINT dwBytes = 0;
        if (VerQueryValueW(data.data(), subBlock, (LPVOID*)&lpBuffer, &dwBytes) && dwBytes > 0 && lpBuffer) {
            return std::wstring(lpBuffer);
        }
    }
    return L"";
}

struct AppInfo {
    std::string id;
    std::string name;
    int volume;
    bool muted;
    DWORD pid;
};

int DoStatus() {
    ComPtr<IMMDeviceEnumerator> pEnumerator;
    HRESULT hr = CoCreateInstance(__uuidof(MMDeviceEnumerator), NULL, CLSCTX_ALL, IID_PPV_ARGS(&pEnumerator));
    if (FAILED(hr)) return 1;

    ComPtr<IMMDevice> pDevice;
    hr = pEnumerator->GetDefaultAudioEndpoint(eRender, eMultimedia, &pDevice);
    if (FAILED(hr)) return 1;

    // Master volume & mute
    int masterVol = 0;
    bool masterMuted = false;
    ComPtr<IAudioEndpointVolume> pEndpointVolume;
    if (SUCCEEDED(pDevice->Activate(__uuidof(IAudioEndpointVolume), CLSCTX_ALL, NULL, (void**)&pEndpointVolume))) {
        float fVol = 0;
        BOOL bMute = FALSE;
        pEndpointVolume->GetMasterVolumeLevelScalar(&fVol);
        pEndpointVolume->GetMute(&bMute);
        masterVol = (int)(fVol * 100.0f + 0.5f);
        masterMuted = bMute ? true : false;
    }

    // Enumerar sessões de áudio ativas
    std::map<std::string, AppInfo> appMap;

    ComPtr<IAudioSessionManager2> pSessionManager;
    if (SUCCEEDED(pDevice->Activate(__uuidof(IAudioSessionManager2), CLSCTX_ALL, NULL, (void**)&pSessionManager))) {
        ComPtr<IAudioSessionEnumerator> pSessionEnum;
        if (SUCCEEDED(pSessionManager->GetSessionEnumerator(&pSessionEnum))) {
            int count = 0;
            pSessionEnum->GetCount(&count);
            for (int i = 0; i < count; ++i) {
                ComPtr<IAudioSessionControl> pControl;
                if (FAILED(pSessionEnum->GetSession(i, &pControl))) continue;

                ComPtr<IAudioSessionControl2> pControl2;
                if (FAILED(pControl.As(&pControl2))) continue;

                AudioSessionState state;
                pControl2->GetState(&state);
                if (state == AudioSessionStateExpired) continue;

                DWORD pid = 0;
                pControl2->GetProcessId(&pid);

                float vol = 0;
                BOOL mute = FALSE;
                ComPtr<ISimpleAudioVolume> pSimple;
                if (SUCCEEDED(pControl.As(&pSimple))) {
                    pSimple->GetMasterVolume(&vol);
                    pSimple->GetMute(&mute);
                }

                int volPct = (int)(vol * 100.0f + 0.5f);
                std::string id;
                std::string name;

                if (pid == 0 || pControl2->IsSystemSoundsSession() == S_OK) {
                    id = "system_sounds";
                    name = "Sons do Sistema";
                } else {
                    std::wstring path = GetProcessPath(pid);
                    if (path.empty()) continue; // Processo já finalizado
                    std::wstring filename;
                    size_t lastSlash = path.find_last_of(L"\\/");
                    if (lastSlash != std::wstring::npos) filename = path.substr(lastSlash + 1);
                    else filename = path;

                    id = WideToUtf8(ToLower(filename));
                    std::wstring desc = GetFileDescription(path);
                    if (!desc.empty()) {
                        name = WideToUtf8(desc);
                    } else {
                        // Nome base capitalizado sem .exe
                        std::wstring base = filename;
                        if (base.size() > 4 && base.substr(base.size() - 4) == L".exe") {
                            base = base.substr(0, base.size() - 4);
                        }
                        if (!base.empty()) base[0] = ::towupper(base[0]);
                        name = WideToUtf8(base);
                    }
                }

                if (appMap.find(id) == appMap.end()) {
                    appMap[id] = AppInfo{ id, name, volPct, mute ? true : false, pid };
                } else {
                    // Mantém o maior volume se houver múltiplos canais/subprocessos
                    if (volPct > appMap[id].volume) {
                        appMap[id].volume = volPct;
                    }
                }
            }
        }
    }

    // Saída JSON limpa
    std::cout << "{\"master\":{\"volume\":" << masterVol << ",\"muted\":" << (masterMuted ? "true" : "false") << "},\"apps\":[";
    bool first = true;
    for (const auto& pair : appMap) {
        if (!first) std::cout << ",";
        first = false;
        const auto& app = pair.second;
        std::cout << "{\"id\":\"" << EscapeJsonString(app.id) << "\","
                  << "\"name\":\"" << EscapeJsonString(app.name) << "\","
                  << "\"volume\":" << app.volume << ","
                  << "\"muted\":" << (app.muted ? "true" : "false") << "}";
    }
    std::cout << "]}\n";
    return 0;
}

int DoSetMaster(int value) {
    ComPtr<IMMDeviceEnumerator> pEnumerator;
    if (FAILED(CoCreateInstance(__uuidof(MMDeviceEnumerator), NULL, CLSCTX_ALL, IID_PPV_ARGS(&pEnumerator)))) return 1;
    ComPtr<IMMDevice> pDevice;
    if (FAILED(pEnumerator->GetDefaultAudioEndpoint(eRender, eMultimedia, &pDevice))) return 1;
    ComPtr<IAudioEndpointVolume> pEndpointVolume;
    if (FAILED(pDevice->Activate(__uuidof(IAudioEndpointVolume), CLSCTX_ALL, NULL, (void**)&pEndpointVolume))) return 1;

    float fVol = std::max(0.0f, std::min(1.0f, value / 100.0f));
    return SUCCEEDED(pEndpointVolume->SetMasterVolumeLevelScalar(fVol, NULL)) ? 0 : 1;
}

int DoSetMasterMute(bool mute) {
    ComPtr<IMMDeviceEnumerator> pEnumerator;
    if (FAILED(CoCreateInstance(__uuidof(MMDeviceEnumerator), NULL, CLSCTX_ALL, IID_PPV_ARGS(&pEnumerator)))) return 1;
    ComPtr<IMMDevice> pDevice;
    if (FAILED(pEnumerator->GetDefaultAudioEndpoint(eRender, eMultimedia, &pDevice))) return 1;
    ComPtr<IAudioEndpointVolume> pEndpointVolume;
    if (FAILED(pDevice->Activate(__uuidof(IAudioEndpointVolume), CLSCTX_ALL, NULL, (void**)&pEndpointVolume))) return 1;

    return SUCCEEDED(pEndpointVolume->SetMute(mute ? TRUE : FALSE, NULL)) ? 0 : 1;
}

int DoSetApp(const std::string& targetStr, int value) {
    ComPtr<IMMDeviceEnumerator> pEnumerator;
    if (FAILED(CoCreateInstance(__uuidof(MMDeviceEnumerator), NULL, CLSCTX_ALL, IID_PPV_ARGS(&pEnumerator)))) return 1;
    ComPtr<IMMDevice> pDevice;
    if (FAILED(pEnumerator->GetDefaultAudioEndpoint(eRender, eMultimedia, &pDevice))) return 1;
    ComPtr<IAudioSessionManager2> pSessionManager;
    if (FAILED(pDevice->Activate(__uuidof(IAudioSessionManager2), CLSCTX_ALL, NULL, (void**)&pSessionManager))) return 1;
    ComPtr<IAudioSessionEnumerator> pSessionEnum;
    if (FAILED(pSessionManager->GetSessionEnumerator(&pSessionEnum))) return 1;

    float fVol = std::max(0.0f, std::min(1.0f, value / 100.0f));
    std::wstring target(targetStr.begin(), targetStr.end());
    target = ToLower(target);
    if (target.size() > 4 && target.substr(target.size() - 4) == L".exe") {
        target = target.substr(0, target.size() - 4);
    }

    int count = 0;
    pSessionEnum->GetCount(&count);
    int affected = 0;

    for (int i = 0; i < count; ++i) {
        ComPtr<IAudioSessionControl> pControl;
        if (FAILED(pSessionEnum->GetSession(i, &pControl))) continue;
        ComPtr<IAudioSessionControl2> pControl2;
        if (FAILED(pControl.As(&pControl2))) continue;

        DWORD pid = 0;
        pControl2->GetProcessId(&pid);

        bool match = false;
        if ((target == L"system_sounds" || target == L"system") && (pid == 0 || pControl2->IsSystemSoundsSession() == S_OK)) {
            match = true;
        } else if (std::to_wstring(pid) == target) {
            match = true;
        } else if (pid != 0) {
            std::wstring path = GetProcessPath(pid);
            std::wstring filename;
            size_t lastSlash = path.find_last_of(L"\\/");
            if (lastSlash != std::wstring::npos) filename = path.substr(lastSlash + 1);
            else filename = path;

            std::wstring base = ToLower(filename);
            if (base.size() > 4 && base.substr(base.size() - 4) == L".exe") {
                base = base.substr(0, base.size() - 4);
            }
            if (base == target) match = true;
        }

        if (match) {
            ComPtr<ISimpleAudioVolume> pSimple;
            if (SUCCEEDED(pControl.As(&pSimple))) {
                if (SUCCEEDED(pSimple->SetMasterVolume(fVol, NULL))) {
                    affected++;
                }
            }
        }
    }
    return 0;
}

int DoSetAppMute(const std::string& targetStr, bool mute) {
    ComPtr<IMMDeviceEnumerator> pEnumerator;
    if (FAILED(CoCreateInstance(__uuidof(MMDeviceEnumerator), NULL, CLSCTX_ALL, IID_PPV_ARGS(&pEnumerator)))) return 1;
    ComPtr<IMMDevice> pDevice;
    if (FAILED(pEnumerator->GetDefaultAudioEndpoint(eRender, eMultimedia, &pDevice))) return 1;
    ComPtr<IAudioSessionManager2> pSessionManager;
    if (FAILED(pDevice->Activate(__uuidof(IAudioSessionManager2), CLSCTX_ALL, NULL, (void**)&pSessionManager))) return 1;
    ComPtr<IAudioSessionEnumerator> pSessionEnum;
    if (FAILED(pSessionManager->GetSessionEnumerator(&pSessionEnum))) return 1;

    std::wstring target(targetStr.begin(), targetStr.end());
    target = ToLower(target);
    if (target.size() > 4 && target.substr(target.size() - 4) == L".exe") {
        target = target.substr(0, target.size() - 4);
    }

    int count = 0;
    pSessionEnum->GetCount(&count);
    int affected = 0;

    for (int i = 0; i < count; ++i) {
        ComPtr<IAudioSessionControl> pControl;
        if (FAILED(pSessionEnum->GetSession(i, &pControl))) continue;
        ComPtr<IAudioSessionControl2> pControl2;
        if (FAILED(pControl.As(&pControl2))) continue;

        DWORD pid = 0;
        pControl2->GetProcessId(&pid);

        bool match = false;
        if ((target == L"system_sounds" || target == L"system") && (pid == 0 || pControl2->IsSystemSoundsSession() == S_OK)) {
            match = true;
        } else if (std::to_wstring(pid) == target) {
            match = true;
        } else if (pid != 0) {
            std::wstring path = GetProcessPath(pid);
            std::wstring filename;
            size_t lastSlash = path.find_last_of(L"\\/");
            if (lastSlash != std::wstring::npos) filename = path.substr(lastSlash + 1);
            else filename = path;

            std::wstring base = ToLower(filename);
            if (base.size() > 4 && base.substr(base.size() - 4) == L".exe") {
                base = base.substr(0, base.size() - 4);
            }
            if (base == target) match = true;
        }

        if (match) {
            ComPtr<ISimpleAudioVolume> pSimple;
            if (SUCCEEDED(pControl.As(&pSimple))) {
                if (SUCCEEDED(pSimple->SetMute(mute ? TRUE : FALSE, NULL))) {
                    affected++;
                }
            }
        }
    }
    return 0;
}

} // namespace

int main(int argc, char* argv[]) {
    if (argc < 2) {
        std::cerr << "Usage: hub_audio_helper <status|set-master <0-100>|set-master-mute <0|1>|set-app <target> <0-100>|set-app-mute <target> <0|1>>\n";
        return 1;
    }

    CoInitializeEx(NULL, COINIT_MULTITHREADED);
    int res = 0;
    std::string cmd = argv[1];

    if (cmd == "status") {
        res = DoStatus();
    } else if (cmd == "set-master" && argc >= 3) {
        res = DoSetMaster(std::stoi(argv[2]));
    } else if (cmd == "set-master-mute" && argc >= 3) {
        res = DoSetMasterMute(std::stoi(argv[2]) != 0);
    } else if (cmd == "set-app" && argc >= 4) {
        res = DoSetApp(argv[2], std::stoi(argv[3]));
    } else if (cmd == "set-app-mute" && argc >= 4) {
        res = DoSetAppMute(argv[2], std::stoi(argv[3]) != 0);
    } else {
        std::cerr << "Unknown command or missing arguments: " << cmd << "\n";
        res = 1;
    }

    CoUninitialize();
    return res;
}

