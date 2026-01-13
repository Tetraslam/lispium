#!/bin/bash
# Usage: ./scripts/bump-version.sh <new-version>
# Example: ./scripts/bump-version.sh 0.2.0

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <new-version>"
    echo "Example: $0 0.2.0"
    exit 1
fi

NEW_VERSION="$1"

# Validate version format (basic semver)
if ! [[ "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$ ]]; then
    echo "Error: Invalid version format. Use semver (e.g., 0.2.0 or 0.2.0-beta.1)"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "Bumping version to $NEW_VERSION..."

# 1. Update VERSION file (used by Zig build)
echo "$NEW_VERSION" > "$ROOT_DIR/VERSION"
echo "  ✓ VERSION"

# 2. Update python/pyproject.toml
sed -i.bak "s/^version = \".*\"/version = \"$NEW_VERSION\"/" "$ROOT_DIR/python/pyproject.toml"
rm -f "$ROOT_DIR/python/pyproject.toml.bak"
echo "  ✓ python/pyproject.toml"

# 3. Update editor/vscode/package.json
sed -i.bak "s/\"version\": \".*\"/\"version\": \"$NEW_VERSION\"/" "$ROOT_DIR/editor/vscode/package.json"
rm -f "$ROOT_DIR/editor/vscode/package.json.bak"
echo "  ✓ editor/vscode/package.json"

echo ""
echo "Version bumped to $NEW_VERSION"
echo ""
echo "Next steps:"
echo "  1. git add -A"
echo "  2. git commit -m \"Bump version to $NEW_VERSION\""
echo "  3. git tag v$NEW_VERSION"
echo "  4. git push origin main --tags"
echo ""
echo "This will trigger:"
echo "  - release.yml: Build and publish binaries to GitHub Releases"
echo "  - pypi.yml: Publish to PyPI (triggered by release)"
