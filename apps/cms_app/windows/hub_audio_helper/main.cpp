#define NOMINMAX
#define WIN32_LEAN_AND_MEAN
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <objidl.h>
#include <gdiplus.h>
#include <iphlpapi.h>
#include <netioapi.h>
#include <setupapi.h>
#include <devpkey.h>
#include <mmdeviceapi.h>
#include <endpointvolume.h>
#include <audiopolicy.h>
#include <psapi.h>
#include <functiondiscoverykeys_devpkey.h>
#include <mfapi.h>
#include <mfidl.h>
#include <mfreadwrite.h>
#include <physicalmonitorenumerationapi.h>
#include <highlevelmonitorconfigurationapi.h>
#include <wrl/client.h>
#include <iostream>
#include <string>
#include <vector>
#include <map>
#include <algorithm>
#include <sstream>
#include <set>
#include <thread>
#include <chrono>
#include <mutex>
#include <atomic>
#include <cmath>
#include <winrt/base.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.UI.Notifications.h>
#include <winrt/Windows.UI.Notifications.Management.h>
#include <winrt/Windows.ApplicationModel.h>
#include <winrt/Windows.Media.Control.h>

#pragma comment(lib, "ole32.lib")
#pragma comment(lib, "psapi.lib")
#pragma comment(lib, "version.lib")
#pragma comment(lib, "propsys.lib")
#pragma comment(lib, "mfplat.lib")
#pragma comment(lib, "mfreadwrite.lib")
#pragma comment(lib, "mfuuid.lib")
#pragma comment(lib, "dxva2.lib")
#pragma comment(lib, "gdiplus.lib")
#pragma comment(lib, "iphlpapi.lib")
#pragma comment(lib, "setupapi.lib")
#pragma comment(lib, "user32.lib")
#pragma comment(lib, "gdi32.lib")
#pragma comment(lib, "windowsapp.lib")

using Microsoft::WRL::ComPtr;

namespace {

std::string WideToUtf8(const std::wstring& wstr) {
    if (wstr.empty()) return "";
    int size = WideCharToMultiByte(CP_UTF8, 0, wstr.data(), (int)wstr.size(), NULL, 0, NULL, NULL);
    std::string result(size, 0);
    WideCharToMultiByte(CP_UTF8, 0, wstr.data(), (int)wstr.size(), &result[0], size, NULL, NULL);
    return result;
}

std::wstring Utf8ToWide(const std::string& str) {
    if (str.empty()) return L"";
    int size = MultiByteToWideChar(CP_UTF8, 0, str.data(), (int)str.size(), NULL, 0);
    std::wstring result(size, 0);
    MultiByteToWideChar(CP_UTF8, 0, str.data(), (int)str.size(), &result[0], size);
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
                    if (path.empty()) continue;
                    std::wstring filename;
                    size_t lastSlash = path.find_last_of(L"\\/");
                    if (lastSlash != std::wstring::npos) filename = path.substr(lastSlash + 1);
                    else filename = path;

                    id = WideToUtf8(ToLower(filename));
                    std::wstring desc = GetFileDescription(path);
                    if (!desc.empty()) {
                        name = WideToUtf8(desc);
                    } else {
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
                    if (volPct > appMap[id].volume) {
                        appMap[id].volume = volPct;
                    }
                }
            }
        }
    }

    // Microfone padrão (WASAPI eCapture)
    bool micAvailable = false;
    int micVol = 0;
    bool micMuted = false;
    ComPtr<IMMDevice> pMicDevice;
    if (SUCCEEDED(pEnumerator->GetDefaultAudioEndpoint(eCapture, eCommunications, &pMicDevice)) ||
        SUCCEEDED(pEnumerator->GetDefaultAudioEndpoint(eCapture, eMultimedia, &pMicDevice))) {
        ComPtr<IAudioEndpointVolume> pMicVol;
        if (SUCCEEDED(pMicDevice->Activate(__uuidof(IAudioEndpointVolume), CLSCTX_ALL, NULL, (void**)&pMicVol))) {
            float fMic = 0;
            BOOL bMicMute = FALSE;
            pMicVol->GetMasterVolumeLevelScalar(&fMic);
            pMicVol->GetMute(&bMicMute);
            micVol = (int)(fMic * 100.0f + 0.5f);
            micMuted = bMicMute ? true : false;
            micAvailable = true;
        }
    }

    std::cout << "{\"master\":{\"volume\":" << masterVol << ",\"muted\":" << (masterMuted ? "true" : "false")
              << "},\"mic\":{\"available\":" << (micAvailable ? "true" : "false")
              << ",\"volume\":" << micVol << ",\"muted\":" << (micMuted ? "true" : "false")
              << "},\"apps\":[";
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

int DoListDevices() {
    ComPtr<IMMDeviceEnumerator> pEnumerator;
    if (FAILED(CoCreateInstance(__uuidof(MMDeviceEnumerator), NULL, CLSCTX_ALL, IID_PPV_ARGS(&pEnumerator)))) return 1;

    ComPtr<IMMDevice> pDefaultDevice;
    std::wstring defaultId = L"";
    if (SUCCEEDED(pEnumerator->GetDefaultAudioEndpoint(eRender, eMultimedia, &pDefaultDevice))) {
        LPWSTR pStrId = NULL;
        if (SUCCEEDED(pDefaultDevice->GetId(&pStrId)) && pStrId) {
            defaultId = pStrId;
            CoTaskMemFree(pStrId);
        }
    }

    ComPtr<IMMDeviceCollection> pCollection;
    if (FAILED(pEnumerator->EnumAudioEndpoints(eRender, DEVICE_STATE_ACTIVE, &pCollection))) return 1;

    UINT count = 0;
    pCollection->GetCount(&count);

    std::cout << "[";
    bool first = true;
    for (UINT i = 0; i < count; ++i) {
        ComPtr<IMMDevice> pDevice;
        if (FAILED(pCollection->Item(i, &pDevice))) continue;

        LPWSTR pStrId = NULL;
        if (FAILED(pDevice->GetId(&pStrId)) || !pStrId) continue;
        std::wstring devId = pStrId;
        CoTaskMemFree(pStrId);

        std::wstring devFriendlyName = devId;
        ComPtr<IPropertyStore> pProps;
        if (SUCCEEDED(pDevice->OpenPropertyStore(STGM_READ, &pProps))) {
            PROPVARIANT varName;
            PropVariantInit(&varName);
            if (SUCCEEDED(pProps->GetValue(PKEY_Device_FriendlyName, &varName))) {
                if (varName.vt == VT_LPWSTR && varName.pwszVal) {
                    devFriendlyName = varName.pwszVal;
                }
                PropVariantClear(&varName);
            }
        }

        bool isDefault = (!defaultId.empty() && devId == defaultId);

        if (!first) std::cout << ",";
        first = false;

        std::cout << "{\"id\":\"" << EscapeJsonString(WideToUtf8(devId)) << "\","
                  << "\"name\":\"" << EscapeJsonString(WideToUtf8(devFriendlyName)) << "\","
                  << "\"is_default\":" << (isDefault ? "true" : "false") << "}";
    }
    std::cout << "]\n";
    return 0;
}

ComPtr<IMMDevice> FindDevice(IMMDeviceEnumerator* pEnumerator, const std::string& target) {
    if (!pEnumerator) return nullptr;

    if (target.empty() || target == "default") {
        ComPtr<IMMDevice> pDef;
        pEnumerator->GetDefaultAudioEndpoint(eRender, eMultimedia, &pDef);
        return pDef;
    }

    std::wstring wTarget = ToLower(Utf8ToWide(target));

    ComPtr<IMMDeviceCollection> pCollection;
    if (SUCCEEDED(pEnumerator->EnumAudioEndpoints(eRender, DEVICE_STATE_ACTIVE, &pCollection))) {
        UINT count = 0;
        pCollection->GetCount(&count);
        ComPtr<IMMDevice> pPartialMatch = nullptr;

        for (UINT i = 0; i < count; ++i) {
            ComPtr<IMMDevice> pDev;
            if (FAILED(pCollection->Item(i, &pDev))) continue;

            LPWSTR pStrId = NULL;
            if (FAILED(pDev->GetId(&pStrId)) || !pStrId) continue;
            std::wstring devId = pStrId;
            CoTaskMemFree(pStrId);

            std::wstring devName = devId;
            ComPtr<IPropertyStore> pProps;
            if (SUCCEEDED(pDev->OpenPropertyStore(STGM_READ, &pProps))) {
                PROPVARIANT var;
                PropVariantInit(&var);
                if (SUCCEEDED(pProps->GetValue(PKEY_Device_FriendlyName, &var))) {
                    if (var.vt == VT_LPWSTR && var.pwszVal) {
                        devName = var.pwszVal;
                    }
                    PropVariantClear(&var);
                }
            }

            std::wstring wDevId = ToLower(devId);
            std::wstring wDevName = ToLower(devName);

            if (wDevId == wTarget || wDevName == wTarget) {
                return pDev;
            }

            if (pPartialMatch == nullptr && wDevName.find(wTarget) != std::wstring::npos) {
                pPartialMatch = pDev;
            }
        }

        if (pPartialMatch != nullptr) {
            return pPartialMatch;
        }
    }

    ComPtr<IMMDevice> pFallback;
    pEnumerator->GetDefaultAudioEndpoint(eRender, eMultimedia, &pFallback);
    return pFallback;
}

