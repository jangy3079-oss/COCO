import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import 'mypage_mock_data.dart';

/// 프로필 수정 화면. 닉네임·자기소개만 수정 가능 — 이메일과 회원 유형(로컬/관광객)은
/// 가입 시 값이라 읽기전용으로만 보여준다(회원 유형은 Q&A 답변 배지·권한과 연결되는
/// 값이라 임의 변경을 막음, MY_TAB_SPEC.md 9번 참고).
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late final _nicknameController = TextEditingController(text: myNickname);
  late final _bioController = TextEditingController(text: myBio);

  bool get _canSave => _nicknameController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _nicknameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_canSave) return;
    myNickname = _nicknameController.text.trim();
    myBio = _bioController.text.trim();
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => context.pop(),
                    child: Text('취소', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                  ),
                  const Expanded(
                    child: Text('프로필 수정', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CocoTheme.secondary)),
                  ),
                  TextButton(
                    onPressed: _canSave ? _save : null,
                    child: Text('저장', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _canSave ? CocoTheme.primary : Colors.grey.shade400)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 88,
                            height: 88,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(color: Color(0xFFF0ECE6), shape: BoxShape.circle),
                            child: Text(myInitial, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: CocoTheme.secondary)),
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('사진 변경은 준비 중이에요'), duration: Duration(seconds: 1)),
                            ),
                            child: const Text('사진 변경', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: CocoTheme.primary)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('닉네임', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nicknameController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('자기소개', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54)),
                        Text('${_bioController.text.length}/60', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _bioController,
                      onChanged: (v) {
                        if (v.length > 60) {
                          _bioController.text = v.substring(0, 60);
                          _bioController.selection = TextSelection.collapsed(offset: 60);
                        }
                        setState(() {});
                      },
                      maxLines: 4,
                      minLines: 3,
                      decoration: InputDecoration(
                        hintText: '자기소개를 추가해보세요',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.all(14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('이메일', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54)),
                    const SizedBox(height: 8),
                    Container(
                      height: 46,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(color: const Color(0xFFF6F6F4), borderRadius: BorderRadius.circular(12)),
                      child: Text(myEmail, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                    ),
                    const SizedBox(height: 6),
                    Text('이메일은 변경할 수 없어요', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                    const SizedBox(height: 20),
                    const Text('회원 유형', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54)),
                    const SizedBox(height: 8),
                    Container(
                      height: 46,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(color: const Color(0xFFF6F6F4), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFE6F1FB), borderRadius: BorderRadius.circular(10)),
                            child: Text(myRoleLabel == '로컬 주민' ? '로컬' : '관광객', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: CocoTheme.primary)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('가입 시 선택한 유형은 변경할 수 없어요', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
