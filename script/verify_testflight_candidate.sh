#!/usr/bin/env bash
set -euo pipefail

# 糖葫芦遥控器：TestFlight 候选包二次验签与冻结校验脚本 (参考 THLDance 规范)
PLATFORM="${1:-ios}"
if (($#)); then shift; fi
ARCHIVE_ROOT=""
BUILD_NUMBER=""
IPA_PATH=""
EXPECTED_SHA256=""

usage() {
  echo "usage: $0 ios --archive-root ABSOLUTE_PATH --build-number NUMBER --ipa ABSOLUTE_PATH --sha256 LOWERCASE_HEX" >&2
}

while (($#)); do
  case "$1" in
    --archive-root) ARCHIVE_ROOT="${2:-}"; shift 2 ;;
    --build-number) BUILD_NUMBER="${2:-}"; shift 2 ;;
    --ipa) IPA_PATH="${2:-}"; shift 2 ;;
    --sha256) EXPECTED_SHA256="${2:-}"; shift 2 ;;
    *) usage; exit 2 ;;
  esac
done

if [[ "$PLATFORM" != "ios" ]] ||
   [[ "$ARCHIVE_ROOT" != /* || "$IPA_PATH" != /* ]] ||
   [[ ! "$BUILD_NUMBER" =~ ^[0-9]{1,18}$ ]] ||
   [[ ! "$EXPECTED_SHA256" =~ ^[a-f0-9]{64}$ ]]; then
  usage
  exit 2
fi

for dependency in unzip shasum codesign realpath; do
  command -v "$dependency" >/dev/null 2>&1 || {
    echo "ERROR: missing dependency: $dependency" >&2
    exit 1
  }
done

[[ -d "$ARCHIVE_ROOT" && ! -L "$ARCHIVE_ROOT" ]] || {
  echo "ERROR: archive root must be an existing directory: $ARCHIVE_ROOT" >&2
  exit 1
}

archive_root="$(cd "$ARCHIVE_ROOT" && pwd -P)"
export_directory="$archive_root/$PLATFORM/export"
[[ -d "$export_directory" && ! -L "$export_directory" ]] || {
  echo "ERROR: platform export directory is missing or is a symlink: $export_directory" >&2
  exit 1
}

[[ -f "$IPA_PATH" && ! -L "$IPA_PATH" && "${IPA_PATH##*.}" == ipa ]] || {
  echo "ERROR: exported IPA must be a regular .ipa file: $IPA_PATH" >&2
  exit 1
}

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
THLBROWSER_BUILD_NUMBER="$BUILD_NUMBER" \
THLBROWSER_ARCHIVE_ROOT="$archive_root" \
  "$repository_root/script/archive_app_store.sh" "$PLATFORM" --verify-only

actual_sha256="$(shasum -a 256 "$IPA_PATH" | awk '{print $1}')"
[[ "$actual_sha256" == "$EXPECTED_SHA256" ]] || {
  echo "ERROR: exported IPA SHA-256 differs from expected value: $actual_sha256 != $EXPECTED_SHA256" >&2
  exit 1
}

verified_directory="$archive_root/$PLATFORM/verified-testflight"
mkdir -p "$verified_directory"
frozen_ipa="$verified_directory/HSBWatchCompanion-$BUILD_NUMBER-$EXPECTED_SHA256.ipa"

if [[ ! -e "$frozen_ipa" ]]; then
  temporary_copy="$(mktemp "$verified_directory/.candidate.XXXXXX")"
  cp "$IPA_PATH" "$temporary_copy"
  copied_sha256="$(shasum -a 256 "$temporary_copy" | awk '{print $1}')"
  if [[ "$copied_sha256" != "$EXPECTED_SHA256" ]]; then
    rm -f "$temporary_copy"
    echo "ERROR: IPA changed while the frozen candidate was being copied" >&2
    exit 1
  fi
  chmod 0444 "$temporary_copy"
  mv -n "$temporary_copy" "$frozen_ipa"
  rm -f "$temporary_copy"
fi

unzip -tq "$frozen_ipa" >/dev/null || {
  echo "ERROR: frozen IPA ZIP integrity check failed" >&2
  exit 1
}

echo "VERIFIED_IPA_PATH=$frozen_ipa"
