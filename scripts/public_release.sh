#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SOURCE_REPO="$(cd "${SCRIPT_DIR}/.." && pwd -P)"

REF="HEAD"
VERSION=""
PUBLIC_DIR=""
PUBLIC_BRANCH="main"
GITHUB_REMOTE="git@github.com:SoftSugar-Inc/shengwang-effects-ios.git"
WORK_DIR=""
KEEP_WORK=0
SYNC=0
COMMIT=0
PUSH=0

usage() {
  cat <<'EOF'
Usage:
  scripts/public_release.sh [options]

Options:
  --ref <ref>             Internal Git ref to publish. Defaults to HEAD.
  --version <version>     Release version used in commit/tag text.
  --github-remote <url>   GitHub repository URL.
                           Defaults to git@github.com:SoftSugar-Inc/shengwang-effects-ios.git.
  --public-dir <path>     Optional existing GitHub checkout path for local inspection.
                           If omitted, the script clones GitHub into the temporary work dir.
  --branch <branch>       GitHub branch to update. Defaults to main.
  --work-dir <path>       Temporary work directory. Created if missing.
  --sync                  Sync sanitized snapshot into a GitHub checkout.
  --commit                Create a release commit after sync. Implies --sync.
  --push                  Push branch and release tag to GitHub. Implies --commit.
  --keep-work             Keep the temporary work directory.
  -h, --help              Show this help.

Examples:
  scripts/public_release.sh --ref v9.7.8 --version 9.7.8
  scripts/public_release.sh --ref v9.7.8 --version 9.7.8 --sync
  scripts/public_release.sh --ref v9.7.8 --version 9.7.8 --commit
  scripts/public_release.sh --ref v9.7.8 --version 9.7.8 --push
EOF
}

die() {
  echo "error: $*" >&2
  exit 1
}

info() {
  echo "==> $*"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --ref)
      REF="${2:-}"
      shift 2
      ;;
    --version)
      VERSION="${2:-}"
      shift 2
      ;;
    --public-dir)
      PUBLIC_DIR="${2:-}"
      shift 2
      ;;
    --github-remote)
      GITHUB_REMOTE="${2:-}"
      shift 2
      ;;
    --branch)
      PUBLIC_BRANCH="${2:-}"
      shift 2
      ;;
    --expected-remote)
      GITHUB_REMOTE="${2:-}"
      shift 2
      ;;
    --work-dir)
      WORK_DIR="${2:-}"
      shift 2
      ;;
    --sync)
      SYNC=1
      shift
      ;;
    --commit)
      COMMIT=1
      SYNC=1
      shift
      ;;
    --push)
      PUSH=1
      COMMIT=1
      SYNC=1
      shift
      ;;
    --keep-work)
      KEEP_WORK=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
done

[ -n "$REF" ] || die "--ref cannot be empty"
[ -n "$PUBLIC_BRANCH" ] || die "--branch cannot be empty"
[ -n "$GITHUB_REMOTE" ] || die "--github-remote cannot be empty"

if [ "$COMMIT" -eq 1 ] && [ -z "$VERSION" ]; then
  die "--version is required when using --commit or --push"
fi

command -v git >/dev/null 2>&1 || die "git is required"
command -v rsync >/dev/null 2>&1 || die "rsync is required"
command -v tar >/dev/null 2>&1 || die "tar is required"

git -C "$SOURCE_REPO" rev-parse --git-dir >/dev/null
git -C "$SOURCE_REPO" cat-file -e "${REF}^{commit}" || die "ref not found: $REF"

SOURCE_COMMIT="$(git -C "$SOURCE_REPO" rev-parse "${REF}^{commit}")"

if [ -z "$WORK_DIR" ]; then
  WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/agora-public-release.XXXXXX")"
else
  mkdir -p "$WORK_DIR"
  WORK_DIR="$(cd "$WORK_DIR" && pwd -P)"
fi

cleanup() {
  if [ "$KEEP_WORK" -eq 0 ]; then
    rm -rf "$WORK_DIR"
  else
    echo "kept work dir: $WORK_DIR"
  fi
}
trap cleanup EXIT

SNAPSHOT_DIR="$WORK_DIR/snapshot"
mkdir -p "$SNAPSHOT_DIR"

info "source repo: $SOURCE_REPO"
info "source ref: $REF ($SOURCE_COMMIT)"
info "snapshot dir: $SNAPSHOT_DIR"

info "exporting source snapshot"
git -C "$SOURCE_REPO" archive --format=tar "$REF" | tar -x -C "$SNAPSHOT_DIR"

info "removing denylisted files from snapshot"
find "$SNAPSHOT_DIR" \( \
  -name '*.lic' -o \
  -name '*.keystore' -o \
  -name 'key.properties' -o \
  -name '*.p12' -o \
  -name '*.mobileprovision' -o \
  -name '*.pem' -o \
  -name '*.token' -o \
  -name '*.secret' \
\) -print -delete