int DoPlaySound(const std::wstring& filePath, const std::string& targetDevice, int volumePercent = 100) {
    HRESULT hr = MFStartup(MF_VERSION);
    if (FAILED(hr)) return 1;

    int exitCode = 0;
    {
        ComPtr<IMMDeviceEnumerator> pEnumerator;
        hr = CoCreateInstance(__uuidof(MMDeviceEnumerator), NULL, CLSCTX_ALL, IID_PPV_ARGS(&pEnumerator));
        if (FAILED(hr)) {
            MFShutdown();
            return 1;
        }

        ComPtr<IMMDevice> pDevice = FindDevice(pEnumerator.Get(), targetDevice);
        if (!pDevice) {
            MFShutdown();
            return 1;
        }

        ComPtr<IAudioClient> pAudioClient;
        hr = pDevice->Activate(__uuidof(IAudioClient), CLSCTX_ALL, NULL, (void**)&pAudioClient);
        if (FAILED(hr)) {
            MFShutdown();
            return 1;
        }

        WAVEFORMATEX* pMixFormat = NULL;
        hr = pAudioClient->GetMixFormat(&pMixFormat);
        if (FAILED(hr) || !pMixFormat) {
            MFShutdown();
            return 1;
        }

        ComPtr<IMFSourceReader> pReader;
        ComPtr<IMFAttributes> pAttributes;
        MFCreateAttributes(&pAttributes, 1);
        if (pAttributes) {
            pAttributes->SetUINT32(MF_LOW_LATENCY, TRUE);
        }

        hr = MFCreateSourceReaderFromURL(filePath.c_str(), pAttributes.Get(), &pReader);
        if (FAILED(hr)) {
            CoTaskMemFree(pMixFormat);
            MFShutdown();
            return 2;
        }

        pReader->SetStreamSelection(MF_SOURCE_READER_ALL_STREAMS, FALSE);
        pReader->SetStreamSelection(MF_SOURCE_READER_FIRST_AUDIO_STREAM, TRUE);

        ComPtr<IMFMediaType> pTargetType;
        MFCreateMediaType(&pTargetType);
        MFInitMediaTypeFromWaveFormatEx(pTargetType.Get(), pMixFormat, sizeof(WAVEFORMATEX) + pMixFormat->cbSize);
        hr = pReader->SetCurrentMediaType(MF_SOURCE_READER_FIRST_AUDIO_STREAM, NULL, pTargetType.Get());
        if (FAILED(hr)) {
            pTargetType.Reset();
            MFCreateMediaType(&pTargetType);
            pTargetType->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Audio);
            pTargetType->SetGUID(MF_MT_SUBTYPE, MFAudioFormat_PCM);
            pReader->SetCurrentMediaType(MF_SOURCE_READER_FIRST_AUDIO_STREAM, NULL, pTargetType.Get());
        }

        REFERENCE_TIME hnsBufferDuration = 600000; // 60 ms para baixa latencia (responsividade de soundpad)
        hr = pAudioClient->Initialize(AUDCLNT_SHAREMODE_SHARED, 0, hnsBufferDuration, 0, pMixFormat, NULL);
        if (FAILED(hr)) {
            CoTaskMemFree(pMixFormat);
            MFShutdown();
            return 3;
        }

        UINT32 bufferFrameCount = 0;
        pAudioClient->GetBufferSize(&bufferFrameCount);

        ComPtr<IAudioRenderClient> pRenderClient;
        pAudioClient->GetService(IID_PPV_ARGS(&pRenderClient));

        UINT32 bytesPerFrame = pMixFormat->nBlockAlign;
        if (bytesPerFrame == 0) bytesPerFrame = 4;

        ComPtr<ISimpleAudioVolume> pSimpleVolume;
        if (SUCCEEDED(pAudioClient->GetService(IID_PPV_ARGS(&pSimpleVolume)))) {
            float volFloat = (float)std::max(0, std::min(100, volumePercent)) / 100.0f;
            pSimpleVolume->SetMasterVolume(volFloat, NULL);
        }

        bool eos = false;
        std::vector<BYTE> pendingData;

        // Pré-carrega primeiras amostras antes de iniciar o stream WASAPI para eliminar delay inicial e gaps
        while (pendingData.size() < bufferFrameCount * bytesPerFrame && !eos) {
            DWORD streamIndex = 0;
            DWORD flags = 0;
            LONGLONG llTimeStamp = 0;
            ComPtr<IMFSample> pSample;
            hr = pReader->ReadSample(MF_SOURCE_READER_FIRST_AUDIO_STREAM, 0, &streamIndex, &flags, &llTimeStamp, &pSample);
            if (FAILED(hr) || (flags & MF_SOURCE_READERF_ENDOFSTREAM)) {
                eos = true;
                break;
            }
            if (pSample) {
                ComPtr<IMFMediaBuffer> pBuffer;
                if (SUCCEEDED(pSample->ConvertToContiguousBuffer(&pBuffer))) {
                    BYTE* pAudioData = NULL;
                    DWORD currentLength = 0;
                    if (SUCCEEDED(pBuffer->Lock(&pAudioData, NULL, &currentLength))) {
                        pendingData.insert(pendingData.end(), pAudioData, pAudioData + currentLength);
                        pBuffer->Unlock();
                    }
                }
            }
        }

        if (!pendingData.empty()) {
            UINT32 initialFrames = (UINT32)(pendingData.size() / bytesPerFrame);
            if (initialFrames > bufferFrameCount) initialFrames = bufferFrameCount;
            BYTE* pData = NULL;
            if (SUCCEEDED(pRenderClient->GetBuffer(initialFrames, &pData))) {
                DWORD bytesToWrite = initialFrames * bytesPerFrame;
                memcpy(pData, pendingData.data(), bytesToWrite);
                pRenderClient->ReleaseBuffer(initialFrames, 0);
                pendingData.erase(pendingData.begin(), pendingData.begin() + bytesToWrite);
            }
        }

        hr = pAudioClient->Start();
        if (FAILED(hr)) {
            CoTaskMemFree(pMixFormat);
            MFShutdown();
            return 4;
        }

        while (!eos) {
            if (pendingData.empty()) {
                DWORD streamIndex = 0;
                DWORD flags = 0;
                LONGLONG llTimeStamp = 0;
                ComPtr<IMFSample> pSample;
                hr = pReader->ReadSample(MF_SOURCE_READER_FIRST_AUDIO_STREAM, 0, &streamIndex, &flags, &llTimeStamp, &pSample);
                if (FAILED(hr) || (flags & MF_SOURCE_READERF_ENDOFSTREAM)) {
                    eos = true;
                    break;
                }

                if (pSample) {
                    ComPtr<IMFMediaBuffer> pBuffer;
                    if (SUCCEEDED(pSample->ConvertToContiguousBuffer(&pBuffer))) {
                        BYTE* pAudioData = NULL;
                        DWORD currentLength = 0;
                        if (SUCCEEDED(pBuffer->Lock(&pAudioData, NULL, &currentLength))) {
                            pendingData.assign(pAudioData, pAudioData + currentLength);
                            pBuffer->Unlock();
                        }
                    }
                }
            }

            UINT32 padding = 0;
            pAudioClient->GetCurrentPadding(&padding);
            UINT32 framesAvailable = (bufferFrameCount > padding) ? (bufferFrameCount - padding) : 0;

            if (framesAvailable > 0 && !pendingData.empty()) {
                UINT32 framesToWrite = (UINT32)(pendingData.size() / bytesPerFrame);
                if (framesToWrite > framesAvailable) {
                    framesToWrite = framesAvailable;
                }

                if (framesToWrite > 0) {
                    BYTE* pData = NULL;
                    if (SUCCEEDED(pRenderClient->GetBuffer(framesToWrite, &pData))) {
                        DWORD bytesToWrite = framesToWrite * bytesPerFrame;
                        memcpy(pData, pendingData.data(), bytesToWrite);
                        pRenderClient->ReleaseBuffer(framesToWrite, 0);

                        pendingData.erase(pendingData.begin(), pendingData.begin() + bytesToWrite);
                    }
                }
            }

            if (framesAvailable == 0 || pendingData.size() >= framesAvailable * bytesPerFrame) {
                Sleep(5);
            }
        }

        // Aguarda esvaziar o que restou no buffer de saída
        UINT32 pad = 0;
        while (SUCCEEDED(pAudioClient->GetCurrentPadding(&pad)) && pad > 0) {
            Sleep(5);
        }

        pAudioClient->Stop();
        CoTaskMemFree(pMixFormat);
    }

    MFShutdown();
    return exitCode;
}

