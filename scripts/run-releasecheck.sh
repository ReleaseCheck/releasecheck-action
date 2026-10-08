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
archive="releasecheck-v${version}-linux-amd64.tar.gz"
checksum_file="$cache_dir/SHA256SUMS"
archive_file="$cache_dir/$archive"
binary_dir="$cache_dir/releasecheck-v${version}-linux-amd64"
binary="$binary_dir/releasecheck"

if [[ ! -x "$binary" ]]; then
  curl --fail --location --proto '=https' --tlsv1.2 --silent --show-error "$base/SHA256SUMS" -o "$checksum_file"
  curl --fail --location --proto '=https' --tlsv1.2 --silent --show-error "$base/$archive" -o "$archive_file"
  expected="$(awk -v name="$archive" '$2 == name {print $1}' "$checksum_file")"
  if [[ -z "$expected" ]]; then echo "archive checksum is missing" >&2; exit 1; fi
  actual="$(sha256sum "$archive_file" | awk '{print $1}')"
  if [[ "$actual" != "$expected" ]]; then echo "archive checksum mismatch" >&2; exit 1; fi
  rm -rf "$binary_dir"
  mkdir -p "$binary_dir"
  tar -xzf "$archive_file" -C "$cache_dir"
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
