import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

/// 스팟 등록 ③ 신청 완료(심사 대기) 화면. 실제로 mockSpots에 반영하지 않는다 —
/// 관리자 심사를 거쳐 승인된 뒤에야 지도에 반영되는 흐름이라(시나리오 2-A8),
/// 이 화면은 신청이 접수됐다는 확인만 보여준다.
class SpotRegisterPendingScreen extends StatelessWidget {
  final String name;
  final String address;
  final String categoryLabel;
  final String exposureLabel;

  const SpotRegisterPendingScreen({
    super.key,
    required this.name,
    required this.address,
    required this.categoryLabel,
    required this.exposureLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: const Color(0xFFE6F1FB), shape: BoxShape.circle),
                      child: const Icon(Icons.check_rounded, color: CocoTheme.primary, size: 32),
                    ),
                    const SizedBox(height: 20),
                    const Text('등록 신청이 접수됐어요', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: CocoTheme.secondary)),
                    const SizedBox(height: 10),
                    Text(
                      '관리자 심사는 보통 1~2일 걸려요. 승인되면 알림으로 알려드리고, 등록 리워드가 지급돼요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, height: 1.7, color: Colors.black.withOpacity(0.5)),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.black.withOpacity(0.08))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                decoration: BoxDecoration(color: const Color(0xFFF4F4F2), borderRadius: BorderRadius.circular(11)),
                                child: Text('심사 대기', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black.withOpacity(0.55))),
                              ),
                              const SizedBox(width: 8),
                              Text('방금 신청', style: TextStyle(fontSize: 11, color: Colors.black.withOpacity(0.35))),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: CocoTheme.secondary)),
                          const SizedBox(height: 4),
                          Text(address, style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.45))),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _Pill(text: categoryLabel, bg: const Color(0xFFE6F1FB), color: CocoTheme.primary),
                              _Pill(text: exposureLabel, bg: const Color(0xFFF4F4F2), color: Colors.black.withOpacity(0.55)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              child: Column(
                children: [
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: CocoTheme.primary,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => context.go('/map'),
                    child: const Text('지도로 돌아가기', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('내 등록 신청 목록은 준비 중이에요'), duration: Duration(seconds: 1)),
                    ),
                    child: const Text('내 등록 신청 보기', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: CocoTheme.secondary)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color bg;
  final Color color;
  const _Pill({required this.text, required this.bg, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(11)),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
