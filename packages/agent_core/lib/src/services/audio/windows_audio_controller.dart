import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import '../../models/audio_state.dart';
import 'audio_controller.dart';

const IID_IAudioEndpointVolume = '{5CDF2C82-841E-4546-9722-0CF74078229A}';

class IAudioEndpointVolume extends IUnknown {
  IAudioEndpointVolume(super.ptr);

  int setMasterVolumeLevelScalar(
          double fLevel, Pointer<GUID> pguidEventContext) =>
      ptr
              .ref.vtable
              .elementAt(7)
              .cast<
                  Pointer<
                      NativeFunction<
                          Int32 Function(Pointer, Float, Pointer<GUID>)>>>()
              .value
              .asFunction<int Function(Pointer, double, Pointer<GUID>)>()(
          ptr.ref.lpVtbl, fLevel, pguidEventContext);

  int getMasterVolumeLevelScalar(Pointer<Float> pfLevel) => ptr.ref.vtable
      .elementAt(9)
      .cast<Pointer<NativeFunction<Int32 Function(Pointer, Pointer<Float>)>>>()
      .value
      .asFunction<
          int Function(Pointer, Pointer<Float>)>()(ptr.ref.lpVtbl, pfLevel);

  int setMute(int bMute, Pointer<GUID> pguidEventContext) => ptr.ref.vtable
      .elementAt(14)
      .cast<
          Pointer<
              NativeFunction<Int32 Function(Pointer, Int32, Pointer<GUID>)>>>()
      .value
      .asFunction<
          int Function(Pointer, int,
              Pointer<GUID>)>()(ptr.ref.lpVtbl, bMute, pguidEventContext);

  int getMute(Pointer<Int32> pbMute) => ptr.ref.vtable
      .elementAt(15)
      .cast<Pointer<NativeFunction<Int32 Function(Pointer, Pointer<Int32>)>>>()
      .value
      .asFunction<
          int Function(Pointer, Pointer<Int32>)>()(ptr.ref.lpVtbl, pbMute);
}

class WindowsAudioController implements AudioController {
  final _masterCtl = StreamController<MasterVolume>.broadcast();
  final _appsCtl = StreamController<List<AppVolume>>.broadcast();

  Timer? _pollTimer;
  bool _available = false;

  MasterVolume _master = const MasterVolume(value: 0);

  @override
  Stream<MasterVolume> get masterChanges => _masterCtl.stream;
  @override
  Stream<List<AppVolume>> get appsChanges => _appsCtl.stream;
  @override
  MasterVolume get master => _master;
  @override
  List<AppVolume> get apps => const [];
  @override
  bool get isAvailable => _available;

  @override
  Future<void> start() async {
    _available = await _tryInit();
    if (!_available) {
      stderr.writeln('audio: COM indisponível no Windows');
      return;
    }
    await refresh();

    _pollTimer =
        Timer.periodic(const Duration(milliseconds: 500), (_) => refresh());
  }

  Future<bool> _tryInit() async {
    try {
      CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> refresh() async {
    if (!_available) return;
    final v = _readMaster();
    if (v != null && v != _master) {
      _master = v;
      if (!_masterCtl.isClosed) _masterCtl.add(v);
    }
  }

  MasterVolume? _readMaster() {
    final enumerator = MMDeviceEnumerator.createInstance();
    final pDevice = calloc<COMObject>();

    try {
      // 0 = eRender, 1 = eMultimedia
      final hr = enumerator.getDefaultAudioEndpoint(0, 1, pDevice.cast());
      if (hr < 0) return null;

      final device = IMMDevice(pDevice);
      final pVol = calloc<COMObject>();
      final iidString = IID_IAudioEndpointVolume.toNativeUtf16();
      final iid = calloc<GUID>();

      try {
        IIDFromString(iidString, iid);
        final hr2 = device.activate(iid, CLSCTX_ALL, nullptr, pVol.cast());
        if (hr2 < 0) return null;

        final vol = IAudioEndpointVolume(pVol);

        final pLevel = calloc<Float>();
        final pMuted = calloc<Int32>();

        try {
          final hr3 = vol.getMasterVolumeLevelScalar(pLevel);
          if (hr3 < 0) return null;

          final hr4 = vol.getMute(pMuted);
          if (hr4 < 0) return null;

          final pct = (pLevel.value * 100).round().clamp(0, 100);
          return MasterVolume(value: pct, muted: pMuted.value != 0);
        } finally {
          free(pLevel);
          free(pMuted);
        }
      } finally {
        free(iidString);
        free(iid);
        _release(pVol);
      }
    } finally {
      free(pDevice);
      enumerator.release();
    }
  }

  @override
  Future<void> setMasterVolume(int value) async {
    if (!_available) return;
    final pct = (value.clamp(0, 100)) / 100.0;
    _withVolume((vol) {
      vol.setMasterVolumeLevelScalar(pct, nullptr);
    });
  }

  @override
  Future<void> setMute(bool muted) async {
    if (!_available) return;
    _withVolume((vol) {
      vol.setMute(muted ? 1 : 0, nullptr);
    });
  }

  @override
  Future<void> setAppVolume(String id, int value) async {}

  @override
  Future<void> setAppVolumeByName(String name, int value) async {}

  void _withVolume(void Function(IAudioEndpointVolume) body) {
    final enumerator = MMDeviceEnumerator.createInstance();
    final pDevice = calloc<COMObject>();

    try {
      if (enumerator.getDefaultAudioEndpoint(0, 1, pDevice.cast()) < 0) {
        return;
      }

      final pVol = calloc<COMObject>();
      final iidString = IID_IAudioEndpointVolume.toNativeUtf16();
      final iid = calloc<GUID>();

      try {
        IIDFromString(iidString, iid);
        final device = IMMDevice(pDevice);
        if (device.activate(iid, CLSCTX_ALL, nullptr, pVol.cast()) < 0) {
          return;
        }
        body(IAudioEndpointVolume(pVol));
      } finally {
        free(iidString);
        free(iid);
        _release(pVol);
      }
    } finally {
      free(pDevice);
      enumerator.release();
    }
  }

  void _release(Pointer<COMObject> obj) {
    try {
      final unk = IUnknown(obj);
      unk.release();
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {
    _pollTimer?.cancel();
    await _masterCtl.close();
    await _appsCtl.close();
  }
}
