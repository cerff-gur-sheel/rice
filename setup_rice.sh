#!/bin/bash

set -e

echo "[INFO] Starting rice environment setup..."

RICE_REPO="https://github.com/cerff-gur-sheel/rice.git"
RICE_DIR="$HOME/.config/rice"

# Clone rice repo if not present
if [ ! -d "$RICE_DIR" ]; then
  echo "[INFO] Cloning rice repository to $RICE_DIR..."
  git clone "$RICE_REPO" "$RICE_DIR"
else
  echo "[INFO] Rice directory already exists. Skipping clone."
fi

# Remove existing config files and directories
echo "[INFO] Removing existing config files and directories..."
rm -rf \
  "$HOME/.bashrc" \
  "$HOME/.bash_profile" \
  "$HOME/.bash_logout" \
  "$HOME/.profile" \
  "$HOME/.gitconfig" \
  "$HOME/.gtkrc-2.0" \
  "$HOME/.config/fish" \
  "$HOME/.config/gtk-3.0" \
  "$HOME/.config/hypr" \
  "$HOME/.config/kitty" \
  "$HOME/.config/qt6ct" \
  "$HOME/.config/xsettingsd"

# Create base directories
echo "[INFO] Creating base directories..."
mkdir -p "$HOME/.config" "$HOME/.local/share" "$HOME/.local/state"

# Create symbolic links
echo "[INFO] Creating symbolic links..."
ln -sf "$RICE_DIR/.bashrc" "$HOME/.bashrc"
ln -sf "$RICE_DIR/.bash_profile" "$HOME/.bash_profile"
ln -sf "$RICE_DIR/.bash_logout" "$HOME/.bash_logout"
ln -sf "$RICE_DIR/.profile" "$HOME/.profile"
ln -sf "$RICE_DIR/.gitconfig" "$HOME/.gitconfig"
ln -sf "$RICE_DIR/.gtkrc-2.0" "$HOME/.gtkrc-2.0"

ln -sf "$RICE_DIR/fish" "$HOME/.config/fish"
ln -sf "$RICE_DIR/gtk-3.0" "$HOME/.config/gtk-3.0"
ln -sf "$RICE_DIR/hypr" "$HOME/.config/hypr"
ln -sf "$RICE_DIR/kitty" "$HOME/.config/kitty"
ln -sf "$RICE_DIR/qt6ct" "$HOME/.config/qt6ct"
ln -sf "$RICE_DIR/xsettingsd" "$HOME/.config/xsettingsd"

echo "[INFO] Rice environment setup completed successfully."

