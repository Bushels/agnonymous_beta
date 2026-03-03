import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../providers/cot_positions_provider.dart';
import '../../providers/futures_provider.dart';
import '../../providers/grain_data_live_provider.dart';
import '../../widgets/charts/insight_card.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/ticker/sparkline_widget.dart';

// =============================================================================
// Canola Thesis Dashboard — the flagship deep-dive screen.
// Combines ICE futures prices, CGC delivery pace, CFTC COT positioning,
// and auto-generated heuristic insights into a single premium view.
// =============================================================================

class CanolaThesisScreen extends ConsumerWidget {
  const CanolaThesisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ---- SliverAppBar ----
          SliverAppBar(
            floating: true,
            snap: true,
            pinned: false,
            backgroundColor: const Color(0xFF0F172A),
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new,
                  color: Colors.white, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              'Canola Market Intelligence',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF84CC16).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF84CC16).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF84CC16),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'LIVE',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF84CC16),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ---- Futures Price Card (Task 4.2) ----
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: const _FuturesPriceCard()
                  .animate()
                  .fade(duration: 400.ms)
                  .slideY(begin: 0.05),
            ),
          ),

          // ---- Delivery Pace Gauge (Task 4.3) ----
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: const _DeliveryPaceGauge()
                  .animate()
                  .fade(duration: 400.ms, delay: 80.ms)
                  .slideY(begin: 0.05),
            ),
          ),

          // ---- Weekly Briefing (Task 4.6) ----
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: const _WeeklyBriefingCard()
                  .animate()
                  .fade(duration: 400.ms, delay: 160.ms)
                  .slideY(begin: 0.05),
            ),
          ),

          // ---- COT Positioning Chart (Task 4.4) ----
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: const _CotPositioningChart()
                  .animate()
                  .fade(duration: 400.ms, delay: 240.ms)
                  .slideY(begin: 0.05),
            ),
          ),

          // ---- Contract Curve Chart (Task 4.5) ----
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: const _ContractCurveChart()
                  .animate()
                  .fade(duration: 400.ms, delay: 320.ms)
                  .slideY(begin: 0.05),
            ),
          ),

          // ---- Insight Cards Section (Task 4.6) ----
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: const _InsightCardsSection()
                  .animate()
                  .fade(duration: 400.ms, delay: 400.ms)
                  .slideY(begin: 0.05),
            ),
          ),

          // Bottom padding for safe area / nav bar
          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      ),
    );
  }
}

// =============================================================================
// 1. _FuturesPriceCard — front-month ICE canola price with sparkline
// =============================================================================

class _FuturesPriceCard extends ConsumerWidget {
  const _FuturesPriceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latestPrice = ref.watch(latestFuturesPriceProvider('CANOLA'));
    final priceHistory = ref.watch(
      frontMonthPriceProvider(
          const FuturesParams(commodity: 'CANOLA', numDays: 30)),
    );