int DoWatchNotifications() {
    try {
        auto listener = winrt::Windows::UI::Notifications::Management::UserNotificationListener::Current();
        if (listener.GetAccessStatus() != winrt::Windows::UI::Notifications::Management::UserNotificationListenerAccessStatus::Allowed) {
            std::cerr << "Notification access not allowed\n";
            return 1;
        }

        std::set<uint32_t> seenIds;
        auto initialNotifs = listener.GetNotificationsAsync(winrt::Windows::UI::Notifications::NotificationKinds::Toast).get();
        for (uint32_t i = 0; i < initialNotifs.Size(); i++) {
            seenIds.insert(initialNotifs.GetAt(i).Id());
        }

        std::cout << "{\"status\":\"ready\",\"initial_count\":" << seenIds.size() << "}" << std::endl;

        while (true) {
            std::this_thread::sleep_for(std::chrono::milliseconds(1000));
            try {
                auto notifs = listener.GetNotificationsAsync(winrt::Windows::UI::Notifications::NotificationKinds::Toast).get();
                for (uint32_t i = 0; i < notifs.Size(); i++) {
                    auto n = notifs.GetAt(i);
                    uint32_t id = n.Id();
                    if (seenIds.find(id) == seenIds.end()) {
                        seenIds.insert(id);
                        std::string appName = "Sistema";
                        try {
                            if (n.AppInfo() && n.AppInfo().DisplayInfo()) {
                                appName = WideToUtf8(n.AppInfo().DisplayInfo().DisplayName().c_str());
                            }
                        } catch (...) {}
                        auto binding = n.Notification().Visual().GetBinding(winrt::Windows::UI::Notifications::KnownNotificationBindings::ToastGeneric());
                        if (binding) {
                            auto texts = binding.GetTextElements();
                            std::string title = texts.Size() > 0 ? WideToUtf8(texts.GetAt(0).Text().c_str()) : "";
                            std::string body = texts.Size() > 1 ? WideToUtf8(texts.GetAt(1).Text().c_str()) : "";
                            std::cout << "{\"id\":" << id
                                      << ",\"app\":\"" << EscapeJsonString(appName) << "\""
                                      << ",\"title\":\"" << EscapeJsonString(title) << "\""
                                      << ",\"body\":\"" << EscapeJsonString(body) << "\"}" << std::endl;
                        }
                    }
                }
            } catch (...) {}
        }
    } catch (const winrt::hresult_error& ex) {
        std::wcerr << L"Error: " << ex.message().c_str() << L"\n";
        return 1;
    }
    return 0;
}

int DoMediaStatus() {
    try {
        auto mgr = winrt::Windows::Media::Control::GlobalSystemMediaTransportControlsSessionManager::RequestAsync().get();
        if (!mgr) {
            std::cout << "{\"status\":\"Stopped\",\"title\":\"\",\"artist\":\"\",\"position\":0,\"duration\":0,\"playback_rate\":1.0}" << std::endl;
            return 0;
        }
        auto session = mgr.GetCurrentSession();
        if (!session) {
            std::cout << "{\"status\":\"Stopped\",\"title\":\"\",\"artist\":\"\",\"position\":0,\"duration\":0,\"playback_rate\":1.0}" << std::endl;
            return 0;
        }

        auto info = session.GetPlaybackInfo();
        std::string statusStr = "Stopped";
        double playbackRate = 1.0;
        if (info) {
            auto playbackStatus = info.PlaybackStatus();
            if (playbackStatus == winrt::Windows::Media::Control::GlobalSystemMediaTransportControlsSessionPlaybackStatus::Playing) statusStr = "Playing";
            else if (playbackStatus == winrt::Windows::Media::Control::GlobalSystemMediaTransportControlsSessionPlaybackStatus::Paused) statusStr = "Paused";
            else if (playbackStatus == winrt::Windows::Media::Control::GlobalSystemMediaTransportControlsSessionPlaybackStatus::Stopped) statusStr = "Stopped";

            try {
                auto rateRef = info.PlaybackRate();
                if (rateRef) {
                    double r = rateRef.Value();
                    if (r > 0.0) playbackRate = r;
                }
            } catch (...) {}
        }

        std::string title = "";
        std::string artist = "";
        try {
            auto mediaProps = session.TryGetMediaPropertiesAsync().get();
            if (mediaProps) {
                title = WideToUtf8(mediaProps.Title().c_str());
                artist = WideToUtf8(mediaProps.Artist().c_str());
            }
        } catch (...) {}

        int positionSec = 0;
        int durationSec = 0;
        try {
            auto timeline = session.GetTimelineProperties();
            if (timeline) {
                int64_t baseTicks = timeline.Position().count();
                int64_t endTicks = timeline.EndTime().count();
                durationSec = (int)(endTicks / 10000000LL);

                if (statusStr == "Playing") {
                    auto lastUpdatedTicks = timeline.LastUpdatedTime().time_since_epoch().count();
                    FILETIME ft;
                    GetSystemTimeAsFileTime(&ft);
                    ULARGE_INTEGER uli;
                    uli.LowPart = ft.dwLowDateTime;
                    uli.HighPart = ft.dwHighDateTime;
                    int64_t nowTicks = (int64_t)uli.QuadPart;
                    int64_t elapsedTicks = nowTicks - lastUpdatedTicks;
                    if (elapsedTicks > 0 && elapsedTicks < (int64_t)7200 * 10000000LL) {
                        int64_t estimatedTicks = baseTicks + (int64_t)(elapsedTicks * playbackRate);
                        if (endTicks > 0 && estimatedTicks > endTicks) estimatedTicks = endTicks;
                        positionSec = (int)(estimatedTicks / 10000000LL);
                    } else {
                        positionSec = (int)(baseTicks / 10000000LL);
                    }
                } else {
                    positionSec = (int)(baseTicks / 10000000LL);
                }
            }
        } catch (...) {}

        std::string safeTitle = "";
        for (char c : title) {
            if (c == '"' || c == '\\') safeTitle += '\\';
            safeTitle += c;
        }
        std::string safeArtist = "";
        for (char c : artist) {
            if (c == '"' || c == '\\') safeArtist += '\\';
            safeArtist += c;
        }

        std::cout << "{\"status\":\"" << statusStr
                  << "\",\"title\":\"" << safeTitle
                  << "\",\"artist\":\"" << safeArtist
                  << "\",\"position\":" << positionSec
                  << ",\"duration\":" << durationSec
                  << ",\"playback_rate\":" << playbackRate
                  << "}" << std::endl;
        return 0;
    } catch (...) {
        std::cout << "{\"status\":\"Stopped\",\"title\":\"\",\"artist\":\"\",\"position\":0,\"duration\":0,\"playback_rate\":1.0}" << std::endl;
        return 0;
    }
}

int DoMediaControl(int argc, char* argv[]) {
    if (argc < 3) return 1;
    std::string action = argv[2];
    try {
        auto mgr = winrt::Windows::Media::Control::GlobalSystemMediaTransportControlsSessionManager::RequestAsync().get();
        if (!mgr) return 1;
        auto session = mgr.GetCurrentSession();
        if (!session) return 1;

        if (action == "play_pause") {
            session.TryTogglePlayPauseAsync().get();
        } else if (action == "next") {
            session.TrySkipNextAsync().get();
        } else if (action == "prev" || action == "previous") {
            session.TrySkipPreviousAsync().get();
        } else if (action == "seek" && argc >= 4) {
            double targetSec = std::stod(argv[3]);
            int64_t ticks = (int64_t)(targetSec * 10000000.0);
            session.TryChangePlaybackPositionAsync(ticks).get();
        } else if (action == "rewind" && argc >= 4) {
            double deltaSec = std::stod(argv[3]);
            auto timeline = session.GetTimelineProperties();
            if (timeline) {
                int64_t cur = timeline.Position().count();
                int64_t delta = (int64_t)(deltaSec * 10000000.0);
                int64_t nextPos = (cur > delta) ? (cur - delta) : 0;
                session.TryChangePlaybackPositionAsync(nextPos).get();
            }
        } else if (action == "fast_forward" && argc >= 4) {
            double deltaSec = std::stod(argv[3]);
            auto timeline = session.GetTimelineProperties();
            if (timeline) {
                int64_t cur = timeline.Position().count();
                int64_t end = timeline.EndTime().count();
                int64_t delta = (int64_t)(deltaSec * 10000000.0);
                int64_t nextPos = (cur + delta < end) ? (cur + delta) : end;
                session.TryChangePlaybackPositionAsync(nextPos).get();
            }
        } else if ((action == "rate" || action == "speed" || action == "set_rate") && argc >= 4) {
            double targetRate = std::stod(argv[3]);
            session.TryChangePlaybackRateAsync(targetRate).get();
        }
        return 0;
    } catch (...) {
        return 1;
    }
}

