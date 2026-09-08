import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../map/map_mock_data.dart';
import '../map/map_screen.dart' show MockMapBackground;

/// "나의 지도" 전체화면. 지도 탭과 같은 목업 지도를 쓰되, 찜한 스팟만 표시한다.
/// 지도 탭(map_screen.dart)과 같은 블러+그라데이션 타이틀 헤더 스타일을 재사용해서
/// 톤을 통일했다. 검색바/카테고리 칩은 없음(찜한 스팟만 보여주는 화면이라 불필요).
class MyMapScreen extends StatelessWidget {
  const MyMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final spots = mockSpots.where((s) => savedSpotIds.contains(s.id)).toList();

    return Scaffold(
      backgroundColor: CocoTheme.surface,
      body: Stack(
        children: [
          Positioned.fill(
            child: spots.isEmpty
                ? _EmptyMap(onGoToMap: () => context.go('/map'))
                : MockMapBackground(
                    spots: spots,
                    onSpotTap: (spot) => context.push('/map/spot/${spot.id}'),
                  ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: ShaderMask(
              shaderCallback: (rect) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Colors.white, Colors.transparent],
                stops: [0.0, 0.6, 1.0],
              ).createShader(rect),
              blendMode: BlendMode.dstIn,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.55, 1.0],
                        colors: [
                          Colors.white.withOpacity(0.82),
                          Colors.white.withOpacity(0.45),
                          Colors.white.withOpacity(0.0),
                        ],
                      ),
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                IconButton(
                                  onPressed: () => context.pop(),
                                  icon: const Icon(Icons.arrow_back_rounded),
                                ),
                                const SizedBox(width: 4),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 8),
                                    const Text('나의 지도', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: CocoTheme.secondary)),
                                    const SizedBox(height: 2),
                                    Text('찜한 스팟 ${spots.length}곳', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                                  ],
                                ),
                              ],
                            ),
                            // 블러가 서서히 사라질 여백(페이드 테일) — 지도 탭과 동일한 패턴.
                            const SizedBox(height: 34),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (spots.isNotEmpty)
            Positioned(
              right: 16,
              bottom: 24,
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Icon(Icons.my_location_rounded, color: CocoTheme.primary, size: 20),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyMap extends StatelessWidget {
  final VoidCallback onGoToMap;
  const _EmptyMap({required this.onGoToMap});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFEAE8E2),
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('아직 찜한 스팟이 없어요', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
            const SizedBox(height: 6),
            Text('지도 탭에서 스팟을 찜해보세요', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
            const SizedBox(height: 18),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: CocoTheme.primary),
              onPressed: onGoToMap,
              child: const Text('지도로 가기'),
            ),
          ],
        ),
      ),
    );
  }
}
