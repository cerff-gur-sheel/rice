


My personal rice se# 🖥️ Rice Config - Press Archconf Editiontup for Arch Linux, focused on aesthetics, productivity, and modularity. Each component of the system is configured with attention to detail and separated into specific folders for easy maintenance and customization.

![Print from neofetch](./documentation/main_print.jpg)

---
## Main Features

```bash.

├── btop/           # System monitoring with custom theme
├── fish/           # Interactive shell with personal settings
├── home/           # User files (placeholder)
├── hypr/           # Complete Hyprland configuration
│   ├── hyprland.conf
│   ├── hyprlock.conf
│   ├── hyprpaper.conf
│   └── land/       # Archconf-style modular configuration
├── kitty/          # Terminal with theme and shortcuts
├── setup.sh        # Installation/configuration script
├── theming/        # GTK, QT, NWG-look themes
├── wallpapers/     # Images and GIFs used in setup
├── waybar/         # Status bar with custom scripts
└── wofi/           # Menus and launcher style
```

---
## Hyprland

My custom Hyprland configuration was designed to be modular, clean, and functional, through a clear separation of responsibilities and a focus on productivity, aesthetics, and ergonomics.


### Directory Structure

All configuration is organized within `~/.config/hypr/`, with the following files:

| File               | Function                                                                 |
|-----------------------|------------------------------------------------------------------------|
| `hyprland.conf`       | Main file that references the modules                           |
| `vars.conf`           | Global variables (e.g., `$MAIN_MOD`, `$TERM`, etc.)                    |
| `envs.conf`           | Environment variables and initial executions                            |
| `inputs.conf`         | Keyboard, mouse, and touchpad settings                            |
| `binds.conf`          | All keyboard and mouse shortcuts, including Lazy Mode            |
| `monitors.conf`       | Monitor layout and resolution                                       |
| `lookandfeel.conf`    | Themes, borders, colors, and overall appearance                                |
| `animations.conf`     | Animations and transitions                                                |
| `rules.conf`          | Specific rules for windows (e.g., opacity, floating, etc.)       |
| `autostart.conf`      | Applications and services started with Hyprland                      |

---

### 🧠 Lazy Mode

One of the highlights of this configuration is **Lazy Mode** — a navigation mode that uses only the numeric keypad, ideal for those who want to control the WM with one hand.




#### Features:

- Enter mode with `KP_Decimal`
- Switch between submodes:
  - `KP_Enter` → move focus
  - `KP_Add` → move window
  - `KP_Multiply` → resize window
  - `KP_Divide` → switch workspace
  - `KP_Subtract` → move window to workspace

All this without having to use `$MAIN_MOD`!

---

### 🚀 Additional Features

- Support for 10 workspaces + special workspace (`magic`)
- Media controls via XF86 and generic keyboard
- Shortcuts for screenshot, color picker, clipboard, notifications
- Power controls (shut down, restart, hibernate, log out)
- Full modularity for easy maintenance and expansion

---

## 🛠️ Installation

Download setup.sh and run

```bash 
git clone https://github.com/cerff-gur-sheel/rice.git ~/.config/rice
cd ~/.config/rice/btop/ 
./setup.sh
```