uint64_t FileTimeToUint64(const FILETIME& ft) {
    return (static_cast<uint64_t>(ft.dwHighDateTime) << 32) | ft.dwLowDateTime;
}

void ReadTotalNetBytes(uint64_t& rxTotal, uint64_t& txTotal) {
    rxTotal = 0;
    txTotal = 0;
    PMIB_IF_TABLE2 table = nullptr;
    if (GetIfTable2(&table) == NO_ERROR && table != nullptr) {
        for (ULONG i = 0; i < table->NumEntries; ++i) {
            const auto& row = table->Table[i];
            if (row.OperStatus != IfOperStatusUp) continue;
            if (row.Type == IF_TYPE_SOFTWARE_LOOPBACK) continue;
            if (!row.InterfaceAndOperStatusFlags.HardwareInterface) continue;
            rxTotal += row.InOctets;
            txTotal += row.OutOctets;
        }
        FreeMibTable(table);
    }
}

int DoStats() {
    // 1. CPU via GetSystemTimes + Rede via GetIfTable2 (mesma janela de 120ms)
    int cpuLoad = 0;
    int rxKbps = 0;
    int txKbps = 0;
    uint64_t rx1 = 0, tx1 = 0, rx2 = 0, tx2 = 0;
    ReadTotalNetBytes(rx1, tx1);

    FILETIME idle1, kernel1, user1, idle2, kernel2, user2;
    auto t1 = std::chrono::steady_clock::now();
    bool gotCpu1 = GetSystemTimes(&idle1, &kernel1, &user1) != FALSE;
    Sleep(120);
    auto t2 = std::chrono::steady_clock::now();
    bool gotCpu2 = GetSystemTimes(&idle2, &kernel2, &user2) != FALSE;
    ReadTotalNetBytes(rx2, tx2);

    if (gotCpu1 && gotCpu2) {
        uint64_t idleDiff = FileTimeToUint64(idle2) - FileTimeToUint64(idle1);
        uint64_t kernelDiff = FileTimeToUint64(kernel2) - FileTimeToUint64(kernel1);
        uint64_t userDiff = FileTimeToUint64(user2) - FileTimeToUint64(user1);
        uint64_t totalDiff = kernelDiff + userDiff;
        if (totalDiff > 0 && totalDiff >= idleDiff) {
            double busy = static_cast<double>(totalDiff - idleDiff) * 100.0 / static_cast<double>(totalDiff);
            cpuLoad = std::clamp(static_cast<int>(busy + 0.5), 0, 100);
        }
    }

    double elapsedSec = std::chrono::duration<double>(t2 - t1).count();
    if (elapsedSec > 0.01) {
        if (rx2 >= rx1) rxKbps = static_cast<int>(((rx2 - rx1) / 1024.0) / elapsedSec + 0.5);
        if (tx2 >= tx1) txKbps = static_cast<int>(((tx2 - tx1) / 1024.0) / elapsedSec + 0.5);
    }

    // 2. RAM via GlobalMemoryStatusEx
    int ramUsedMb = 0;
    int ramTotalMb = 0;
    int ramPercent = 0;
    MEMORYSTATUSEX mem;
    mem.dwLength = sizeof(mem);
    if (GlobalMemoryStatusEx(&mem)) {
        const uint64_t mb = 1024ULL * 1024ULL;
        ramTotalMb = static_cast<int>(mem.ullTotalPhys / mb);
        uint64_t usedBytes = (mem.ullTotalPhys >= mem.ullAvailPhys) ? (mem.ullTotalPhys - mem.ullAvailPhys) : 0;
        ramUsedMb = static_cast<int>(usedBytes / mb);
        ramPercent = ramTotalMb > 0 ? std::clamp(static_cast<int>((usedBytes * 100ULL) / mem.ullTotalPhys), 0, 100) : 0;
    }

    // 3. Disco via GetDiskFreeSpaceExW
    wchar_t sysDrive[16] = L"C:";
    DWORD envLen = GetEnvironmentVariableW(L"SystemDrive", sysDrive, 14);
    if (envLen == 0 || envLen >= 14) {
        wcscpy_s(sysDrive, L"C:");
    }
    std::wstring mountW(sysDrive);
    std::wstring rootPath = mountW + L"\\";
    int diskUsedGb = 0;
    int diskTotalGb = 0;
    int diskPercent = 0;
    ULARGE_INTEGER freeBytes, totalBytes, totalFree;
    if (GetDiskFreeSpaceExW(rootPath.c_str(), &freeBytes, &totalBytes, &totalFree) && totalBytes.QuadPart > 0) {
        const uint64_t gb = 1024ULL * 1024ULL * 1024ULL;
        uint64_t used = (totalBytes.QuadPart >= totalFree.QuadPart) ? (totalBytes.QuadPart - totalFree.QuadPart) : 0;
        diskTotalGb = static_cast<int>(totalBytes.QuadPart / gb);
        diskUsedGb = static_cast<int>(used / gb);
        diskPercent = std::clamp(static_cast<int>((used * 100ULL) / totalBytes.QuadPart), 0, 100);
    }

    std::cout << "{\"cpu_load\":" << cpuLoad
              << ",\"ram_used_mb\":" << ramUsedMb
              << ",\"ram_total_mb\":" << ramTotalMb
              << ",\"ram_percent\":" << ramPercent
              << ",\"disk_mount\":\"" << EscapeJsonString(WideToUtf8(mountW))
              << "\",\"disk_used_gb\":" << diskUsedGb
              << ",\"disk_total_gb\":" << diskTotalGb
              << ",\"disk_percent\":" << diskPercent
              << ",\"net_rx_kbps\":" << rxKbps
              << ",\"net_tx_kbps\":" << txKbps
              << "}" << std::endl;
    return 0;
}

struct PhysicalMonitorEntry {
    int number;
    std::string model;
    HANDLE handle;
};

struct MonitorEnumContext {
    std::vector<PHYSICAL_MONITOR> rawMonitors;
};

BOOL CALLBACK MonitorEnumProc(HMONITOR hMonitor, HDC, LPRECT, LPARAM lParam) {
    auto* ctx = reinterpret_cast<MonitorEnumContext*>(lParam);
    DWORD count = 0;
    if (GetNumberOfPhysicalMonitorsFromHMONITOR(hMonitor, &count) && count > 0) {
        std::vector<PHYSICAL_MONITOR> batch(count);
        if (GetPhysicalMonitorsFromHMONITOR(hMonitor, count, batch.data())) {
            for (DWORD i = 0; i < count; ++i) {
                ctx->rawMonitors.push_back(batch[i]);
            }
        }
    }
    return TRUE;
}

int DoListDisplays() {
    MonitorEnumContext ctx;
    EnumDisplayMonitors(NULL, NULL, MonitorEnumProc, reinterpret_cast<LPARAM>(&ctx));

    std::cout << "[";
    bool first = true;
    for (size_t i = 0; i < ctx.rawMonitors.size(); ++i) {
        auto& pm = ctx.rawMonitors[i];
        DWORD minB = 0, curB = 0, maxB = 100;
        bool supportsDdc = GetMonitorBrightness(pm.hPhysicalMonitor, &minB, &curB, &maxB) != FALSE;
        int pct = -1;
        if (supportsDdc && maxB > minB) {
            pct = std::clamp(static_cast<int>(((curB - minB) * 100) / (maxB - minB)), 0, 100);
        }
        std::wstring desc(pm.szPhysicalMonitorDescription);
        std::string model = WideToUtf8(desc);
        if (model.empty()) model = "Monitor " + std::to_string(i + 1);

        if (!first) std::cout << ",";
        first = false;
        std::cout << "{\"number\":" << (i + 1)
                  << ",\"model\":\"" << EscapeJsonString(model)
                  << "\",\"supported\":" << (supportsDdc ? "true" : "false")
                  << ",\"brightness\":" << pct << "}";
    }
    std::cout << "]" << std::endl;

    if (!ctx.rawMonitors.empty()) {
        DestroyPhysicalMonitors(static_cast<DWORD>(ctx.rawMonitors.size()), ctx.rawMonitors.data());
    }
    return 0;
}

int DoGetBrightness(int displayNumber) {
    MonitorEnumContext ctx;
    EnumDisplayMonitors(NULL, NULL, MonitorEnumProc, reinterpret_cast<LPARAM>(&ctx));

    int resultPct = -1;
    for (size_t i = 0; i < ctx.rawMonitors.size(); ++i) {
        if (displayNumber > 0 && static_cast<int>(i + 1) != displayNumber) continue;
        DWORD minB = 0, curB = 0, maxB = 100;
        if (GetMonitorBrightness(ctx.rawMonitors[i].hPhysicalMonitor, &minB, &curB, &maxB) && maxB > minB) {
            resultPct = std::clamp(static_cast<int>(((curB - minB) * 100) / (maxB - minB)), 0, 100);
            break;
        }
    }

    if (!ctx.rawMonitors.empty()) {
        DestroyPhysicalMonitors(static_cast<DWORD>(ctx.rawMonitors.size()), ctx.rawMonitors.data());
    }

    if (resultPct >= 0) {
        std::cout << "{\"value\":" << resultPct << "}" << std::endl;
        return 0;
    }
    std::cout << "{\"value\":null}" << std::endl;
    return 0;
}

