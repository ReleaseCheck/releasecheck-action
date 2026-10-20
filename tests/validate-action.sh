#!/usr/bin/env bash
set -euo pipefail

test -f action.yml
test -f LICENSE
test -f scripts/run-releasecheck.sh
test -f scripts/run-releasecheck.ps1
grep -q 'using: composite' action.yml
grep -q 'releasecheck-version' action.yml
grep -q 'description: "Registry ecosystem to verify: npm or pypi"' action.yml
grep -q 'description: "Report format: human, json, or sarif"' action.yml
grep -q 'sha256sum' scripts/run-releasecheck.sh
grep -q 'tar -xOzf' scripts/run-releasecheck.sh
grep -q 'verify' scripts/run-releasecheck.sh
grep -q "runner.os == 'Windows'" action.yml
grep -q 'run-releasecheck.ps1' action.yml
if grep -Eq 'npm install|pip install|curl.*\|.*sh|eval ' scripts/run-releasecheck.sh; then
  echo 'unsafe installation or shell execution found' >&2
  exit 1
fi

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
runner="$root/scripts/run-releasecheck.sh"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
release_dir="$test_root/release"
workspace="$test_root/workspace"
mock_bin="$test_root/mock-bin"
archive="releasecheck-v0.1.0-linux-amd64.tar.gz"
binary_dir="releasecheck-v0.1.0-linux-amd64"
mkdir -p "$release_dir" "$workspace" "$mock_bin" "$test_root/stage/$binary_dir"

cat > "$test_root/stage/$binary_dir/releasecheck" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
for ((index = 1; index <= $#; index++)); do
  if [[ "${!index}" == "--output" ]]; then
    next=$((index + 1))
    printf '{"schema_version":"1.0"}\n' > "${!next}"
    break
  fi
done
if [[ "${MOCK_EXIT:-0}" != 0 ]]; then
  exit "$MOCK_EXIT"
fi
EOF
chmod 0755 "$test_root/stage/$binary_dir/releasecheck"
tar -czf "$release_dir/$archive" -C "$test_root/stage" "$binary_dir"

cat > "$mock_bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
url=""
for argument in "$@"; do
  case "$argument" in https://*) url="$argument";; esac
done
destination="${!#}"
case "$url" in
  */SHA256SUMS) cp "$MOCK_RELEASE_DIR/SHA256SUMS" "$destination" ;;
  *.tar.gz) cp "$MOCK_RELEASE_DIR/releasecheck-v0.1.0-linux-amd64.tar.gz" "$destination" ;;
  *) echo "unexpected curl URL: $url" >&2; exit 1 ;;
esac
EOF
chmod 0755 "$mock_bin/curl"

run_action() {
  PATH="$mock_bin:$PATH" \
  MOCK_RELEASE_DIR="$release_dir" \
  GITHUB_WORKSPACE="$workspace" \
  RUNNER_TEMP="$test_root/runner" \
  GITHUB_OUTPUT="$test_root/github-output" \
  INPUT_ECOSYSTEM=npm \
  INPUT_PACKAGE=example-package \
  INPUT_FORMAT=json \
  INPUT_RELEASECHECK_VERSION=0.1.0 \
  "$runner"
}

write_checksum() {
  case "$1" in
    prefixed) (cd "$release_dir" && sha256sum "./$archive") > "$release_dir/SHA256SUMS" ;;
    unprefixed) (cd "$release_dir" && sha256sum "$archive") > "$release_dir/SHA256SUMS" ;;
    missing) printf '%064d  ./other.tar.gz\n' 0 > "$release_dir/SHA256SUMS" ;;
    malformed) printf 'not-a-sha256  ./%s\n' "$archive" > "$release_dir/SHA256SUMS" ;;
    mismatch) printf '%064d  ./%s\n' 0 "$archive" > "$release_dir/SHA256SUMS" ;;
  esac
}

write_checksum prefixed
run_action
test -s "$workspace/releasecheck-report.json"

rm -rf "$test_root/runner" "$workspace"
mkdir -p "$workspace"
if MOCK_EXIT=1 run_action >"$test_root/verifier-failure.out" 2>&1; then
  echo 'verifier nonzero status was swallowed' >&2
  exit 1
fi

rm -rf "$test_root/runner" "$workspace"
mkdir -p "$workspace"
write_checksum unprefixed
run_action
test -s "$workspace/releasecheck-report.json"

for case_name in missing malformed mismatch; do
  rm -rf "$test_root/runner"
  write_checksum "$case_name"
  if run_action >"$test_root/$case_name.out" 2>&1; then
    echo "checksum case unexpectedly succeeded: $case_name" >&2
    exit 1
  fi
done

grep -q 'missing, malformed, or ambiguous' "$test_root/missing.out"
grep -q 'missing, malformed, or ambiguous' "$test_root/malformed.out"
grep -q 'checksum mismatch' "$test_root/mismatch.out"
echo 'action-structure=PASS'