    return GlassContainer(
      blur: 10,
      opacity: 0.08,
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.all(20),
      child: latestPrice.when(
        loading: () => const _ShimmerBox(height: 140),
        error: (_, __) => _errorRow('Unable to load futures price'),
        data: (price) {
          if (price == null) {
            return _emptyState('No canola futures data available');
          }

          final displayPrice = price.settlePrice ?? price.lastPrice ?? 0;
          final change = price.changeAmount ?? 0;
          final changePct = price.changePercent ?? 0;
          final isPositive = change >= 0;
          final changeColor = isPositive
              ? const Color(0xFF22C55E)
              : const Color(0xFFEF4444);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Label
              Row(
                children: [
                  const Icon(Icons.candlestick_chart,
                      color: Color(0xFF84CC16), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'ICE Canola Futures',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF94A3B8),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${price.contractMonth} Front Month',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF64748B),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Price + change
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${displayPrice.toStringAsFixed(2)}',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.5,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      'CAD/t',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF64748B),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: changeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPositive
                              ? Icons.trending_up
                              : Icons.trending_down,
                          color: changeColor,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${isPositive ? '+' : ''}\$${change.toStringAsFixed(2)}'
                          ' (${isPositive ? '+' : ''}${changePct.toStringAsFixed(2)}%)',
                          style: TextStyle(
                            color: changeColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 30-day sparkline
              priceHistory.when(
                loading: () => const _ShimmerBox(height: 40),
                error: (_, __) => const SizedBox(height: 40),
                data: (prices) {
                  final sparkData = prices
                      .where((p) =>
                          (p.settlePrice ?? p.lastPrice) != null)
                      .map((p) => (p.settlePrice ?? p.lastPrice)!)
                      .toList()
                      .reversed
                      .toList();
                  if (sparkData.length < 2) {
                    return const SizedBox(height: 40);
                  }
                  return SparklineWidget(
                    data: sparkData,
                    width: double.infinity,
                    height: 40,
                    lineColor: changeColor,
                    fillColor: changeColor.withValues(alpha: 0.08),
                    lineWidth: 2,
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

// =============================================================================
// 2. _DeliveryPaceGauge — semicircular gauge of cumulative deliveries vs 5yr avg
// =============================================================================

class _DeliveryPaceGauge extends ConsumerWidget {
  const _DeliveryPaceGauge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deliveryData = ref.watch(grainDataLiveProvider(
      const GrainDataParams(grain: 'Canola', metric: 'Deliveries', limit: 260),
    ));

    return GlassContainer(
      blur: 10,
      opacity: 0.08,
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.all(20),
      child: deliveryData.when(
        loading: () => const _ShimmerBox(height: 200),
        error: (_, __) => _errorRow('Unable to load delivery data'),
        data: (data) {
          if (data.isEmpty) {
            return _emptyState('No canola delivery data available');
          }

          // Parse and aggregate delivery data
          final now = DateTime.now();
          final currentCropYear = now.month >= 8 ? now.year : now.year - 1;
          final cropYearStart = DateTime(currentCropYear, 8, 1);

          double currentCumulative = 0;
          final List<double> historicalYears = [];

          // Group by crop year and accumulate
          final Map<int, double> yearTotals = {};
          for (final row in data) {
            final weekEnd = DateTime.tryParse(
                (row['week_ending'] ?? row['period_end'] ?? '') as String);
            if (weekEnd == null) continue;
            final ktonnes = (row['ktonnes'] as num?)?.toDouble() ?? 0;
            final yearStart =
                weekEnd.month >= 8 ? weekEnd.year : weekEnd.year - 1;

            if (yearStart == currentCropYear &&
                weekEnd.isAfter(cropYearStart.subtract(const Duration(days: 1)))) {
              currentCumulative += ktonnes;
            } else if (yearStart >= currentCropYear - 5 &&
                yearStart < currentCropYear) {
              yearTotals[yearStart] = (yearTotals[yearStart] ?? 0) + ktonnes;
            }
          }

          for (final entry in yearTotals.entries) {
            historicalYears.add(entry.value);
          }

          final fiveYearAvg = historicalYears.isNotEmpty
              ? historicalYears.reduce((a, b) => a + b) / historicalYears.length
              : 0.0;

          final pacePercent =
              fiveYearAvg > 0 ? (currentCumulative / fiveYearAvg * 100) : 0.0;

          // Gauge color based on pace
          Color gaugeColor;
          String paceLabel;
          if (pacePercent >= 95) {
            gaugeColor = const Color(0xFF22C55E);
            paceLabel = 'Ahead of pace';
          } else if (pacePercent >= 80) {
            gaugeColor = const Color(0xFFF59E0B);
            paceLabel = 'Near pace';
          } else {
            gaugeColor = const Color(0xFFEF4444);
            paceLabel = 'Behind pace';
          }

          final numFmt = NumberFormat('#,##0.0');

          return Column(
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.speed, color: Color(0xFF84CC16), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Delivery Pace',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: gaugeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      paceLabel,
                      style: TextStyle(
                        color: gaugeColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Gauge
              SizedBox(
                width: 180,
                height: 110,
                child: CustomPaint(
                  painter: _GaugePainter(
                    value: pacePercent.clamp(0, 150),
                    maxValue: 150,
                    gaugeColor: gaugeColor,
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 30),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${pacePercent.toStringAsFixed(0)}%',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'of 5yr avg pace',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF64748B),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Stats row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _statColumn(
                      'Current', '${numFmt.format(currentCumulative)} KT'),
                  Container(
                    width: 1,
                    height: 30,
                    color: const Color(0xFF1E293B),
                  ),
                  _statColumn('5yr Avg', '${numFmt.format(fiveYearAvg)} KT'),
                  Container(
                    width: 1,
                    height: 30,
                    color: const Color(0xFF1E293B),
                  ),
                  _statColumn(
                    'Diff',
                    '${(currentCumulative - fiveYearAvg) >= 0 ? '+' : ''}${numFmt.format(currentCumulative - fiveYearAvg)} KT',
                    valueColor: (currentCumulative - fiveYearAvg) >= 0
                        ? const Color(0xFF22C55E)
                        : const Color(0xFFEF4444),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _statColumn(String label, String value, {Color? valueColor}) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(
            color: valueColor ?? Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

/// Semicircular gauge painter for delivery pace visualization.
class _GaugePainter extends CustomPainter {
  final double value;
  final double maxValue;
  final Color gaugeColor;

  _GaugePainter({
    required this.value,
    required this.maxValue,
    required this.gaugeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 10);
    final radius = math.min(size.width / 2, size.height) - 16;
    const strokeWidth = 16.0;
    const startAngle = math.pi;
    const sweepAngle = math.pi;

    // Background arc
    final bgPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );

    // Value arc
    final valueSweep = (value / maxValue).clamp(0.0, 1.0) * sweepAngle;
    final valuePaint = Paint()
      ..color = gaugeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      valueSweep,
      false,
      valuePaint,
    );

    // Subtle glow on the value arc
    final glowPaint = Paint()
      ..color = gaugeColor.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 8
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      valueSweep,
      false,
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.gaugeColor != gaugeColor;
  }
}

// =============================================================================
// 3. _WeeklyBriefingCard — narrative combining delivery, COT, and price data
// =============================================================================

class _WeeklyBriefingCard extends ConsumerWidget {
  const _WeeklyBriefingCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deliveryData = ref.watch(grainDataLiveProvider(
      const GrainDataParams(grain: 'Canola', metric: 'Deliveries', limit: 10),
    ));
    final cotData = ref.watch(
      cotPositionsProvider(
          const CotParams(commodity: 'CANOLA', numWeeks: 2)),
    );
    final priceHistory = ref.watch(
      frontMonthPriceProvider(
          const FuturesParams(commodity: 'CANOLA', numDays: 14)),
    );

    return GlassContainer(
      blur: 10,
      opacity: 0.08,
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.calendar_today,
                  color: Color(0xFF84CC16), size: 18),
              const SizedBox(width: 8),
              Text(
                'Weekly Briefing',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Narrative
          _buildNarrative(deliveryData, cotData, priceHistory),
        ],
      ),
    );
  }

  Widget _buildNarrative(
    AsyncValue<List<Map<String, dynamic>>> deliveryData,
    AsyncValue<List<CotPosition>> cotData,
    AsyncValue<List<FuturesPrice>> priceHistory,
  ) {
    final sentences = <String>[];

    // Delivery sentence
    deliveryData.whenData((data) {
      if (data.length >= 2) {
        final current =
            (data[0]['ktonnes'] as num?)?.toDouble() ?? 0;
        final previous =
            (data[1]['ktonnes'] as num?)?.toDouble() ?? 0;
        if (previous > 0) {
          final wowChange = ((current - previous) / previous * 100);
          final direction = wowChange >= 0 ? 'rose' : 'fell';
          sentences.add(
            'Canola deliveries $direction ${wowChange.abs().toStringAsFixed(0)}% '
            'week-over-week to ${current.toStringAsFixed(1)} KT.',
          );
        }
      }
    });

    // COT sentence
    cotData.whenData((positions) {
      if (positions.isNotEmpty) {
        final latest = positions.first;
        final netChange = latest.nonCommercialNetChange;
        final net = latest.nonCommercialNet;
        if (netChange != null && net != null) {
          final numFmt = NumberFormat('#,##0');
          final direction = netChange >= 0 ? 'increased' : 'decreased';
          final stance = net >= 0 ? 'net long' : 'net short';
          sentences.add(
            'Speculators $direction their $stance position by '
            '${numFmt.format(netChange.abs())} contracts.',
          );
        }
      }
    });

    // Price sentence
    priceHistory.whenData((prices) {
      if (prices.length >= 2) {
        final latest = prices.first;
        final weekAgo = prices.last;
        final latestSettle = latest.settlePrice ?? latest.lastPrice;
        final weekAgoSettle = weekAgo.settlePrice ?? weekAgo.lastPrice;
        if (latestSettle != null && weekAgoSettle != null) {
          final diff = latestSettle - weekAgoSettle;
          final direction = diff >= 0 ? 'up' : 'down';
          sentences.add(
            'The ${latest.contractMonth} contract settled at '
            '\$${latestSettle.toStringAsFixed(2)}/tonne, '
            '$direction \$${diff.abs().toStringAsFixed(2)} on the week.',
          );
        }
      }
    });

    final isLoading = deliveryData.isLoading ||
        cotData.isLoading ||
        priceHistory.isLoading;

    if (isLoading) {
      return const _ShimmerBox(height: 60);
    }

    if (sentences.isEmpty) {
      return Text(
        'Awaiting data...',
        style: GoogleFonts.inter(
          color: const Color(0xFF64748B),
          fontSize: 13,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Text(
      sentences.join(' '),
      style: GoogleFonts.inter(
        color: const Color(0xFFCBD5E1),
        fontSize: 13,
        height: 1.6,
      ),
    );
  }
}

// =============================================================================
// 4. _CotPositioningChart — 12-week bar chart of speculative net positioning
// =============================================================================

class _CotPositioningChart extends ConsumerWidget {
  const _CotPositioningChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cotData = ref.watch(
      cotPositionsProvider(
          const CotParams(commodity: 'CANOLA', numWeeks: 12)),
    );

    return GlassContainer(
      blur: 10,
      opacity: 0.08,
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.all(20),
      child: cotData.when(
        loading: () => const _ShimmerBox(height: 320),
        error: (_, __) => _errorRow('Unable to load COT data'),
        data: (positions) {
          if (positions.isEmpty) {
            return _emptyState('No COT positioning data available');
          }

          // Reverse so oldest is first (left side of chart)
          final sorted = positions.reversed.toList();

          // Latest week change callout
          final latest = positions.first;
          final netChange = latest.nonCommercialNetChange;
          final numFmt = NumberFormat('#,##0');

          String changeCallout = '';
          Color calloutColor = const Color(0xFF94A3B8);
          if (netChange != null) {
            if (netChange >= 0) {
              changeCallout =
                  'Specs added +${numFmt.format(netChange)} contracts net long this week';
              calloutColor = const Color(0xFF22C55E);
            } else {
              changeCallout =
                  'Specs reduced ${numFmt.format(netChange)} contracts this week';
              calloutColor = const Color(0xFFEF4444);
            }
          }

          // Build bar data
          final barGroups = <BarChartGroupData>[];
          double maxAbs = 0;

          for (int i = 0; i < sorted.length; i++) {
            final net =
                sorted[i].nonCommercialNet?.toDouble() ?? 0;
            if (net.abs() > maxAbs) maxAbs = net.abs();

            barGroups.add(
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: net,
                    width: sorted.length > 8 ? 14 : 20,
                    borderRadius: net >= 0
                        ? const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          )
                        : const BorderRadius.only(
                            bottomLeft: Radius.circular(4),
                            bottomRight: Radius.circular(4),
                          ),
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: net >= 0
                          ? [
                              const Color(0xFF22C55E)
                                  .withValues(alpha: 0.6),
                              const Color(0xFF22C55E),
                            ]
                          : [
                              const Color(0xFFEF4444),
                              const Color(0xFFEF4444)
                                  .withValues(alpha: 0.6),
                            ],
                    ),
                  ),
                ],
              ),
            );
          }

          final yPadding = maxAbs * 0.15;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.bar_chart,
                      color: Color(0xFF84CC16), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Speculative Positioning',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (changeCallout.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  changeCallout,
                  style: GoogleFonts.inter(
                    color: calloutColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Chart
              SizedBox(
                height: 280,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxAbs + yPadding,
                    minY: -(maxAbs + yPadding),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval:
                          maxAbs > 0 ? maxAbs / 2 : 1000,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: const Color(0xFF1E293B),
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 55,
                          interval: maxAbs > 0 ? maxAbs / 2 : 1000,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              NumberFormat.compact().format(value),
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 10,
                              ),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: sorted.length > 6
                              ? (sorted.length / 4).ceilToDouble()
                              : 1,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx < 0 || idx >= sorted.length) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                DateFormat('MMM dd')
                                    .format(sorted[idx].reportDate),
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 9,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: barGroups,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) =>
                            const Color(0xFF1E293B),
                        tooltipBorder:
                            const BorderSide(color: Color(0xFF334155)),
                        getTooltipItem:
                            (group, groupIdx, rod, rodIdx) {
                          final pos = sorted[group.x];
                          return BarTooltipItem(
                            '${DateFormat('MMM dd, yyyy').format(pos.reportDate)}\n',
                            const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 11,
                            ),
                            children: [
                              TextSpan(
                                text:
                                    'Net: ${numFmt.format(pos.nonCommercialNet ?? 0)} contracts',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// =============================================================================
// 5. _ContractCurveChart — futures forward curve across active contract months
// =============================================================================

class _ContractCurveChart extends ConsumerWidget {
  const _ContractCurveChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final curveData = ref.watch(contractCurveProvider('CANOLA'));

    return GlassContainer(
      blur: 10,
      opacity: 0.08,
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.all(20),
      child: curveData.when(
        loading: () => const _ShimmerBox(height: 300),
        error: (_, __) => _errorRow('Unable to load futures curve'),
        data: (contracts) {
          if (contracts.isEmpty) {
            return _emptyState('No futures curve data available');
          }

          // Sort by contract month (should already be ordered)
          final sorted = List<FuturesPrice>.from(contracts)
            ..sort((a, b) => a.contractMonth.compareTo(b.contractMonth));

          // Build chart spots
          final spots = <FlSpot>[];
          final labels = <String>[];
          for (int i = 0; i < sorted.length; i++) {
            final price =
                sorted[i].settlePrice ?? sorted[i].lastPrice ?? 0;
            spots.add(FlSpot(i.toDouble(), price));
            labels.add(sorted[i].contractMonth);
          }

          if (spots.isEmpty) {
            return _emptyState('No futures curve data available');
          }

          final maxY =
              spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
          final minY =
              spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
          final yRange = maxY - minY;
          final yPadding = yRange > 0 ? yRange * 0.15 : 10;

          // Carry / backwardation
          final frontPrice = spots.first.y;
          final deferredPrice = spots.last.y;
          final spread = deferredPrice - frontPrice;
          final isCarry = spread > 0;
          final spreadLabel = isCarry
              ? 'Carry: +\$${spread.toStringAsFixed(2)}/tonne'
              : 'Backwardation: -\$${spread.abs().toStringAsFixed(2)}/tonne';
          final spreadColor = isCarry
              ? const Color(0xFFF59E0B)
              : const Color(0xFF06B6D4);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.show_chart,
                      color: Color(0xFF84CC16), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Futures Curve',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${sorted.length} contracts',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF64748B),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Carry/backwardation callout
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: spreadColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  spreadLabel,
                  style: TextStyle(
                    color: spreadColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Chart
              SizedBox(
                height: 250,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval:
                          yRange > 0 ? yRange / 4 : 5,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: const Color(0xFF1E293B),
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 55,
                          interval: yRange > 0 ? yRange / 4 : 5,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              '\$${value.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 10,
                              ),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx < 0 || idx >= labels.length) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                labels[idx],
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    minY: minY - yPadding,
                    maxY: maxY + yPadding,
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        curveSmoothness: 0.25,
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF84CC16),
                            Color(0xFF10B981),
                          ],
                        ),
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter:
                              (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 4,
                              color: const Color(0xFF84CC16),
                              strokeWidth: 2,
                              strokeColor: const Color(0xFF0F172A),
                            );
                          },
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              const Color(0xFF84CC16)
                                  .withValues(alpha: 0.2),
                              const Color(0xFF10B981)
                                  .withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ],
                    lineTouchData: LineTouchData(
                      enabled: true,
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) =>
                            const Color(0xFF1E293B),
                        tooltipBorder:
                            const BorderSide(color: Color(0xFF334155)),
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                            final idx = spot.x.toInt();
                            final label =
                                idx < labels.length ? labels[idx] : '';
                            return LineTooltipItem(
                              '\$${spot.y.toStringAsFixed(2)}\n',
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                              children: [
                                TextSpan(
                                  text: label,
                                  style: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontWeight: FontWeight.w400,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            );
                          }).toList();
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// =============================================================================
// 6. _InsightCardsSection — rule-based heuristic insight cards
// =============================================================================

class _InsightCardsSection extends ConsumerWidget {
  const _InsightCardsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deliveryData = ref.watch(grainDataLiveProvider(
      const GrainDataParams(grain: 'Canola', metric: 'Deliveries', limit: 260),
    ));
    final cotData = ref.watch(
      cotPositionsProvider(
          const CotParams(commodity: 'CANOLA', numWeeks: 4)),
    );
    final curveData = ref.watch(contractCurveProvider('CANOLA'));
    final regionSk = ref.watch(grainDataLiveProvider(
      const GrainDataParams(
          grain: 'Canola',
          region: 'Saskatchewan',
          metric: 'Deliveries',
          limit: 4),
    ));
    final regionAb = ref.watch(grainDataLiveProvider(
      const GrainDataParams(
          grain: 'Canola',
          region: 'Alberta',
          metric: 'Deliveries',
          limit: 4),
    ));

    // Collect insight cards
    final cards = <Widget>[];

    // ---- Pace Insight ----
    deliveryData.whenData((data) {
      if (data.isEmpty) return;

      final now = DateTime.now();
      final currentCropYear = now.month >= 8 ? now.year : now.year - 1;

      double currentCumulative = 0;
      final Map<int, double> yearTotals = {};

      for (final row in data) {
        final weekEnd = DateTime.tryParse(
            (row['week_ending'] ?? row['period_end'] ?? '') as String);
        if (weekEnd == null) continue;
        final ktonnes = (row['ktonnes'] as num?)?.toDouble() ?? 0;
        final yearStart =
            weekEnd.month >= 8 ? weekEnd.year : weekEnd.year - 1;

        if (yearStart == currentCropYear) {
          currentCumulative += ktonnes;
        } else if (yearStart >= currentCropYear - 5 &&
            yearStart < currentCropYear) {
          yearTotals[yearStart] = (yearTotals[yearStart] ?? 0) + ktonnes;
        }
      }

      if (yearTotals.isNotEmpty) {
        final fiveYearAvg =
            yearTotals.values.reduce((a, b) => a + b) / yearTotals.length;
        if (fiveYearAvg > 0) {
          final pacePct = (currentCumulative / fiveYearAvg * 100) - 100;
          final direction = pacePct >= 0 ? 'ahead of' : 'behind';
          final implication = pacePct >= 0
              ? 'suggesting strong farmer selling'
              : 'suggesting farmers are holding grain';

          cards.add(InsightCard(
            icon: Icons.speed,
            title: 'Delivery Pace',
            description:
                'Delivery pace is running ${pacePct.abs().toStringAsFixed(0)}% '
                '$direction the 5-year average, $implication.',
            type: pacePct >= 0 ? InsightType.positive : InsightType.warning,
          ));
        }
      }
    });

    // ---- COT Insight ----
    cotData.whenData((positions) {
      if (positions.length < 2) return;

      // Check trend direction over last 4 weeks
      int consecutiveWeeks = 0;
      bool? trendDirection; // true = building, false = reducing

      for (int i = 0; i < positions.length - 1; i++) {
        final current = positions[i].nonCommercialNet ?? 0;
        final previous = positions[i + 1].nonCommercialNet ?? 0;
        final isBuilding = current > previous;

        if (trendDirection == null) {
          trendDirection = isBuilding;
          consecutiveWeeks = 1;
        } else if (isBuilding == trendDirection) {
          consecutiveWeeks++;
        } else {
          break;
        }
      }

      if (consecutiveWeeks >= 2 && trendDirection != null) {
        final latest = positions.first;
        final stance = (latest.nonCommercialNet ?? 0) >= 0 ? 'long' : 'short';
        final action = trendDirection ? 'building' : 'reducing';

        cards.add(InsightCard(
          icon: Icons.people_outline,
          title: 'COT Positioning',
          description:
              'Speculators have been $action their net $stance position '
              'for $consecutiveWeeks consecutive weeks.',
          type: trendDirection ? InsightType.positive : InsightType.negative,
        ));
      }
    });

    // ---- Carry Insight ----
    curveData.whenData((contracts) {
      if (contracts.length < 2) return;

      final sorted = List<FuturesPrice>.from(contracts)
        ..sort((a, b) => a.contractMonth.compareTo(b.contractMonth));

      final frontPrice =
          sorted.first.settlePrice ?? sorted.first.lastPrice;
      final deferredPrice =
          sorted.last.settlePrice ?? sorted.last.lastPrice;

      if (frontPrice != null && deferredPrice != null) {
        final spread = deferredPrice - frontPrice;
        final isCarry = spread > 0;
        final structureLabel = isCarry ? 'carry' : 'backwardation';
        final implication =
            isCarry ? 'encouraging storage' : 'discouraging storage';

        cards.add(InsightCard(
          icon: Icons.timeline,
          title: 'Futures Curve',
          description:
              'The futures curve is in $structureLabel at '
              '\$${spread.abs().toStringAsFixed(2)}/tonne, $implication.',
          type: isCarry ? InsightType.neutral : InsightType.warning,
        ));
      }
    });

    // ---- Regional Insight ----
    regionSk.whenData((skData) {
      regionAb.whenData((abData) {
        if (skData.length >= 2 && abData.length >= 2) {
          final skCurrent =
              (skData[0]['ktonnes'] as num?)?.toDouble() ?? 0;
          final skPrevious =
              (skData[1]['ktonnes'] as num?)?.toDouble() ?? 0;
          final abCurrent =
              (abData[0]['ktonnes'] as num?)?.toDouble() ?? 0;
          final abPrevious =
              (abData[1]['ktonnes'] as num?)?.toDouble() ?? 0;

          if (skPrevious > 0 && abPrevious > 0) {
            final skChange = ((skCurrent - skPrevious) / skPrevious * 100);
            final abChange = ((abCurrent - abPrevious) / abPrevious * 100);

            final skDir = skChange >= 0 ? 'rose' : 'fell';
            final abDir = abChange >= 0 ? 'rose' : 'fell';

            cards.add(InsightCard(
              icon: Icons.location_on_outlined,
              title: 'Regional Breakdown',
              description:
                  'Saskatchewan deliveries $skDir ${skChange.abs().toStringAsFixed(0)}% '
                  'while Alberta deliveries $abDir ${abChange.abs().toStringAsFixed(0)}%.',
              type: InsightType.neutral,
            ));
          }
        }
      });
    });

    if (cards.isEmpty) {
      // Check if everything is still loading
      if (deliveryData.isLoading ||
          cotData.isLoading ||
          curveData.isLoading) {
        return const _ShimmerBox(height: 100);
      }
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome,
                  color: Color(0xFF84CC16), size: 18),
              const SizedBox(width: 8),
              Text(
                'Key Insights',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        ...cards.map((card) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: card,
            )),
      ],
    );
  }
}

// =============================================================================
// Shared helper widgets
// =============================================================================

/// Shimmer placeholder for loading states.
class _ShimmerBox extends StatelessWidget {
  final double height;

  const _ShimmerBox({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(
          duration: 1500.ms,
          color: const Color(0xFF334155).withValues(alpha: 0.3),
        );
  }
}

/// Inline error message row.
Widget _errorRow(String message) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          ),
        ),
      ],
    ),
  );
}

/// Empty state placeholder.
Widget _emptyState(String message) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Center(
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined,
              color: Color(0xFF334155), size: 32),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
            ),
          ),
        ],
      ),
    ),
  );
}
