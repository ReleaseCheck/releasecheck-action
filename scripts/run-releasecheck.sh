#!/usr/bin/env bash
set -euo pipefail

version="${INPUT_RELEASECHECK_VERSION:?releasecheck-version is required}"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "releasecheck-version must match MAJOR.MINOR.PATCH: $version" >&2
  exit 2
fi

case "${INPUT_ECOSYSTEM:?ecosystem is required}" in
  npm|pypi) ;;
  *) echo "ecosystem must be npm or pypi" >&2; exit 2 ;;
esac

case "${INPUT_FORMAT:-json}" in
  human) format_flag=();;
  json) format_flag=(--json);;
  sarif) format_flag=(--sarif);;
  *) echo "format must be human, json, or sarif" >&2; exit 2 ;;
esac

if [[ -z "${GITHUB_WORKSPACE:-}" ]]; then
  echo "GITHUB_WORKSPACE is required" >&2
  exit 2
fi

output="${INPUT_OUTPUT:-releasecheck-report.json}"
case "$output" in
  /*|../*|*/../*|..\*) echo "output must stay within the workspace" >&2; exit 2 ;;
esac
mkdir -p "$GITHUB_WORKSPACE/$(dirname "$output")"

cache_dir="${RUNNER_TEMP:-$GITHUB_WORKSPACE}/releasecheck"
mkdir -p "$cache_dir"
base="https://github.com/ReleaseCheck/releasecheck/releases/download/v${version}"
case "${RUNNER_OS:-Linux}:${RUNNER_ARCH:-X64}" in
  Linux:X64) archive="releasecheck-v${version}-linux-amd64.tar.gz" ;;
  Linux:ARM64) archive="releasecheck-v${version}-linux-arm64.tar.gz" ;;
  macOS:X64) archive="releasecheck-v${version}-darwin-amd64.tar.gz" ;;
  macOS:ARM64) archive="releasecheck-v${version}-darwin-arm64.tar.gz" ;;
  *) echo "unsupported runner platform: ${RUNNER_OS:-unknown}/${RUNNER_ARCH:-unknown}" >&2; exit 2 ;;
esac
checksum_file="$cache_dir/SHA256SUMS"
archive_file="$cache_dir/$archive"
binary_dir="$cache_dir/${archive%.tar.gz}"
binary="$binary_dir/releasecheck"
archive_binary="${archive%.tar.gz}/releasecheck"

if [[ ! -x "$binary" ]]; then
  curl --fail --location --proto '=https' --tlsv1.2 --silent --show-error "$base/SHA256SUMS" -o "$checksum_file"
  curl --fail --location --proto '=https' --tlsv1.2 --silent --show-error "$base/$archive" -o "$archive_file"
  if ! expected="$(awk -v name="$archive" '
    {
      entry = $2
      sub(/^\*/, "", entry)
    }
    (entry == name || entry == "./" name) {
      if (length($1) != 64 || $1 !~ /^[0-9A-Fa-f]+$/) { invalid = 1; next }
      count++
      value = tolower($1)
    }
    END {
      if (invalid || count != 1) { exit 1 }
      print value
    }
  ' "$checksum_file" 2>/dev/null)"; then
    expected=""
  fi
  if [[ -z "$expected" ]]; then echo "archive checksum is missing, malformed, or ambiguous" >&2; exit 1; fi
  if command -v sha256sum >/dev/null 2>&1; then
    actual="$(sha256sum "$archive_file" | awk '{print $1}')"
  else
    actual="$(shasum -a 256 "$archive_file" | awk '{print $1}')"
  fi
  if [[ "$actual" != "$expected" ]]; then echo "archive checksum mismatch" >&2; exit 1; fi
  mkdir -p "$binary_dir"
  temporary_binary="$binary_dir/.releasecheck.tmp"
  if ! tar -xOzf "$archive_file" -- "$archive_binary" > "$temporary_binary"; then
    rm -f "$temporary_binary"
    echo "release archive does not contain the expected Linux binary" >&2
    exit 1
  fi
  if [[ ! -s "$temporary_binary" ]]; then
    rm -f "$temporary_binary"
    echo "release archive contains an empty Linux binary" >&2
    exit 1
  fi
  mv "$temporary_binary" "$binary"
  chmod 0755 "$binary"
fi

args=(verify "$INPUT_ECOSYSTEM" "${format_flag[@]}" --timeout "${INPUT_TIMEOUT:-30s}" --output "$GITHUB_WORKSPACE/$output" "$INPUT_PACKAGE")
if [[ -n "${INPUT_VERSION:-}" ]]; then args+=("$INPUT_VERSION"); fi
if [[ "$INPUT_ECOSYSTEM" == "pypi" && -n "${INPUT_ARTIFACT:-}" ]]; then args+=(--artifact "$INPUT_ARTIFACT"); fi

set +e
"$binary" "${args[@]}"
status=$?
set -e
echo "report=$output" >> "${GITHUB_OUTPUT:?GITHUB_OUTPUT is required}"
exit "$status"