find "$SNAPSHOT_DIR" -type d -name license -print -exec rm -rf {} +

info "scanning sanitized snapshot"
SCAN_REPORT="$WORK_DIR/scan-report.txt"
: > "$SCAN_REPORT"

find "$SNAPSHOT_DIR" \( \
  -name '*.lic' -o \
  -name '*.keystore' -o \
  -name 'key.properties' -o \
  -name '*.p12' -o \
  -name '*.mobileprovision' -o \
  -name '*.pem' -o \
  -name '*.token' -o \
  -name '*.secret' \
\) -print >> "$SCAN_REPORT"

find "$SNAPSHOT_DIR" -type d -name license -print >> "$SCAN_REPORT"

if grep -RInE --exclude='public_release.sh' 'gitlab\.softsugar\.com|softsugar\.corp|BEGIN (RSA |OPENSSH |EC |DSA )?PRIVATE KEY|x-access-token:' "$SNAPSHOT_DIR" >> "$SCAN_REPORT"; then
  :
fi

if [ -s "$SCAN_REPORT" ]; then
  echo "scan failed; findings:" >&2
  sed -n '1,120p' "$SCAN_REPORT" >&2
  die "sanitized snapshot contains blocked content"
fi

info "scan passed"

SNAPSHOT_FILES="$(find "$SNAPSHOT_DIR" -type f | wc -l | tr -d ' ')"
info "snapshot file count: $SNAPSHOT_FILES"

if [ "$SYNC" -eq 0 ]; then
  info "dry run complete; use --sync to clone/update a GitHub checkout"
  exit 0
fi

if [ -z "$PUBLIC_DIR" ]; then
  PUBLIC_DIR="$WORK_DIR/public-checkout"
  info "cloning GitHub checkout"
  git clone --branch "$PUBLIC_BRANCH" --single-branch "$GITHUB_REMOTE" "$PUBLIC_DIR"
else
  [ -d "$PUBLIC_DIR/.git" ] || die "public dir is not a git checkout: $PUBLIC_DIR"
fi

[ -d "$PUBLIC_DIR/.git" ] || die "public dir is not a git checkout: $PUBLIC_DIR"

PUBLIC_REMOTE="$(git -C "$PUBLIC_DIR" remote get-url origin)"
if [ "$PUBLIC_REMOTE" != "$GITHUB_REMOTE" ]; then
  die "unexpected public remote: $PUBLIC_REMOTE (expected $GITHUB_REMOTE)"
fi

CURRENT_BRANCH="$(git -C "$PUBLIC_DIR" branch --show-current)"
if [ "$CURRENT_BRANCH" != "$PUBLIC_BRANCH" ]; then
  die "public checkout is on $CURRENT_BRANCH, expected $PUBLIC_BRANCH"
fi

if [ -n "$(git -C "$PUBLIC_DIR" status --porcelain)" ]; then
  die "public checkout has uncommitted changes: $PUBLIC_DIR"
fi

info "fetching latest GitHub branch"
git -C "$PUBLIC_DIR" fetch origin "$PUBLIC_BRANCH"
git -C "$PUBLIC_DIR" merge --ff-only "origin/$PUBLIC_BRANCH"

info "syncing snapshot into GitHub checkout"
rsync -a --delete --exclude '.git' "$SNAPSHOT_DIR/" "$PUBLIC_DIR/"

info "public checkout changes"
git -C "$PUBLIC_DIR" status --short

if [ "$COMMIT" -eq 0 ]; then
  info "sync complete; inspect $PUBLIC_DIR and use --commit when ready"
  exit 0
fi

if [ -z "$(git -C "$PUBLIC_DIR" status --porcelain)" ]; then
  info "no public changes to commit"
else
  COMMIT_MESSAGE="${VERSION} release"
  info "creating release commit: $COMMIT_MESSAGE"
  git -C "$PUBLIC_DIR" add -A
  git -C "$PUBLIC_DIR" commit -m "$COMMIT_MESSAGE"
fi

TAG_NAME="v${VERSION#v}"
if git -C "$PUBLIC_DIR" rev-parse -q --verify "refs/tags/$TAG_NAME" >/dev/null; then
  die "tag already exists locally: $TAG_NAME"
fi

if git -C "$PUBLIC_DIR" ls-remote --exit-code --tags origin "refs/tags/$TAG_NAME" >/dev/null 2>&1; then
  die "tag already exists on origin: $TAG_NAME"
fi

info "creating release tag: $TAG_NAME"
git -C "$PUBLIC_DIR" tag "$TAG_NAME"

if [ "$PUSH" -eq 0 ]; then
  info "commit/tag created locally; use --push to publish"
  exit 0
fi

info "pushing branch and tag to GitHub"
git -C "$PUBLIC_DIR" push origin "$PUBLIC_BRANCH"
git -C "$PUBLIC_DIR" push origin "$TAG_NAME"

info "publish complete"
