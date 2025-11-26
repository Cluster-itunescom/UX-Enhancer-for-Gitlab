#!/usr/bin/env bash
set -euo pipefail

# publish_template_to_gitlab.sh
# Create or update a file in a GitLab project using the Repository Files API.
# Usage:
#   GITLAB_TOKEN=... GITLAB_HOST=gitlab.com ./scripts/publish_template_to_gitlab.sh \
#     --project "your-group/ci-templates" --branch main --src ./templates/nodejs-defaults.yml --dst templates/nodejs-defaults.yml
#
# Environment variables:
#  GITLAB_TOKEN  (required) - Personal Access Token with 'api' or 'write_repository' scope
#  GITLAB_HOST   (optional) - GitLab host (default: gitlab.com)

GITLAB_HOST=${GITLAB_HOST:-gitlab.com}

usage() {
  cat <<EOF
Usage: $0 --project <namespace/project> --branch <branch> --src <local-file> --dst <remote-path>

Environment:
  GITLAB_TOKEN (required) - PAT with api/write_repository
  GITLAB_HOST  (optional) - default: gitlab.com

Example:
  GITLAB_TOKEN=XXX ./scripts/publish_template_to_gitlab.sh --project "your-group/ci-templates" --branch main \
    --src ./templates/nodejs-defaults.yml --dst templates/nodejs-defaults.yml

EOF
}

if [ $# -eq 0 ]; then
  usage
  exit 1
fi

PROJECT=""
BRANCH="main"
SRC=""
DST=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) PROJECT="$2"; shift 2;;
    --branch) BRANCH="$2"; shift 2;;
    --src) SRC="$2"; shift 2;;
    --dst) DST="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1"; usage; exit 1;;
  esac
done

if [ -z "${PROJECT}" ] || [ -z "${SRC}" ] || [ -z "${DST}" ]; then
  echo "Missing required parameters"
  usage
  exit 1
fi

if [ ! -f "$SRC" ]; then
  echo "Source file not found: $SRC"
  exit 1
fi

if [ -z "${GITLAB_TOKEN:-}" ]; then
  echo "GITLAB_TOKEN must be set in the environment (Personal Access Token)."
  exit 1
fi

API_BASE="https://${GITLAB_HOST}/api/v4"

urlencode() {
  # simple urlencode for path components
  python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$1"
}

PROJECT_ENC=$(urlencode "$PROJECT")
FILE_PATH_ENC=$(urlencode "$DST")

GET_URL="${API_BASE}/projects/${PROJECT_ENC}/repository/files/${FILE_PATH_ENC}?ref=${BRANCH}"
POST_PUT_URL="${API_BASE}/projects/${PROJECT_ENC}/repository/files/${FILE_PATH_ENC}"

CONTENT=$(sed -e 's/"/\\"/g' "$SRC")

echo "Publishing $SRC to ${PROJECT}:${DST} on branch ${BRANCH} (host: ${GITLAB_HOST})"

http_code=$(curl -s -o /dev/null -w '%{http_code}' -H "PRIVATE-TOKEN: ${GITLAB_TOKEN}" "$GET_URL") || true

if [ "$http_code" = "200" ]; then
  echo "File exists — updating"
  curl --silent --show-error -X PUT -H "Content-Type: application/json" -H "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
    -d "{\"branch\": \"${BRANCH}\", \"content\": \"${CONTENT}\", \"commit_message\": \"Update template ${DST}\"}" \
    "$POST_PUT_URL"
else
  echo "File does not exist — creating"
  curl --silent --show-error -X POST -H "Content-Type: application/json" -H "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
    -d "{\"branch\": \"${BRANCH}\", \"content\": \"${CONTENT}\", \"commit_message\": \"Add template ${DST}\"}" \
    "$POST_PUT_URL"
fi

echo "Done. If you plan to use raw includes, ensure the target project is accessible (public or via token)."
