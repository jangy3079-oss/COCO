#!/usr/bin/env bash
set -euo pipefail

# 기존 uploads 디렉터리에 남아 있는 파일을 같은 객체 경로로 Supabase Storage에 옮긴다.
# 사용 예:
#   export SUPABASE_URL=https://프로젝트_REF.supabase.co
#   export SUPABASE_STORAGE_KEY=sb_secret_...
#   ./scripts/migrate-local-uploads.sh uploads

: "${SUPABASE_URL:?SUPABASE_URL 환경변수가 필요합니다.}"
: "${SUPABASE_STORAGE_KEY:=${SUPABASE_SERVICE_ROLE_KEY:-}}"
: "${SUPABASE_STORAGE_KEY:?SUPABASE_STORAGE_KEY 환경변수가 필요합니다.}"

upload_root="${1:-uploads}"
bucket="${SUPABASE_STORAGE_BUCKET:-coco-uploads}"
supabase_url="${SUPABASE_URL%/}"

if [[ ! -d "$upload_root" ]]; then
  echo "업로드 디렉터리가 없습니다: $upload_root"
  exit 0
fi

auth_headers=(
  -H "apikey: ${SUPABASE_STORAGE_KEY}"
)
if [[ "$SUPABASE_STORAGE_KEY" != sb_secret_* ]]; then
  auth_headers+=(-H "Authorization: Bearer ${SUPABASE_STORAGE_KEY}")
fi

bucket_status="$(curl --silent --show-error --output /dev/null --write-out '%{http_code}' \
  "${auth_headers[@]}" \
  "${supabase_url}/storage/v1/bucket/${bucket}")"

if [[ "$bucket_status" == "404" ]]; then
  create_status="$(curl --silent --show-error --output /dev/null --write-out '%{http_code}' \
    -X POST "${auth_headers[@]}" -H 'Content-Type: application/json' \
    --data "{\"id\":\"${bucket}\",\"name\":\"${bucket}\",\"public\":false,\"file_size_limit\":5242880,\"allowed_mime_types\":[\"image/jpeg\",\"image/png\",\"image/webp\",\"image/gif\"]}" \
    "${supabase_url}/storage/v1/bucket")"
  if [[ ! "$create_status" =~ ^2 ]]; then
    echo "Storage 버킷 생성 실패 (HTTP ${create_status})" >&2
    exit 1
  fi
elif [[ ! "$bucket_status" =~ ^2 ]]; then
  echo "Storage 버킷 확인 실패 (HTTP ${bucket_status})" >&2
  exit 1
fi

migrated=0
failed=0
while IFS= read -r -d '' file_path; do
  object_path="${file_path#"${upload_root%/}/"}"
  content_type="$(file --brief --mime-type "$file_path")"
  status="$(curl --silent --show-error --output /dev/null --write-out '%{http_code}' \
    -X POST "${auth_headers[@]}" \
    -H "Content-Type: ${content_type}" -H 'cache-control: 31536000' -H 'x-upsert: true' \
    --data-binary "@${file_path}" \
    "${supabase_url}/storage/v1/object/${bucket}/${object_path}")"
  if [[ "$status" =~ ^2 ]]; then
    echo "이전 완료: ${object_path}"
    migrated=$((migrated + 1))
  else
    echo "이전 실패: ${object_path} (HTTP ${status})" >&2
    failed=$((failed + 1))
  fi
done < <(find "$upload_root" -type f -print0)

echo "Storage 이전 결과: 성공 ${migrated}개, 실패 ${failed}개"
[[ "$failed" -eq 0 ]]