int DoSetBrightness(const std::string& target, int percent) {
    int pct = std::clamp(percent, 0, 100);
    int targetNum = 0;
    if (target != "all" && !target.empty()) {
        try {
            targetNum = std::stoi(target);
        } catch (...) {
            targetNum = 0;
        }
    }

    MonitorEnumContext ctx;
    EnumDisplayMonitors(NULL, NULL, MonitorEnumProc, reinterpret_cast<LPARAM>(&ctx));

    bool anySuccess = false;
    for (size_t i = 0; i < ctx.rawMonitors.size(); ++i) {
        if (targetNum > 0 && static_cast<int>(i + 1) != targetNum) continue;
        DWORD minB = 0, curB = 0, maxB = 100;
        if (GetMonitorBrightness(ctx.rawMonitors[i].hPhysicalMonitor, &minB, &curB, &maxB) && maxB >= minB) {
            DWORD newVal = minB + static_cast<DWORD>(((maxB - minB) * pct + 50) / 100);
            if (SetMonitorBrightness(ctx.rawMonitors[i].hPhysicalMonitor, newVal)) {
                anySuccess = true;
            }
        }
    }

    if (!ctx.rawMonitors.empty()) {
        DestroyPhysicalMonitors(static_cast<DWORD>(ctx.rawMonitors.size()), ctx.rawMonitors.data());
    }
    return anySuccess ? 0 : 1;
}

int DoSetMicMute(bool muted) {
    ComPtr<IMMDeviceEnumerator> pEnumerator;
    if (FAILED(CoCreateInstance(__uuidof(MMDeviceEnumerator), NULL, CLSCTX_ALL, IID_PPV_ARGS(&pEnumerator)))) {
        return 1;
    }
    ComPtr<IMMDevice> pMicDevice;
    if (FAILED(pEnumerator->GetDefaultAudioEndpoint(eCapture, eCommunications, &pMicDevice)) &&
        FAILED(pEnumerator->GetDefaultAudioEndpoint(eCapture, eMultimedia, &pMicDevice))) {
        return 1;
    }
    ComPtr<IAudioEndpointVolume> pMicVol;
    if (FAILED(pMicDevice->Activate(__uuidof(IAudioEndpointVolume), CLSCTX_ALL, NULL, (void**)&pMicVol))) {
        return 1;
    }
    return SUCCEEDED(pMicVol->SetMute(muted ? TRUE : FALSE, NULL)) ? 0 : 1;
}

std::string ClassifyDeviceKind(const std::string& lowerName) {
    if (lowerName.find("mouse") != std::string::npos || lowerName.find("g pro") != std::string::npos || lowerName.find("mx master") != std::string::npos) return "mouse";
    if (lowerName.find("keyboard") != std::string::npos || lowerName.find("teclado") != std::string::npos || lowerName.find("keychron") != std::string::npos) return "keyboard";
    if (lowerName.find("headset") != std::string::npos || lowerName.find("headphone") != std::string::npos || lowerName.find("fone") != std::string::npos || lowerName.find("buds") != std::string::npos || lowerName.find("airpods") != std::string::npos || lowerName.find("wh-") != std::string::npos || lowerName.find("jbl") != std::string::npos || lowerName.find("audio") != std::string::npos) return "headphones";
    if (lowerName.find("controller") != std::string::npos || lowerName.find("xbox") != std::string::npos || lowerName.find("dualsense") != std::string::npos || lowerName.find("gamepad") != std::string::npos) return "gamepad";
    return "other";
}

int DoBatteries() {
    struct BatEntry {
        std::string id;
        std::string name;
        std::string kind;
        int percent;
        bool charging;
    };
    std::vector<BatEntry> entries;

    // 1. Bateria principal do notebook / UPS
    SYSTEM_POWER_STATUS sps;
    if (GetSystemPowerStatus(&sps)) {
        if ((sps.BatteryFlag & 128) == 0 && sps.BatteryLifePercent <= 100) {
            entries.push_back(BatEntry{
                "pc_main",
                "PC / Notebook",
                "laptop",
                static_cast<int>(sps.BatteryLifePercent),
                (sps.ACLineStatus == 1) || ((sps.BatteryFlag & 8) != 0)
            });
        }
    }

    // 2. Periféricos Bluetooth / HID via SetupAPI (DEVPKEY_Device_BatteryLevel)
    static const DEVPROPKEY kBatteryLevelKey = {
        { 0x104EA319, 0x6EE2, 0x4701, { 0xBD, 0x47, 0x8D, 0xDB, 0xF4, 0x25, 0xBB, 0xE5 } },
        2
    };
    static const DEVPROPKEY kFriendlyNameKey = {
        { 0xA45C254E, 0xDF1C, 0x4EFD, { 0x80, 0x20, 0x67, 0xD1, 0x46, 0xA8, 0x50, 0xE0 } },
        14
    };
    static const DEVPROPKEY kDeviceNameKey = {
        { 0xB725F130, 0x47EF, 0x101A, { 0xA5, 0xF1, 0x02, 0x60, 0x8C, 0x9E, 0xEB, 0xAC } },
        10
    };
    HDEVINFO devInfo = SetupDiGetClassDevsW(NULL, NULL, NULL, DIGCF_ALLCLASSES | DIGCF_PRESENT);
    if (devInfo != INVALID_HANDLE_VALUE) {
        SP_DEVINFO_DATA devData;
        devData.cbSize = sizeof(devData);
        std::set<std::string> seenNames;

        for (DWORD idx = 0; SetupDiEnumDeviceInfo(devInfo, idx, &devData); ++idx) {
            DEVPROPTYPE propType = 0;
            BYTE batByte = 0;
            DWORD reqSize = 0;
            if (!SetupDiGetDevicePropertyW(devInfo, &devData, &kBatteryLevelKey, &propType, &batByte, sizeof(batByte), &reqSize, 0)) {
                continue;
            }
            if (batByte > 100) continue;

            wchar_t nameBuf[256] = { 0 };
            DEVPROPTYPE nameType = 0;
            if (!SetupDiGetDevicePropertyW(devInfo, &devData, &kFriendlyNameKey, &nameType, reinterpret_cast<PBYTE>(nameBuf), sizeof(nameBuf) - sizeof(wchar_t), &reqSize, 0) || nameBuf[0] == 0) {
                SetupDiGetDevicePropertyW(devInfo, &devData, &kDeviceNameKey, &nameType, reinterpret_cast<PBYTE>(nameBuf), sizeof(nameBuf) - sizeof(wchar_t), &reqSize, 0);
            }

            std::string nameUtf8 = WideToUtf8(std::wstring(nameBuf));
            if (nameUtf8.empty()) nameUtf8 = "Dispositivo BT";
            if (!seenNames.insert(nameUtf8).second) continue;

            std::string lower = nameUtf8;
            std::transform(lower.begin(), lower.end(), lower.begin(), [](unsigned char c) { return (char)std::tolower(c); });
            std::string id = "bt_" + std::to_string(entries.size());
            entries.push_back(BatEntry{
                id,
                nameUtf8,
                ClassifyDeviceKind(lower),
                static_cast<int>(batByte),
                false
            });
        }
        SetupDiDestroyDeviceInfoList(devInfo);
    }

    std::cout << "{\"devices\":[";
    for (size_t i = 0; i < entries.size(); ++i) {
        if (i > 0) std::cout << ",";
        const auto& e = entries[i];
        std::cout << "{\"id\":\"" << EscapeJsonString(e.id)
                  << "\",\"name\":\"" << EscapeJsonString(e.name)
                  << "\",\"kind\":\"" << EscapeJsonString(e.kind)
                  << "\",\"percent\":" << e.percent
                  << ",\"charging\":" << (e.charging ? "true" : "false")
                  << "}";
    }
    std::cout << "]}" << std::endl;
    return 0;
}

int DoActiveWindow() {
    HWND hwnd = GetForegroundWindow();
    if (!hwnd) {
        std::cout << "{\"process\":\"\",\"title\":\"\"}" << std::endl;
        return 0;
    }
    DWORD pid = 0;
    GetWindowThreadProcessId(hwnd, &pid);
    std::wstring path = GetProcessPath(pid);
    std::wstring procName;
    if (!path.empty()) {
        size_t slash = path.find_last_of(L"\\/");
        procName = (slash != std::wstring::npos) ? path.substr(slash + 1) : path;
        procName = ToLower(procName);
        if (procName.size() > 4 && procName.substr(procName.size() - 4) == L".exe") {
            procName = procName.substr(0, procName.size() - 4);
        }
    }
    wchar_t titleBuf[512] = { 0 };
    GetWindowTextW(hwnd, titleBuf, 511);

    std::cout << "{\"process\":\"" << EscapeJsonString(WideToUtf8(procName))
              << "\",\"title\":\"" << EscapeJsonString(WideToUtf8(std::wstring(titleBuf)))
              << "\"}" << std::endl;
    return 0;
}

