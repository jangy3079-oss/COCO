// 백엔드(coco_backend)가 내려주는 createdAt은 서버가 UTC로 찍은 시각인데,
// JSON에 타임존 표시("Z"나 "+09:00")가 없이 내려온다. Dart의 DateTime.parse는
// 타임존 표시가 없으면 그 숫자를 그대로 "로컬(기기) 시각"으로 읽어버려서,
// 실제로는 UTC인 값이 이미 한국시간인 것처럼 해석돼 항상 9시간(한국 UTC+9)만큼
// 미래처럼 보이는 버그가 생긴다(예: 방금 쓴 글이 "9시간 전"으로 표시됨).
// 그래서 문자열에 타임존 표시가 없으면 UTC임을 명시해준 뒤 로컬로 변환한다.
DateTime parseBackendDateTime(String raw) {
  final hasTimezone = raw.endsWith('Z') || RegExp(r'[+-]\d\d:\d\d$').hasMatch(raw);
  final utc = DateTime.parse(hasTimezone ? raw : '${raw}Z');
  return utc.toLocal();
}
