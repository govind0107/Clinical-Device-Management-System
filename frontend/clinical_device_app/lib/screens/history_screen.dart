// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:io';
import 'dart:js' as js;
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/models.dart';
import '../providers/history_provider.dart';
import '../services/api_client.dart';
import '../services/local_db.dart';
import '../theme/app_theme.dart';
import '../widgets/state_views.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  SessionModel? _selected;
  List<ReadingModel> _readings = [];
  var _loadingReadings = false;
  double _scrub = 1.0;
  var _isOffline = false;

  Timer? _playbackTimer;
  bool _isPlaying = false;

  void _togglePlayback() {
    if (_isPlaying) {
      _pausePlayback();
    } else {
      _startPlayback();
    }
  }

  void _startPlayback() {
    if (_readings.isEmpty) return;
    if (_scrub >= 1.0) {
      setState(() => _scrub = 0.0);
    }
    _playbackTimer?.cancel();
    setState(() => _isPlaying = true);

    _playbackTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _scrub += 0.01;
        if (_scrub >= 1.0) {
          _scrub = 1.0;
          _pausePlayback();
        }
      });
    });
  }

  void _pausePlayback() {
    _playbackTimer?.cancel();
    setState(() => _isPlaying = false);
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    super.dispose();
  }

  final Map<String, bool> _enabledChannels = {
    'ECG': true,
    'SpO2': true,
    'BP': true,
  };

  static const _channelColors = {
    'ECG': AppTheme.clinicalRed,
    'SpO2': AppTheme.clinicalBlue,
    'BP': AppTheme.clinicalGreen,
  };

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(historySessionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('History & Playback'),
        actions: [
          if (_readings.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.table_chart_outlined),
              tooltip: 'Export CSV',
              onPressed: _exportCsv,
            ),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'Export PDF',
              onPressed: _exportPdf,
            ),
          ],
        ],
      ),
      body: sessionsAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(historySessionsProvider),
        ),
        data: (sessions) {
          final completed = sessions.where((s) => s.endTime != null).toList();
          if (completed.isEmpty) {
            return const EmptyView(
              message: 'No completed sessions yet.\nStop a live session to save it here, then scrub and export.',
              icon: Icons.history,
            );
          }

          return Row(
            children: [
              SizedBox(
                width: 280,
                child: ListView.builder(
                  itemCount: completed.length,
                  itemBuilder: (context, i) {
                    final s = completed[i];
                    final selected = _selected?.sessionId == s.sessionId;
                    return ListTile(
                      selected: selected,
                      title: Text(DateFormat.MMMd().add_jm().format(s.startTime.toLocal())),
                      subtitle: Text('Device ${s.deviceId.substring(0, 8)}...'),
                      onTap: () => _loadSession(s),
                    );
                  },
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: _loadingReadings
                    ? const LoadingView(message: 'Loading readings...')
                    : _selected == null
                        ? const EmptyView(message: 'Select a session to playback.')
                        : _buildPlayback(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPlayback() {
    final channelsPresent = _readings.map((r) => r.channel).toSet();
    if (channelsPresent.isEmpty) {
      return const EmptyView(message: 'No readings for this session.');
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Session ${_selected!.sessionId.substring(0, 8)}...',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (_isOffline) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.clinicalAmber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.clinicalAmber),
                      ),
                      child: const Text(
                        'Offline Cache',
                        style: TextStyle(
                          color: AppTheme.clinicalAmber,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _enabledChannels.keys.where((ch) => channelsPresent.contains(ch)).map((ch) {
                  final on = _enabledChannels[ch] ?? true;
                  return FilterChip(
                    label: Text(ch),
                    selected: on,
                    onSelected: (v) {
                      setState(() {
                        _enabledChannels[ch] = v;
                      });
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: _enabledChannels.entries
                .where((e) => e.value && channelsPresent.contains(e.key))
                .map((e) {
              final ch = e.key;
              final channelReadings = _readings.where((r) => r.channel == ch).toList();
              if (channelReadings.isEmpty) {
                return const SizedBox.shrink();
              }

              final maxIndex = channelReadings.length - 1;
              final index = (_scrub * maxIndex).round().clamp(0, maxIndex);
              final window = channelReadings.sublist(0, index + 1);

              final spots = <FlSpot>[];
              if (window.isNotEmpty) {
                final base = window.first.timestamp.millisecondsSinceEpoch.toDouble();
                for (var i = 0; i < window.length; i++) {
                  final x = (window[i].timestamp.millisecondsSinceEpoch - base) / 1000;
                  spots.add(FlSpot(x, window[i].value));
                }
              }

              var minVal = window.isEmpty ? 0.0 : window.first.value;
              var maxVal = window.isEmpty ? 0.0 : window.first.value;
              var sumVal = 0.0;
              for (final p in window) {
                if (p.value < minVal) minVal = p.value;
                if (p.value > maxVal) maxVal = p.value;
                sumVal += p.value;
              }
              final avgVal = window.isEmpty ? 0.0 : sumVal / window.length;
              final color = _channelColors[ch] ?? Colors.blue;

              // Calculate clean, rounded bounds and intervals to eliminate decimal bounds and overlaps
              final double interval;
              final double minY;
              final double maxY;

              if (ch == 'SpO2') {
                interval = 5;
                minY = ((minVal - 2) / interval).floorToDouble() * interval;
                maxY = ((maxVal + 2) / interval).ceilToDouble() * interval;
              } else if (ch == 'ECG') {
                interval = 20;
                minY = ((minVal - 5) / interval).floorToDouble() * interval;
                maxY = ((maxVal + 5) / interval).ceilToDouble() * interval;
              } else {
                // BP
                interval = 20;
                minY = ((minVal - 10) / interval).floorToDouble() * interval;
                maxY = ((maxVal + 10) / interval).ceilToDouble() * interval;
              }

              return SizedBox(
                height: 180,
                child: Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 48, right: 8),
                          child: Row(
                            children: [
                              Text(ch, style: Theme.of(context).textTheme.titleSmall),
                              const Spacer(),
                              Text('Min ${minVal.toStringAsFixed(1)}'),
                              const SizedBox(width: 8),
                              Text('Avg ${avgVal.toStringAsFixed(1)}'),
                              const SizedBox(width: 8),
                              Text('Max ${maxVal.toStringAsFixed(1)}'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: LineChart(
                            LineChartData(
                              minY: minY,
                              maxY: maxY,
                              gridData: const FlGridData(show: true, drawVerticalLine: false),
                              titlesData: FlTitlesData(
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 40,
                                    interval: interval,
                                    getTitlesWidget: (value, meta) {
                                      return SideTitleWidget(
                                        axisSide: meta.axisSide,
                                        space: 8,
                                        child: Text(
                                          value.toInt().toString(),
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              ),
                              borderData: FlBorderData(show: false),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: spots,
                                  isCurved: true,
                                  color: color,
                                  barWidth: 2,
                                  dotData: const FlDotData(show: false),
                                  belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.12)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              IconButton(
                icon: Icon(_isPlaying ? Icons.pause_circle_outline : Icons.play_circle_outline),
                iconSize: 32,
                onPressed: _togglePlayback,
              ),
              Expanded(
                child: Slider(
                  value: _scrub,
                  onChanged: (v) {
                    if (_isPlaying) _pausePlayback();
                    setState(() => _scrub = v);
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _loadSession(SessionModel session) async {
    _pausePlayback();
    setState(() {
      _selected = session;
      _loadingReadings = true;
      _scrub = 1.0;
      _isOffline = false;
    });
    try {
      final readings = await ref.read(apiServiceProvider).getReadings(session.sessionId);
      setState(() => _readings = readings);
    } catch (e) {
      try {
        final cached = await LocalDb.getCachedReadings(session.sessionId);
        if (cached.isNotEmpty) {
          setState(() {
            _readings = cached;
            _isOffline = true;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Offline: Loaded telemetry data from local SQLite cache.'),
                backgroundColor: AppTheme.clinicalAmber,
              ),
            );
          }
          return;
        }
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load readings: $e')));
      }
    } finally {
      if (mounted) setState(() => _loadingReadings = false);
    }
  }

  Future<void> _exportCsv() async {
    final rows = [
      ['timestamp', 'channel', 'value', 'unit'],
      ..._readings.map((r) => [
            r.timestamp.toIso8601String(),
            r.channel,
            r.value.toString(),
            r.unit,
          ]),
    ];
    final csv = const ListToCsvConverter().convert(rows);

    if (kIsWeb) {
      js.context.callMethod('eval', [
        '''
        window.downloadCsvFile = function(content, fileName) {
          const blob = new Blob([content], {type: 'text/csv'});
          const url = URL.createObjectURL(blob);
          const anchor = document.createElement('a');
          anchor.href = url;
          anchor.download = fileName;
          anchor.click();
          URL.revokeObjectURL(url);
        }
        '''
      ]);
      js.context.callMethod('downloadCsvFile', [csv, 'session_${_selected!.sessionId}.csv']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSV exported successfully')),
        );
      }
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/session_${_selected!.sessionId}.csv');
      await file.writeAsString(csv);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved ${file.path}')));
      }
    }
  }

  Future<void> _exportPdf() async {
    if (_selected == null) return;
    final patientName = await LocalDb.getPatientNameForSession(_selected!.sessionId) ?? 'Unlinked Patient';

    final statsData = <List<String>>[];
    final channels = _readings.map((r) => r.channel).toSet().toList();
    for (final ch in channels) {
      final chReadings = _readings.where((r) => r.channel == ch).toList();
      if (chReadings.isEmpty) continue;
      
      var minVal = chReadings.first.value;
      var maxVal = chReadings.first.value;
      var sumVal = 0.0;
      for (final r in chReadings) {
        if (r.value < minVal) minVal = r.value;
        if (r.value > maxVal) maxVal = r.value;
        sumVal += r.value;
      }
      final avgVal = sumVal / chReadings.length;
      final unit = chReadings.first.unit;
      
      statsData.add([
        ch,
        minVal.toStringAsFixed(1),
        avgVal.toStringAsFixed(1),
        maxVal.toStringAsFixed(1),
        unit,
        chReadings.length.toString(),
      ]);
    }

    final startTimeStr = DateFormat.yMMMd().add_jm().format(_selected!.startTime.toLocal());
    final endTimeStr = _selected!.endTime != null 
        ? DateFormat.yMMMd().add_jm().format(_selected!.endTime!.toLocal()) 
        : 'Ongoing';

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'CLINICAL TELEMETRY REPORT',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: const PdfColor.fromInt(0xFF1565C0),
                  ),
                ),
                pw.Text(
                  DateFormat.yMMMd().format(DateTime.now()),
                  style: const pw.TextStyle(color: PdfColors.grey),
                ),
              ],
            ),
            pw.Divider(thickness: 1.5, color: const PdfColor.fromInt(0xFF1565C0)),
            pw.SizedBox(height: 16),
            pw.Text('Session metadata:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
            pw.SizedBox(height: 8),
            pw.Bullet(text: 'Session ID: ${_selected!.sessionId}'),
            pw.Bullet(text: 'Patient: $patientName'),
            pw.Bullet(text: 'Start Time: $startTimeStr'),
            pw.Bullet(text: 'End Time: $endTimeStr'),
            pw.SizedBox(height: 24),
            pw.Text('Telemetry Channel Summary Statistics:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
            pw.SizedBox(height: 12),
            pw.TableHelper.fromTextArray(
              context: ctx,
              headers: ['Channel', 'Min', 'Avg', 'Max', 'Unit', 'Reading Count'],
              data: statsData,
              border: pw.TableBorder.symmetric(
                inside: const pw.BorderSide(width: 0.5, color: PdfColors.grey300),
                outside: const pw.BorderSide(width: 1, color: PdfColors.grey400),
              ),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF1565C0)),
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: {
                1: pw.Alignment.centerRight,
                2: pw.Alignment.centerRight,
                3: pw.Alignment.centerRight,
              },
            ),
          ],
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => doc.save());
  }
}