int DoToggleTopmost() {
    HWND hwnd = GetForegroundWindow();
    if (!hwnd) {
        std::cout << "{\"pinned\":false,\"title\":\"\"}" << std::endl;
        return 1;
    }
    LONG_PTR exStyle = GetWindowLongPtrW(hwnd, GWL_EXSTYLE);
    bool isTopmost = (exStyle & WS_EX_TOPMOST) != 0;
    bool nextPinned = !isTopmost;
    SetWindowPos(
        hwnd,
        nextPinned ? HWND_TOPMOST : HWND_NOTOPMOST,
        0, 0, 0, 0,
        SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE
    );
    wchar_t titleBuf[256] = { 0 };
    GetWindowTextW(hwnd, titleBuf, 255);
    std::cout << "{\"pinned\":" << (nextPinned ? "true" : "false")
              << ",\"title\":\"" << EscapeJsonString(WideToUtf8(std::wstring(titleBuf)))
              << "\"}" << std::endl;
    return 0;
}

std::string Base64Decode(const std::string& in) {
    static const int T[256] = {
        -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
        -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
        -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,62,-1,-1,-1,63,
        52,53,54,55,56,57,58,59,60,61,-1,-1,-1,-1,-1,-1,
        -1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,
        15,16,17,18,19,20,21,22,23,24,25,-1,-1,-1,-1,-1,
        -1,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,
        41,42,43,44,45,46,47,48,49,50,51,-1,-1,-1,-1,-1,
        -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
        -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
        -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
        -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
        -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
        -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
        -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
        -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1
    };
    std::string out;
    int val = 0, valb = -8;
    for (unsigned char c : in) {
        if (T[c] == -1) break;
        val = (val << 6) + T[c];
        valb += 6;
        if (valb >= 0) {
            out.push_back(char((val >> valb) & 0xFF));
            valb -= 8;
        }
    }
    return out;
}

int DoGetClipboard() {
    std::string text;
    if (OpenClipboard(NULL)) {
        HANDLE hData = GetClipboardData(CF_UNICODETEXT);
        if (hData) {
            LPCWSTR pText = static_cast<LPCWSTR>(GlobalLock(hData));
            if (pText) {
                text = WideToUtf8(std::wstring(pText));
                GlobalUnlock(hData);
            }
        }
        CloseClipboard();
    }
    std::cout << "{\"text\":\"" << EscapeJsonString(text) << "\"}" << std::endl;
    return 0;
}

int DoSetClipboard(const std::string& base64Utf8) {
    std::string utf8 = Base64Decode(base64Utf8);
    std::wstring wide = Utf8ToWide(utf8);
    if (!OpenClipboard(NULL)) return 1;
    EmptyClipboard();
    size_t bytes = (wide.size() + 1) * sizeof(wchar_t);
    HGLOBAL hMem = GlobalAlloc(GMEM_MOVEABLE, bytes);
    if (!hMem) {
        CloseClipboard();
        return 1;
    }
    void* ptr = GlobalLock(hMem);
    memcpy(ptr, wide.c_str(), bytes);
    GlobalUnlock(hMem);
    SetClipboardData(CF_UNICODETEXT, hMem);
    CloseClipboard();
    return 0;
}

// =========================================================================
// FLOATING OSD / HUD DAEMON (GDI+ Layered Window, Click-Through, No-Focus)
// =========================================================================
struct OsdPayload {
    std::string kind = "slider"; // "slider" | "badge"
    std::string icon = "volume";
    std::wstring title = L"Hub Agent";
    std::wstring subtitle = L"";
    int value = 0; // 0..100
    COLORREF accent = RGB(203, 166, 247);
    std::string position = "bottom_center"; // bottom_center | top_center | top_right
    int durationMs = 1800;
};

std::string ExtractJsonStr(const std::string& json, const std::string& key, const std::string& def = "") {
    std::string needle = "\"" + key + "\":\"";
    size_t pos = json.find(needle);
    if (pos == std::string::npos) return def;
    pos += needle.size();
    std::string out;
    while (pos < json.size()) {
        char c = json[pos++];
        if (c == '\\' && pos < json.size()) {
            char next = json[pos++];
            if (next == 'n') out += '\n';
            else if (next == 't') out += '\t';
            else out += next;
        } else if (c == '"') {
            break;
        } else {
            out += c;
        }
    }
    return out;
}

int ExtractJsonInt(const std::string& json, const std::string& key, int def = 0) {
    std::string needle = "\"" + key + "\":";
    size_t pos = json.find(needle);
    if (pos == std::string::npos) return def;
    pos += needle.size();
    while (pos < json.size() && (json[pos] == ' ' || json[pos] == '"')) pos++;
    try {
        return std::stoi(json.substr(pos));
    } catch (...) {
        return def;
    }
}

COLORREF ParseHexColor(const std::string& hex, COLORREF fallback) {
    std::string s = hex;
    if (!s.empty() && s[0] == '#') s = s.substr(1);
    if (s.size() != 6) return fallback;
    try {
        unsigned long val = std::stoul(s, nullptr, 16);
        return RGB((val >> 16) & 0xFF, (val >> 8) & 0xFF, val & 0xFF);
    } catch (...) {
        return fallback;
    }
}

constexpr UINT WM_OSD_UPDATE = WM_APP + 10;
constexpr UINT_PTR kOsdAnimTimerId = 1;
constexpr int kOsdWidth = 320;
constexpr int kOsdHeight = 68;

std::mutex g_osdMutex;
OsdPayload g_osdCurrent;
std::atomic<bool> g_osdRunning{ true };

void AddRoundedRectPath(Gdiplus::GraphicsPath& path, Gdiplus::REAL x, Gdiplus::REAL y, Gdiplus::REAL w, Gdiplus::REAL h, Gdiplus::REAL r) {
    Gdiplus::REAL d = r * 2.0f;
    path.AddArc(x, y, d, d, 180, 90);
    path.AddArc(x + w - d, y, d, d, 270, 90);
    path.AddArc(x + w - d, y + h - d, d, d, 0, 90);
    path.AddArc(x, y + h - d, d, d, 90, 90);
    path.CloseFigure();
}

