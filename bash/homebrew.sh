#!/usr/bin/env bash
#
# Homebrew hardening — supply-chain security configuration
# See: man brew (search for HOMEBREW_ environment variables)
#
# Sourced automatically by bashrc (via $HOME/.bash/*.sh)

# ─── Supply-chain / integrity ──────────────────────────────────────────────

# Verify cryptographic build provenance of bottles from homebrew-core.
# Uses `gh` (GitHub CLI) to verify signed attestations.
# Install: brew install gh && gh auth login
# Disable with: HOMEBREW_NO_VERIFY_ATTESTATIONS=1
export HOMEBREW_VERIFY_ATTESTATIONS=1

# Forbid redirects from secure HTTPS to insecure HTTP when downloading.
# Prevents downgrade / man-in-the-middle attacks on package downloads.
export HOMEBREW_NO_INSECURE_REDIRECT=1

# Refuse to install formulae or casks provided from file paths
# (e.g. brew install ./payload.rb). Prevents accidental local injections.
export HOMEBREW_FORBID_PACKAGES_FROM_PATHS=1

# ─── Update discipline ─────────────────────────────────────────────────────

# Disable automatic self-update before install/upgrade.
# You control when updates happen: brew update
export HOMEBREW_NO_AUTO_UPDATE=1

# Don't auto-delete old versions after install/upgrade.
# Lets you roll back if a new release is compromised.
export HOMEBREW_NO_INSTALL_CLEANUP=1

# ─── Privacy ───────────────────────────────────────────────────────────────

# Opt out of all usage analytics / telemetry.
export HOMEBREW_NO_ANALYTICS=1

# ─── Optional extras (uncomment as needed) ─────────────────────────────────

# Block formulae by SPDX license identifier
# export HOMEBREW_FORBIDDEN_LICENSES="GPL-3.0-only AGPL-3.0-only"

# Block specific packages outright
# export HOMEBREW_FORBIDDEN_FORMULAE="insecure-package"

# Block entire third-party taps
# export HOMEBREW_FORBIDDEN_TAPS="some/untrusted-tap"

# Use a strict curl config (create ~/.curlrc with --tlsv1.3 --proto =https)
# export HOMEBREW_CURLRC="$HOME/.curlrc"

# Force full git clones instead of API (slower, more auditable)
# export HOMEBREW_NO_INSTALL_FROM_API=1
