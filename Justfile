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
godot_platform := if arch() == "x86" { "linux.x86_32" } else { if arch() == "x86_64" { "linux.x86_64" } else { "" } }
godot_filename := "Godot_v" + godot_version + "-stable_" + godot_platform
godot_bin := bin_dir / godot_filename

# Addon variables
addon_name := env_var('ADDON_NAME')
addon_version := env_var('ADDON_VERSION')

# Python virtualenv
venv_dir := justfile_directory() / "venv"

# === Commands ===

# Display all commands
@default:
    echo "OS: {{ os() }} - ARCH: {{ arch() }}\n"
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
    if [ ! -e {{ godot_bin }} ]
    then
        curl -X GET "https://downloads.tuxfamily.org/godotengine/{{ godot_version }}/{{ godot_filename }}.zip" --output {{ cache_dir }}/{{ godot_filename }}.zip
        unzip {{ cache_dir }}/{{ godot_filename }}.zip -d {{ cache_dir }}
        cp {{ cache_dir }}/{{ godot_filename }} {{ godot_bin }}
    fi

# Download plugins
install-addons:
    [ -f plug.gd ] && just godot --headless --script plug.gd install || true

# Updates the addon version
@bump-version:
    echo "Update version in the plugin.cfg"
    sed -i "s,version=.*$,version=\"{{ addon_version }}\",g" ./addons/{{ addon_name }}/plugin.cfg

# Godot binary wrapper
@godot *ARGS: makedirs install-godot
    {{ godot_bin }} {{ ARGS }}

# Open the Godot editor
editor:
    just godot --editor

# Run files formatters
fmt:
    just venv pip install pre-commit==3.3.3 reuse==2.1.0 gdtoolkit==4.*
    just venv pre-commit run -a

# Remove cache and binaries created by this Justfile
[private]
clean-mkflower:
    rm -rf {{ main_dir }}
    rm -rf {{ venv_dir }}

# Remove plugins
clean-addons:
    rm -rf .plugged
    [ -f plug.gd ] && find addons/ -type d -not -name 'addons' -not -name 'gd-plug' -not -name '{{ addon_name }}' -exec rm -rf {} \; || true

# Remove any unnecessary files
clean: clean-addons

# Add some variables to Github env
ci-load-dotenv:
    echo "godot_version={{ godot_version }}" >> $GITHUB_ENV
    echo "addon_name={{ addon_name }}" >> $GITHUB_ENV
    echo "addon_version={{ addon_version }}" >> $GITHUB_ENV

# Upload the addon on Github
publish:
    gh release create "{{ addon_version }}" --title="v{{ addon_version }}" --generate-notes
    # TODO: Add a asset-lib publish step