void RenderOsdWindow(HWND hwnd, const OsdPayload& p, BYTE masterAlpha) {
    HDC screenDC = GetDC(NULL);
    HDC memDC = CreateCompatibleDC(screenDC);

    BITMAPINFO bmi = {};
    bmi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    bmi.bmiHeader.biWidth = kOsdWidth;
    bmi.bmiHeader.biHeight = -kOsdHeight;
    bmi.bmiHeader.biPlanes = 1;
    bmi.bmiHeader.biBitCount = 32;
    bmi.bmiHeader.biCompression = BI_RGB;

    void* pvBits = nullptr;
    HBITMAP hBmp = CreateDIBSection(memDC, &bmi, DIB_RGB_COLORS, &pvBits, NULL, 0);
    HGDIOBJ oldBmp = SelectObject(memDC, hBmp);

    {
        Gdiplus::Graphics g(memDC);
        g.SetSmoothingMode(Gdiplus::SmoothingModeAntiAlias);
        g.SetTextRenderingHint(Gdiplus::TextRenderingHintAntiAliasGridFit);
        g.Clear(Gdiplus::Color(0, 0, 0, 0));

        BYTE ar = GetRValue(p.accent);
        BYTE ag = GetGValue(p.accent);
        BYTE ab = GetBValue(p.accent);

        // Pílula de fundo translúcida escura (Catppuccin Mantle)
        Gdiplus::GraphicsPath bgPath;
        AddRoundedRectPath(bgPath, 2.0f, 2.0f, kOsdWidth - 4.0f, kOsdHeight - 4.0f, 18.0f);
        Gdiplus::SolidBrush bgBrush(Gdiplus::Color(236, 24, 24, 37));
        g.FillPath(&bgBrush, &bgPath);

        Gdiplus::Pen borderPen(Gdiplus::Color(115, ar, ag, ab), 1.3f);
        g.DrawPath(&borderPen, &bgPath);

        // Círculo do ícone à esquerda
        Gdiplus::SolidBrush badgeBrush(Gdiplus::Color(42, ar, ag, ab));
        g.FillEllipse(&badgeBrush, 14.0f, 15.0f, 38.0f, 38.0f);

        Gdiplus::FontFamily fontFamily(L"Segoe UI");
        Gdiplus::Font iconFont(&fontFamily, 14.0f, Gdiplus::FontStyleBold, Gdiplus::UnitPixel);
        Gdiplus::Font titleFont(&fontFamily, 13.5f, Gdiplus::FontStyleBold, Gdiplus::UnitPixel);
        Gdiplus::Font valFont(&fontFamily, 13.5f, Gdiplus::FontStyleBold, Gdiplus::UnitPixel);
        Gdiplus::Font subFont(&fontFamily, 12.0f, Gdiplus::FontStyleRegular, Gdiplus::UnitPixel);

        Gdiplus::SolidBrush accentBrush(Gdiplus::Color(255, ar, ag, ab));
        Gdiplus::SolidBrush textBrush(Gdiplus::Color(255, 205, 214, 244));
        Gdiplus::SolidBrush subBrush(Gdiplus::Color(210, 166, 173, 200));

        std::wstring glyph = L"VOL";
        if (p.icon == "brightness") glyph = L"BRI";
        else if (p.icon == "mic") glyph = L"MIC";
        else if (p.icon == "mic_off") glyph = L"OFF";
        else if (p.icon == "sound") glyph = L"SFX";
        else if (p.icon == "pomodoro") glyph = L"POM";
        else if (p.icon == "pin") glyph = L"PIN";
        else if (p.icon == "clip") glyph = L"CLP";
        else if (p.icon == "toggle") glyph = L"A/B";
        else if (p.icon == "mute") glyph = L"MUT";

        Gdiplus::StringFormat centerFmt;
        centerFmt.SetAlignment(Gdiplus::StringAlignmentCenter);
        centerFmt.SetLineAlignment(Gdiplus::StringAlignmentCenter);
        Gdiplus::Font badgeTextFont(&fontFamily, 10.5f, Gdiplus::FontStyleBold, Gdiplus::UnitPixel);
        Gdiplus::RectF iconRect(14.0f, 15.0f, 38.0f, 38.0f);
        g.DrawString(glyph.c_str(), -1, &badgeTextFont, iconRect, &centerFmt, &accentBrush);

        if (p.kind == "slider") {
            Gdiplus::StringFormat leftFmt;
            leftFmt.SetTrimming(Gdiplus::StringTrimmingEllipsisCharacter);
            leftFmt.SetFormatFlags(Gdiplus::StringFormatFlagsNoWrap);
            Gdiplus::RectF titleRect(62.0f, 14.0f, 185.0f, 20.0f);
            g.DrawString(p.title.c_str(), -1, &titleFont, titleRect, &leftFmt, &textBrush);

            Gdiplus::StringFormat rightFmt;
            rightFmt.SetAlignment(Gdiplus::StringAlignmentFar);
            std::wstring valStr = p.subtitle.empty() ? (std::to_wstring(std::clamp(p.value, 0, 100)) + L"%") : p.subtitle;
            Gdiplus::RectF valRect(245.0f, 14.0f, 58.0f, 20.0f);
            g.DrawString(valStr.c_str(), -1, &valFont, valRect, &rightFmt, &accentBrush);

            // Barra de progresso arredondada
            Gdiplus::REAL barX = 62.0f;
            Gdiplus::REAL barY = 42.0f;
            Gdiplus::REAL barW = 240.0f;
            Gdiplus::REAL barH = 8.0f;

            Gdiplus::GraphicsPath trackPath;
            AddRoundedRectPath(trackPath, barX, barY, barW, barH, 4.0f);
            Gdiplus::SolidBrush trackBrush(Gdiplus::Color(255, 49, 50, 68));
            g.FillPath(&trackBrush, &trackPath);

            int pct = std::clamp(p.value, 0, 100);
            if (pct > 0) {
                Gdiplus::REAL fillW = std::max(8.0f, barW * (pct / 100.0f));
                Gdiplus::GraphicsPath fillPath;
                AddRoundedRectPath(fillPath, barX, barY, fillW, barH, 4.0f);
                g.FillPath(&accentBrush, &fillPath);
            }
        } else {
            Gdiplus::StringFormat leftFmt;
            leftFmt.SetTrimming(Gdiplus::StringTrimmingEllipsisCharacter);
            leftFmt.SetFormatFlags(Gdiplus::StringFormatFlagsNoWrap);
            Gdiplus::RectF titleRect(62.0f, 15.0f, 240.0f, 20.0f);
            g.DrawString(p.title.c_str(), -1, &titleFont, titleRect, &leftFmt, &textBrush);
            Gdiplus::RectF subRect(62.0f, 36.0f, 240.0f, 18.0f);
            g.DrawString(p.subtitle.c_str(), -1, &subFont, subRect, &leftFmt, &subBrush);
        }
    }

    // Posiciona na área útil do monitor primário
    RECT workArea = {};
    SystemParametersInfoW(SPI_GETWORKAREA, 0, &workArea, 0);
    int screenW = workArea.right - workArea.left;
    int posX = workArea.left + (screenW - kOsdWidth) / 2;
    int posY = workArea.bottom - kOsdHeight - 44;

    if (p.position == "top_center") {
        posX = workArea.left + (screenW - kOsdWidth) / 2;
        posY = workArea.top + 24;
    } else if (p.position == "top_right") {
        posX = workArea.right - kOsdWidth - 24;
        posY = workArea.top + 24;
    }

    POINT ptDst = { posX, posY };
    SIZE wndSize = { kOsdWidth, kOsdHeight };
    POINT ptSrc = { 0, 0 };
    BLENDFUNCTION blend = {};
    blend.BlendOp = AC_SRC_OVER;
    blend.SourceConstantAlpha = masterAlpha;
    blend.AlphaFormat = AC_SRC_ALPHA;

    UpdateLayeredWindow(hwnd, screenDC, &ptDst, &wndSize, memDC, &ptSrc, 0, &blend, ULW_ALPHA);

    SelectObject(memDC, oldBmp);
    DeleteObject(hBmp);
    DeleteDC(memDC);
    ReleaseDC(NULL, screenDC);
}

struct OsdAnimState {
    bool visible = false;
    float alpha = 0.0f;
    std::chrono::steady_clock::time_point hideAt;
    OsdPayload payload;
};

LRESULT CALLBACK OsdWndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    auto* st = reinterpret_cast<OsdAnimState*>(GetWindowLongPtrW(hwnd, GWLP_USERDATA));
    switch (msg) {
        case WM_OSD_UPDATE: {
            if (!st) break;
            {
                std::lock_guard<std::mutex> lock(g_osdMutex);
                st->payload = g_osdCurrent;
            }
            st->hideAt = std::chrono::steady_clock::now() + std::chrono::milliseconds(std::clamp(st->payload.durationMs, 400, 8000));
            if (!st->visible) {
                st->visible = true;
                ShowWindow(hwnd, SW_SHOWNOACTIVATE);
            }
            if (st->alpha < 0.25f) st->alpha = 0.25f;
            RenderOsdWindow(hwnd, st->payload, static_cast<BYTE>(st->alpha * 255.0f));
            SetTimer(hwnd, kOsdAnimTimerId, 16, NULL);
            return 0;
        }
        case WM_TIMER: {
            if (wParam == kOsdAnimTimerId && st) {
                auto now = std::chrono::steady_clock::now();
                if (now < st->hideAt) {
                    if (st->alpha < 1.0f) {
                        st->alpha = std::min(1.0f, st->alpha + 0.16f);
                        RenderOsdWindow(hwnd, st->payload, static_cast<BYTE>(st->alpha * 255.0f));
                    }
                } else {
                    st->alpha = std::max(0.0f, st->alpha - 0.10f);
                    if (st->alpha <= 0.01f) {
                        st->alpha = 0.0f;
                        st->visible = false;
                        KillTimer(hwnd, kOsdAnimTimerId);
                        ShowWindow(hwnd, SW_HIDE);
                    } else {
                        RenderOsdWindow(hwnd, st->payload, static_cast<BYTE>(st->alpha * 255.0f));
                    }
                }
            }
            return 0;
        }
        case WM_DESTROY:
            PostQuitMessage(0);
            return 0;
    }
    return DefWindowProcW(hwnd, msg, wParam, lParam);
}

