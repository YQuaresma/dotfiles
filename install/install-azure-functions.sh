#!/usr/bin/env bash
# Installs Azure Functions Core Tools v4.
# macOS: via Homebrew. Ubuntu: via APT (jammy Microsoft repo — only distro that publishes v4).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../symlinks/home/bin/functions.sh"
OS="$(detect_os)"

echo "--------------------------------"
cog_msg "Installing Azure Functions Core Tools..."
echo "--------------------------------"

# Skip if already installed
if command -v func &>/dev/null; then
    warn "Already installed: azure-functions-core-tools ($(func --version))"
    exit 0
fi

if [[ "$OS" == "macos" ]]; then
    brew tap azure/functions
    brew install azure-functions-core-tools@4

elif [[ "$OS" == "debian" ]]; then
    export DEBIAN_FRONTEND=noninteractive

    # azure-functions-core-tools-4 is only published to the jammy repo
    RESOLVED_CODENAME="jammy"
    REPO_URL="https://packages.microsoft.com/repos/microsoft-ubuntu-${RESOLVED_CODENAME}-prod"

    cog_msg "Installing via APT (${RESOLVED_CODENAME} repo)..."

    # Add Microsoft GPG keys — standard bundle + newer "General GPG Signer" key
    # (newer Ubuntu codenames like resolute are signed with EE4D7792F748182B,
    #  which is absent from the standard microsoft.asc bundle).
    #
    # Both are fetched over HTTPS from packages.microsoft.com and checked against
    # pinned full fingerprints. The previous version pulled the signer key from a
    # public keyserver by 64-bit key ID: key IDs are not secure identifiers,
    # keyservers accept arbitrary uploads, and the fetch failure was swallowed by
    # `|| true` — for something that becomes an APT trust anchor, i.e. root.
    MS_KEY_FPRS=(
        "BC528686B50D79E339D3721CEB3E94ADBE1229CF"  # microsoft.asc (standard bundle)
        "AA86F75E427A19DD33346403EE4D7792F748182B"  # microsoft-2025.asc (General GPG Signer)
    )
    MS_KEY_URLS=(
        "https://packages.microsoft.com/keys/microsoft.asc"
        "https://packages.microsoft.com/keys/microsoft-2025.asc"
    )

    tmp_keys="$(mktemp)"
    trap 'rm -f "$tmp_keys"' EXIT
    for i in "${!MS_KEY_URLS[@]}"; do
        one_key="$(mktemp)"
        # -f so an HTTP error page is never appended as key material
        curl -fsSL "${MS_KEY_URLS[$i]}" -o "$one_key"
        if ! gpg --show-keys --with-colons "$one_key" \
            | awk -F: '/^fpr:/ { print $10 }' \
            | grep -qx "${MS_KEY_FPRS[$i]}"; then
            error "Fingerprint mismatch for ${MS_KEY_URLS[$i]}"
            error "Expected ${MS_KEY_FPRS[$i]}. Refusing to trust it."
            rm -f "$one_key"
            exit 1
        fi
        cat "$one_key" >> "$tmp_keys"
        rm -f "$one_key"
    done

    sudo install -m 0755 -d /etc/apt/keyrings
    sudo gpg --yes --dearmor -o /etc/apt/keyrings/microsoft.gpg < "$tmp_keys"
    sudo chmod go+r /etc/apt/keyrings/microsoft.gpg

    # Add APT source with signed-by reference
    sudo sh -c "echo \"deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] ${REPO_URL} ${RESOLVED_CODENAME} main\" > /etc/apt/sources.list.d/dotnetdev.list"

    sudo apt-get update
    sudo apt-get install -y azure-functions-core-tools-4

else
    error "Unsupported OS: ${OS}"; exit 1
fi

success "Azure Functions Core Tools installed: $(func --version)"
