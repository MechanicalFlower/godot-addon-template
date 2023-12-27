#!/usr/bin/env -S just --justfile

set dotenv-load := true

export PIP_REQUIRE_VIRTUALENV := "true"

# === Aliases ===

[private]
alias g := godot

[private]
alias e := editor

# === Variables ===

# Global directories
# To make the Godot binaries available for other projects
home_dir := env_var('HOME')
main_dir := home_dir / ".mkflower"
cache_dir := main_dir / "cache"
bin_dir := main_dir / "bin"

# Godot variables
godot_version := env_var('GODOT_VERSION')
godot_platform := if os() == "windows" {
    if arch() == "x86" {
        "win32.exe"
    } else if arch() == "x86_64" {
        "win64.exe"
    } else {
        error("Architecture not supported")
    }
} else if os() == "macos" {
    "macos.universal"
} else if os() == "linux" {
    if arch() == "x86" {
        "linux.x86_32"
    } else if arch() == "x86_64" {
        "linux.x86_64"
    } else if arch() == "arm" {
        "linux.arm32"
    } else if arch() == "aarch64" {
        "linux.arm64"
    } else {
        error("Architecture not supported")
    }
} else {
    error("OS not supported")
}
godot_filename := "Godot_v" + godot_version + "-stable_" + godot_platform
godot_bin := bin_dir / godot_filename
use_x11_wrapper := if godot_platform =~ "x11*" { env("CI", "false") } else { "false" }

# Addon variables
addon_name := env_var('ADDON_NAME')
addon_version := env_var('ADDON_VERSION')

# Python virtualenv
venv_dir := justfile_directory() / "venv"

# === Commands ===

# Display all commands
@default:
    echo "OS: {{ os() }} - ARCH: {{ arch() }}"
    just --list

# Create directories
[private]
@makedirs:
    mkdir -p {{ cache_dir }} {{ bin_dir }}

# Python virtualenv wrapper
[private]
@venv *ARGS:
    [ ! -d {{ venv_dir }} ] && python3 -m venv {{ venv_dir }} || true
    . {{ venv_dir }}/bin/activate && {{ ARGS }}

# Download Godot
[private]
install-godot:
    #!/usr/bin/env sh
    if [ ! -e {{ godot_bin }} ]; then
        curl -X GET "https://downloads.tuxfamily.org/godotengine/{{ godot_version }}/{{ godot_filename }}.zip" --output {{ cache_dir }}/{{ godot_filename }}.zip
        unzip -o {{ cache_dir }}/{{ godot_filename }}.zip -d {{ cache_dir }}
        cp {{ cache_dir }}/{{ godot_filename }} {{ godot_bin }}
    fi

# Download plugins
install-addons:
    [ -f plug.gd ] && just godot --headless --script plug.gd install || true

# Import game resources
import-resources:
    just godot --headless --editor --quit

# Updates the addon version
@bump-version:
    echo "Update version in the plugin.cfg"
    sed -i "s,version=.*$,version=\"{{ addon_version }}\",g" ./addons/{{ addon_name }}/plugin.cfg
    echo "Update version in the README.md"
    sed -i "s,tag = ".*"$,tag = \"{{ addon_version }}\"\, include = [\"addons/{{ addon_name }}\"]}),g" ./README.md

# Godot binary wrapper
@godot *ARGS: makedirs install-godot
    #!/usr/bin/env sh
    if [ "{{ use_x11_wrapper }}" = "true" ]; then
        just ci-godot-x11 {{ ARGS }}
    else
        {{ godot_bin }} {{ ARGS }}
    fi

# Open the Godot editor
editor:
    just godot --editor

# Run files formatters
fmt:
    just venv pip install pre-commit==3.5.0 reuse==2.1.0 gdtoolkit==4.*
    just venv pre-commit run -a

# Remove cache and binaries created by this Justfile
[private]
clean-glam-cache:
    rm -rf {{ main_dir }}
    rm -rf {{ venv_dir }}

# Remove plugins
clean-addons:
    rm -rf .plugged
    [ -f plug.gd ] && find addons/ -maxdepth 1 -type d -not -name 'addons' -not -name 'gd-plug' -not -name '{{ addon_name }}' -exec rm -rf {} \; || true

# Remove any unnecessary files
clean: clean-addons

# Add some variables to Github env
ci-load-dotenv:
    echo "godot_version={{ godot_version }}" >> $GITHUB_ENV
    echo "addon_name={{ addon_name }}" >> $GITHUB_ENV
    echo "addon_version={{ addon_version }}" >> $GITHUB_ENV

# Starts godot using Xvfb and pulseaudio
ci-godot-x11 *ARGS:
    #!/bin/bash
    set -e
    # Set locale to 'en' if locale is not already set.
    # Godot will fallback to this locale anyway and it
    # prevents an error message being printed to console.
    [ "$LANG" == "C.UTF-8" ] && LANG=en || true

    # Start dummy sound device.
    pulseaudio --check || pulseaudio -D

    # Running godot with X11 Display.
    xvfb-run --auto-servernum {{ godot_bin }} {{ ARGS }}

    # Cleanup (allowed to fail).
    pulseaudio -k || true

# Upload the addon on Github
publish:
    gh release create "{{ addon_version }}" --title="v{{ addon_version }}" --generate-notes
    # TODO: Add an asset-lib publish step

# Generate documentation
doc:
    sed -i "s,res://src,res://addons/{{ addon_name }},g" ./addons/godot-autogen-docs/reference_collector.gd
    just godot --editor --headless --quit --script addons/godot-autogen-docs/reference_collector_cli.gd
    just godot --headless --quit --script addons/godot-autogen-docs/markdown.gd
    just venv pip install mkdocs==1.5.3 mkdocs-literate-nav==0.6.1
    just venv mkdocs build

# Start serving the documentation
serve:
    just venv pip install mkdocs==1.5.3 mkdocs-literate-nav==0.6.1
    just venv mkdocs serve

# Run unit tests
unit: install-addons import-resources
    just godot --headless --script addons/gut/gut_cmdln.gd -gconfig=.gutconfig.json