int DoOsdDaemon() {
    Gdiplus::GdiplusStartupInput gdiInput;
    ULONG_PTR gdiToken = 0;
    Gdiplus::GdiplusStartup(&gdiToken, &gdiInput, NULL);

    HINSTANCE hInst = GetModuleHandleW(NULL);
    const wchar_t* kCls = L"HubAgentOsdOverlayClass";
    WNDCLASSEXW wc = {};
    wc.cbSize = sizeof(wc);
    wc.lpfnWndProc = OsdWndProc;
    wc.hInstance = hInst;
    wc.lpszClassName = kCls;
    RegisterClassExW(&wc);

    OsdAnimState animState;
    HWND hwnd = CreateWindowExW(
        WS_EX_LAYERED | WS_EX_TRANSPARENT | WS_EX_TOPMOST | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE,
        kCls,
        L"HubAgentOSD",
        WS_POPUP,
        0, 0, kOsdWidth, kOsdHeight,
        NULL, NULL, hInst, NULL
    );
    if (!hwnd) {
        Gdiplus::GdiplusShutdown(gdiToken);
        return 1;
    }
    SetWindowLongPtrW(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(&animState));

    std::thread reader([hwnd]() {
        std::string line;
        while (std::getline(std::cin, line)) {
            if (line.empty()) continue;
            if (line == "quit") break;
            OsdPayload p;
            p.kind = ExtractJsonStr(line, "kind", "slider");
            p.icon = ExtractJsonStr(line, "icon", "volume");
            p.title = Utf8ToWide(ExtractJsonStr(line, "title", "Hub Agent"));
            p.subtitle = Utf8ToWide(ExtractJsonStr(line, "subtitle", ""));
            p.value = ExtractJsonInt(line, "value", 0);
            p.accent = ParseHexColor(ExtractJsonStr(line, "accent", "#cba6f7"), RGB(203, 166, 247));
            p.position = ExtractJsonStr(line, "position", "bottom_center");
            p.durationMs = ExtractJsonInt(line, "duration_ms", 1800);
            {
                std::lock_guard<std::mutex> lock(g_osdMutex);
                g_osdCurrent = p;
            }
            PostMessageW(hwnd, WM_OSD_UPDATE, 0, 0);
        }
        g_osdRunning = false;
        PostMessageW(hwnd, WM_CLOSE, 0, 0);
    });

    MSG msg;
    while (GetMessageW(&msg, NULL, 0, 0) > 0) {
        TranslateMessage(&msg);
        DispatchMessageW(&msg);
    }

    if (reader.joinable()) reader.detach();
    Gdiplus::GdiplusShutdown(gdiToken);
    return 0;
}

bool ParseHotkeyCombo(const std::string& rawCombo, UINT& outMods, UINT& outVk) {
    outMods = MOD_NOREPEAT;
    outVk = 0;

    std::string lower = rawCombo;
    std::transform(lower.begin(), lower.end(), lower.begin(),
                   [](unsigned char c) { return static_cast<char>(std::tolower(c)); });

    std::stringstream ss(lower);
    std::string token;
    while (std::getline(ss, token, '+')) {
        // Trim whitespace
        size_t s = token.find_first_not_of(" \t\r\n");
        if (s == std::string::npos) continue;
        size_t e = token.find_last_not_of(" \t\r\n");
        token = token.substr(s, e - s + 1);

        if (token == "ctrl" || token == "control") {
            outMods |= MOD_CONTROL;
        } else if (token == "alt") {
            outMods |= MOD_ALT;
        } else if (token == "shift") {
            outMods |= MOD_SHIFT;
        } else if (token == "win" || token == "windows" || token == "super" || token == "meta") {
            outMods |= MOD_WIN;
        } else if (token == "space" || token == "spc") {
            outVk = VK_SPACE;
        } else if (token == "tab") {
            outVk = VK_TAB;
        } else if (token == "enter" || token == "return") {
            outVk = VK_RETURN;
        } else if (token == "esc" || token == "escape") {
            outVk = VK_ESCAPE;
        } else if (token == "backspace" || token == "bksp") {
            outVk = VK_BACK;
        } else if (token == "del" || token == "delete") {
            outVk = VK_DELETE;
        } else if (token == "ins" || token == "insert") {
            outVk = VK_INSERT;
        } else if (token == "home") {
            outVk = VK_HOME;
        } else if (token == "end") {
            outVk = VK_END;
        } else if (token == "pageup" || token == "prior") {
            outVk = VK_PRIOR;
        } else if (token == "pagedown" || token == "next") {
            outVk = VK_NEXT;
        } else if (token == "up") {
            outVk = VK_UP;
        } else if (token == "down") {
            outVk = VK_DOWN;
        } else if (token == "left") {
            outVk = VK_LEFT;
        } else if (token == "right") {
            outVk = VK_RIGHT;
        } else if (token == "print" || token == "printscreen" || token == "prtscn") {
            outVk = VK_SNAPSHOT;
        } else if (token.size() >= 2 && token[0] == 'f') {
            int fnum = std::atoi(token.c_str() + 1);
            if (fnum >= 1 && fnum <= 24) {
                outVk = static_cast<UINT>(VK_F1 + (fnum - 1));
            }
        } else if (token.size() == 1) {
            unsigned char ch = static_cast<unsigned char>(token[0]);
            if (ch >= 'a' && ch <= 'z') {
                outVk = static_cast<UINT>('A' + (ch - 'a'));
            } else if (ch >= '0' && ch <= '9') {
                outVk = static_cast<UINT>(ch);
            } else {
                SHORT vkRes = VkKeyScanA(static_cast<char>(ch));
                if (vkRes != -1) {
                    outVk = static_cast<UINT>(vkRes & 0xFF);
                }
            }
        }
    }

    return outVk != 0;
}

int DoWatchHotkey(const std::string& combo) {
    UINT mods = 0;
    UINT vk = 0;
    if (!ParseHotkeyCombo(combo, mods, vk)) {
        std::cout << "{\"event\":\"error\",\"message\":\"invalid_combo\"}" << std::endl;
        return 1;
    }

    const int kHotkeyId = 1;
    if (!RegisterHotKey(NULL, kHotkeyId, mods, vk)) {
        std::cout << "{\"event\":\"error\",\"message\":\"hotkey_in_use\"}" << std::endl;
        return 2;
    }

    std::cout << "{\"event\":\"ready\",\"combo\":\"" << EscapeJsonString(combo) << "\"}" << std::endl;

    MSG msg;
    while (GetMessageW(&msg, NULL, 0, 0) > 0) {
        if (msg.message == WM_HOTKEY && msg.wParam == kHotkeyId) {
            std::cout << "{\"event\":\"triggered\",\"combo\":\"" << EscapeJsonString(combo) << "\"}" << std::endl;
        }
    }

    UnregisterHotKey(NULL, kHotkeyId);
    return 0;
}

} // namespace

int main(int argc, char* argv[]) {
    if (argc < 2) {
        std::cerr << "Usage: hub_audio_helper <status|list-devices|watch-notifications|play-sound <file> [device] [volume]|set-master <0-100>|set-master-mute <0|1>|set-app <target> <0-100>|set-app-mute <target> <0|1>>\n";
        return 1;
    }

    CoInitializeEx(NULL, COINIT_MULTITHREADED);
    int res = 0;
    std::string cmd = argv[1];

    if (cmd == "status") {
        res = DoStatus();
    } else if (cmd == "list-devices") {
        res = DoListDevices();
    } else if (cmd == "watch-notifications") {
        res = DoWatchNotifications();
    } else if (cmd == "play-sound" && argc >= 3) {
        std::wstring filePath = Utf8ToWide(argv[2]);
        std::string targetDevice = (argc >= 4) ? argv[3] : "";
        int volumePercent = (argc >= 5) ? std::stoi(argv[4]) : 100;
        res = DoPlaySound(filePath, targetDevice, volumePercent);
    } else if (cmd == "set-master" && argc >= 3) {
        res = DoSetMaster(std::stoi(argv[2]));
    } else if (cmd == "set-master-mute" && argc >= 3) {
        res = DoSetMasterMute(std::stoi(argv[2]) != 0);
    } else if (cmd == "set-app" && argc >= 4) {
        res = DoSetApp(argv[2], std::stoi(argv[3]));
    } else if (cmd == "set-app-mute" && argc >= 4) {
        res = DoSetAppMute(argv[2], std::stoi(argv[3]) != 0);
    } else if (cmd == "media-status") {
        res = DoMediaStatus();
    } else if (cmd == "media-control") {
        res = DoMediaControl(argc, argv);
    } else if (cmd == "stats") {
        res = DoStats();
    } else if (cmd == "list-displays") {
        res = DoListDisplays();
    } else if (cmd == "get-brightness") {
        int dispNum = (argc >= 3) ? std::stoi(argv[2]) : 0;
        res = DoGetBrightness(dispNum);
    } else if (cmd == "set-brightness" && argc >= 4) {
        res = DoSetBrightness(argv[2], std::stoi(argv[3]));
    } else if (cmd == "set-mic-mute" && argc >= 3) {
        res = DoSetMicMute(std::stoi(argv[2]) != 0);
    } else if (cmd == "batteries") {
        res = DoBatteries();
    } else if (cmd == "active-window") {
        res = DoActiveWindow();
    } else if (cmd == "toggle-topmost") {
        res = DoToggleTopmost();
    } else if (cmd == "get-clipboard") {
        res = DoGetClipboard();
    } else if (cmd == "set-clipboard" && argc >= 3) {
        res = DoSetClipboard(argv[2]);
    } else if (cmd == "osd-daemon") {
        res = DoOsdDaemon();
    } else if (cmd == "watch-hotkey" && argc >= 3) {
        res = DoWatchHotkey(argv[2]);
    } else {
        std::cerr << "Unknown command or missing arguments: " << cmd << "\n";
        res = 1;
    }

    CoUninitialize();
    return res;
}
