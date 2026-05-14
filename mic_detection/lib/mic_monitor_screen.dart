import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mic_info/mic_info.dart';
import 'package:mic_info/model/mic_info_model.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

// ── Isolated waveform widget — only this rebuilds on amplitude changes ────────

class _WaveformDisplay extends StatefulWidget {
  final Stream<double> levelStream;
  final bool active;

  const _WaveformDisplay({required this.levelStream, required this.active});

  @override
  State<_WaveformDisplay> createState() => _WaveformDisplayState();
}

class _WaveformDisplayState extends State<_WaveformDisplay> {
  static const int _barCount = 28;
  final List<double> _waveform = List.filled(_barCount, 0.0);
  double _inputLevel = 0.0;
  StreamSubscription<double>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.levelStream.listen((level) {
      setState(() {
        _inputLevel = level;
        _waveform.removeAt(0);
        _waveform.add(level);
      });
    });
  }

  @override
  void didUpdateWidget(_WaveformDisplay old) {
    super.didUpdateWidget(old);
    if (!widget.active) {
      setState(() {
        _inputLevel = 0.0;
        for (int i = 0; i < _barCount; i++) _waveform[i] = 0.0;
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Waveform bars
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: widget.active
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: List.generate(_barCount, (i) {
                    final h = (_waveform[i] * 44).clamp(3.0, 44.0);
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 60),
                      curve: Curves.easeOut,
                      width: 3.5,
                      height: h,
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      decoration: BoxDecoration(
                        color: Color.lerp(Colors.green.shade300, Colors.green.shade700, _waveform[i]),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                )
              : Center(
                  child: Text(
                    'Waveform appears when mic is on',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                  ),
                ),
        ),
        const SizedBox(height: 12),

        // Input level meter
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Input Level',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                ),
                const SizedBox(width: 6),
                Text(
                  widget.active ? 'live' : 'mic off',
                  style: TextStyle(fontSize: 11, color: widget.active ? Colors.green : Colors.grey.shade400),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _inputLevel,
                minHeight: 10,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _inputLevel > 0.8
                      ? Colors.red
                      : _inputLevel > 0.5
                      ? Colors.orange
                      : Colors.green,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Low', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                Text('Mid', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                Text('High', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

// ── Main screen ───────────────────────────────────────────────────────────────

class MicMonitorScreen extends StatefulWidget {
  const MicMonitorScreen({super.key});

  @override
  State<MicMonitorScreen> createState() => _MicMonitorScreenState();
}

class _MicMonitorScreenState extends State<MicMonitorScreen> {
  List<MicInfoDevice> _activeDevices = [];
  List<MicInfoDevice> _bluetoothDevices = [];
  List<MicInfoDevice> _wiredDevices = [];
  List<MicInfoDevice> _defaultDevices = [];

  bool _permissionGranted = false;
  bool _micEnabled = false;

  Timer? _pollingTimer;
  final AudioRecorder _recorder = AudioRecorder();

  // Amplitude broadcast stream — fed into _WaveformDisplay only
  final StreamController<double> _levelController = StreamController<double>.broadcast();

  StreamSubscription<Amplitude>? _amplitudeSub;
  String? _tempFilePath;

  // Input device list: built by merging record's list + mic_info BT list
  List<InputDevice> _inputDevices = [];
  InputDevice? _selectedDevice;

  @override
  void initState() {
    super.initState();
    _requestPermissionAndStart();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _amplitudeSub?.cancel();
    _levelController.close();
    _recorder.stop();
    _recorder.dispose();
    _deleteTempFile();
    super.dispose();
  }

  // ── Permissions + startup ─────────────────────────────────────────────────

  Future<void> _requestPermissionAndStart() async {
    final status = await Permission.microphone.request();
    setState(() => _permissionGranted = status.isGranted);
    if (status.isGranted) {
      await Future.wait([_fetchMicInfo(), _refreshInputDevices()]);
      _pollingTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
        await _fetchMicInfo();
        await _refreshInputDevices();
      });
    }
  }

  // ── Device list: merge record + mic_info bluetooth ────────────────────────
  //
  // record's listInputDevices() uses AudioManager and sometimes misses BT.
  // mic_info's getBluetoothMicrophones() reliably finds BT devices.
  // We merge both, deduplicating by id, so BT always appears.

  Future<void> _refreshInputDevices() async {
    final recordDevices = await _recorder.listInputDevices();
    final btMicDevices = await MicInfo.getBluetoothMicrophones();

    final merged = List<InputDevice>.from(recordDevices);

    for (final bt in btMicDevices) {
      final btId = bt.id?.toString() ?? '';
      final alreadyPresent = merged.any((d) => d.id == btId);
      if (!alreadyPresent && btId.isNotEmpty) {
        merged.add(InputDevice(id: btId, label: bt.productName ?? 'Bluetooth Mic ($btId)'));
      }
    }

    setState(() {
      _inputDevices = merged;
      final ids = merged.map((d) => d.id).toSet();
      if (_selectedDevice != null && !ids.contains(_selectedDevice!.id)) {
        _selectedDevice = merged.isNotEmpty ? merged.first : null;
      }
      _selectedDevice ??= merged.isNotEmpty ? merged.first : null;
    });
  }

  // ── mic_info polling ──────────────────────────────────────────────────────

  Future<void> _fetchMicInfo() async {
    final active = await MicInfo.getActiveMicrophones();
    final bluetooth = await MicInfo.getBluetoothMicrophones();
    final wired = await MicInfo.getWiredMicrophones();
    final defaults = await MicInfo.getDefaultMicrophones();
    setState(() {
      _activeDevices = active;
      _bluetoothDevices = bluetooth;
      _wiredDevices = wired;
      _defaultDevices = defaults;
    });
  }

  // ── Recording ─────────────────────────────────────────────────────────────

  Future<String> _getTempPath() async {
    final dir = await getTemporaryDirectory();
    return '${dir.path}/mic_monitor_temp.m4a';
  }

  void _deleteTempFile() {
    if (_tempFilePath != null) {
      final f = File(_tempFilePath!);
      if (f.existsSync()) f.deleteSync();
      _tempFilePath = null;
    }
  }

  Future<void> _startRecording() async {
    _tempFilePath = await _getTempPath();

    // Find matching InputDevice from record's own list (BT synthetic entries
    // may not be accepted by record — fall back to null = system default)
    final recordIds = (await _recorder.listInputDevices()).map((d) => d.id).toSet();
    final deviceForRecord = (_selectedDevice != null && recordIds.contains(_selectedDevice!.id))
        ? _selectedDevice
        : null;

    await _recorder.start(
      RecordConfig(
        encoder: AudioEncoder.aacLc, // universally supported
        device: deviceForRecord,
      ),
      path: _tempFilePath!,
    );

    _amplitudeSub = _recorder.onAmplitudeChanged(const Duration(milliseconds: 60)).listen((amp) {
      // dBFS: -60 silence → 0 max, normalize to 0.0–1.0
      final level = ((amp.current + 60) / 60).clamp(0.0, 1.0);
      _levelController.add(level);
    });
  }

  Future<void> _stopRecording() async {
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;
    await _recorder.stop();
    _deleteTempFile();
    _levelController.add(0.0);
  }

  Future<void> _toggleMic(bool value) async {
    value ? await _startRecording() : await _stopRecording();
    setState(() => _micEnabled = value);
    await Future.delayed(const Duration(milliseconds: 300));
    await _fetchMicInfo();
  }

  Future<void> _onDeviceChanged(InputDevice? device) async {
    setState(() => _selectedDevice = device);
    if (_micEnabled) {
      await _stopRecording();
      await _startRecording();
      setState(() => _micEnabled = true);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(title: const Text('Mic Monitor'), backgroundColor: Colors.blueGrey, elevation: 1),
      body: !_permissionGranted
          ? Center(
              child: ElevatedButton.icon(
                onPressed: _requestPermissionAndStart,
                icon: const Icon(Icons.mic),
                label: const Text('Grant Microphone Permission'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _card(
                  children: [
                    _buildMicToggleRow(),
                    const SizedBox(height: 16),
                    _WaveformDisplay(levelStream: _levelController.stream, active: _micEnabled),
                  ],
                ),
                const SizedBox(height: 12),
                _card(children: [_buildDeviceSelector()]),
                const SizedBox(height: 12),
                _card(
                  children: [
                    _buildSection('Active', Icons.graphic_eq, _activeDevices),
                    _buildSection('Bluetooth', Icons.bluetooth_audio, _bluetoothDevices),
                    _buildSection('Wired', Icons.headset_mic, _wiredDevices),
                    _buildSection('Default', Icons.mic, _defaultDevices),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
    );
  }

  Widget _card({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _buildMicToggleRow() {
    final on = _micEnabled;
    return Row(
      children: [
        Icon(on ? Icons.mic : Icons.mic_off, size: 28, color: on ? Colors.green : Colors.red),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              on ? 'Microphone On' : 'Microphone Off',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: on ? Colors.green.shade700 : Colors.red.shade700,
              ),
            ),
            Text(
              _activeDevices.isNotEmpty ? '${_activeDevices.length} device(s) active' : 'No active devices',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
        const Spacer(),
        Switch(value: _micEnabled, onChanged: _toggleMic, activeColor: Colors.green),
      ],
    );
  }

  Widget _buildDeviceSelector() {
    if (_inputDevices.isEmpty) {
      return Row(
        children: [
          Icon(Icons.devices, size: 18, color: Colors.grey.shade400),
          const SizedBox(width: 8),
          Text('No input devices found', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.settings_input_svideo, size: 14, color: Colors.grey.shade500),
            const SizedBox(width: 6),
            Text(
              'Input Device',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<InputDevice>(
          value: _selectedDevice,
          isExpanded: true,
          decoration: InputDecoration(
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          ),
          items: _inputDevices.map((d) {
            return DropdownMenuItem<InputDevice>(
              value: d,
              child: Text(
                d.label.isNotEmpty ? d.label : 'Device ${d.id}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, letterSpacing: -0.5),
              ),
            );
          }).toList(),
          onChanged: _onDeviceChanged,
        ),
      ],
    );
  }

  Widget _buildSection(String title, IconData icon, List<MicInfoDevice> devices) {
    final isLast = title == 'Default';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.grey.shade500),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
              child: Text('${devices.length}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        devices.isEmpty
            ? Padding(
                padding: const EdgeInsets.only(left: 20, bottom: 4),
                child: Text('None', style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
              )
            : Column(
                children: devices
                    .map(
                      (d) => Padding(
                        padding: const EdgeInsets.only(left: 20, bottom: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.green),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(d.productName ?? 'Unknown', style: const TextStyle(fontSize: 13))),
                            Text('ID: ${d.id ?? '-'}', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
        if (!isLast) Divider(height: 20, color: Colors.grey.shade100),
      ],
    );
  }
}
