#!/bin/bash
set -e
echo "[INFO] Setting up rice environment..."

RICE_REPO="https://github.com/cerff-gur-sheel/rice.git"
RICE_DIR="$HOME/.config/rice"

# Clone rice repo if not present
if [ ! -d "$RICE_DIR" ]; then
  echo "	[INFO] Cloning rice repository to $RICE_DIR..."
  git clone "$RICE_REPO" "$RICE_DIR"
else
  echo "	[INFO] Rice directory already exists. Skipping clone."
fi

echo "[INFO] Removing existing config files and directories..."
rm -rf \
  "$HOME/.config/wofi" \
  "$HOME/.config/waybar" \
  "$HOME/.config/hypr" \
  "$HOME/.config/kitty"\
	"$HOME/.profile"\
	"$HOME/.config/fish/config.fish"\
	"$HOME/.config/gtk-3.0"\
	"$HOME/.config/gtk-4.0"\
	"$HOME/.gtkrc-2.0"\
	"$HOME/.icons"\
	"$HOME/.config/qt5ct"\
	"$HOME/.config/qt6ct"\
	"$HOME/.config/nwg-look" \
	"$HOME/.config/btop"

echo "[INFO] Creating symbolic links..."
ln -sf "$RICE_DIR/wofi" "$HOME/.config/wofi"
ln -sf "$RICE_DIR/waybar" "$HOME/.config/waybar"
ln -sf "$RICE_DIR/hypr" "$HOME/.config/hypr"
ln -sf "$RICE_DIR/kitty" "$HOME/.config/kitty"
ln -sf "$RICE_DIR/home/.profile" "$HOME/.profile"
ln -sf "$RICE_DIR/fish/config.fish" "$HOME/.config/fish/config.fish"
ln -sf "$RICE_DIR/theming/gtk-3.0" "$HOME/.config/gtk-3.0"
ln -sf "$RICE_DIR/theming/gtk-4.0" "$HOME/.config/gtk-4.0"
ln -sf "$RICE_DIR/theming/.gtkrc-2.0" "$HOME/.gtkrc-2.0" 
ln -sf "$RICE_DIR/theming/.icons" "$HOME/.icons" 
ln -sf "$RICE_DIR/theming/qt5ct" "$HOME/.config/qt5ct" 
ln -sf "$RICE_DIR/theming/qt6ct" "$HOME/.config/qt6ct" 
ln -sf "$RICE_DIR/theming/nwg-look" "$HOME/.config/nwg-look" 
ln -sf "$RICE_DIR/btop" "$HOME/.config/btop" 

echo "[INFO] Rice environment setup completed successfully."
