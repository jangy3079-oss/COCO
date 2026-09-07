import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import 'spot_register_mock_data.dart';

/// 스팟 등록 ② 등록 폼 화면. 검색에서 고른 위치에 카테고리·노출 기간·한줄 소개를
/// 채워 "등록 신청"하면 심사 대기 화면(spot_register_pending_screen)으로 넘어간다.
class SpotRegisterFormScreen extends StatefulWidget {
  final SpotSearchCandidate picked;
  const SpotRegisterFormScreen({super.key, required this.picked});

  @override
  State<SpotRegisterFormScreen> createState() => _SpotRegisterFormScreenState();
}

class _SpotRegisterFormScreenState extends State<SpotRegisterFormScreen> {
  SpotRegisterCategory _category = spotRegisterCategories.first;
  String _exposure = 'always'; // always | limited
  final _startController = TextEditingController();
  final _endController = TextEditingController();
  final _introController = TextEditingController();

  bool get _periodRequired => _category.forcePeriod || _exposure == 'limited';
  bool get _canSubmit =>
      _introController.text.trim().isNotEmpty &&
      (!_periodRequired || (_startController.text.trim().isNotEmpty && _endController.text.trim().isNotEmpty));

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    _introController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_canSubmit) return;
    final exposureLabel = _periodRequired
        ? '기간 한정${_endController.text.trim().isNotEmpty ? ' · ${_endController.text.trim()} 종료' : ''}'
        : '상시 노출';
    context.push('/map/register/pending', extra: {
      'name': widget.picked.name,
      'address': widget.picked.address,
      'categoryLabel': _category.label,
      'exposureLabel': exposureLabel,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_back_rounded)),
                  const Text('스팟 등록', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CocoTheme.secondary)),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFFF6F6F4), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on_rounded, size: 18, color: CocoTheme.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.picked.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CocoTheme.secondary)),
                                const SizedBox(height: 2),
                                Text(widget.picked.address, style: TextStyle(fontSize: 11, color: Colors.black.withOpacity(0.45))),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => context.pop(),
                            child: const Text('변경', style: TextStyle(fontSize: 12, color: CocoTheme.primary)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text('카테고리', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: CocoTheme.secondary)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final c in spotRegisterCategories)
                          _Chip(
                            label: c.label,
                            selected: _category.code == c.code,
                            onTap: () => setState(() {
                              _category = c;
                              _exposure = c.forcePeriod ? 'limited' : 'always';
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const Text('노출 기간', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: CocoTheme.secondary)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _ToggleButton(
                            label: '상시',
                            active: _exposure == 'always' && !_category.forcePeriod,
                            onTap: () => setState(() => _exposure = 'always'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ToggleButton(
                            label: '기간 한정',
                            active: _periodRequired,
                            onTap: () => setState(() => _exposure = 'limited'),
                          ),
                        ),
                      ],
                    ),
                    if (_periodRequired) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: const Color(0xFFF4F8FC), borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _category.forcePeriod ? '팝업스토어는 운영 기간을 꼭 입력해야 해요' : '기간 한정 스팟은 시작일과 종료일을 입력해 주세요',
                              style: const TextStyle(fontSize: 11, height: 1.5, color: CocoTheme.primary),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(child: _DateField(label: '시작일', controller: _startController, hint: '2026.09.01', onChanged: () => setState(() {}))),
                                const SizedBox(width: 8),
                                Expanded(child: _DateField(label: '종료일', controller: _endController, hint: '2026.09.30', onChanged: () => setState(() {}))),
                              ],
                            ),
                            const SizedBox(height: 9),
                            Text(
                              '종료일이 지나면 지도에서 자동으로 숨겨지고, 만료 3일 전에 알림을 보내드려요',
                              style: TextStyle(fontSize: 11, height: 1.5, color: Colors.black.withOpacity(0.45)),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('한줄 소개', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: CocoTheme.secondary)),
                        Text('${_introController.text.length}/80', style: TextStyle(fontSize: 11, color: Colors.black.withOpacity(0.35))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _introController,
                      maxLength: 80,
                      maxLines: 4,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: '동네 사람으로서 이 곳을 한 문장으로 소개해 주세요',
                        counterText: '',
                        contentPadding: const EdgeInsets.all(14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: const Color(0xFFF6F6F4), borderRadius: BorderRadius.circular(12)),
                      child: Text(
                        '등록 신청은 관리자 심사를 거쳐요. 승인되면 영어·일본어로 자동 번역되어 지도에 올라가고, 등록 리워드가 지급돼요.',
                        style: TextStyle(fontSize: 11, height: 1.6, color: Colors.black.withOpacity(0.5)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _canSubmit ? CocoTheme.primary : Colors.black.withOpacity(0.1),
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _submit,
                child: Text('등록 신청', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _canSubmit ? Colors.white : Colors.black.withOpacity(0.3))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? CocoTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? CocoTheme.primary : Colors.grey.shade300),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.white : CocoTheme.secondary)),
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ToggleButton({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? CocoTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? CocoTheme.primary : Colors.grey.shade300),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: active ? Colors.white : Colors.black.withOpacity(0.6))),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final VoidCallback onChanged;
  const _DateField({required this.label, required this.controller, required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black.withOpacity(0.5))),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          onChanged: (_) => onChanged(),
          style: const TextStyle(fontSize: 13, color: CocoTheme.secondary),
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
          ),
        ),
      ],
    );
  }
}
