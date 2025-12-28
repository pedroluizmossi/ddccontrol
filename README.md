# DDC Brightness Control - Plasmoid

A KDE Plasma widget that controls the brightness of monitors via the DDC-CI protocol.

<img width="605" height="221" alt="image" src="https://github.com/user-attachments/assets/49cc67ab-7beb-4d30-9a43-51024b46e2d4" />

## Requirements

- KDE Plasma 6.0+
- `ddcutil` installed on the system
- Proper permissions to access I2C devices

### Step 1: Install system dependencies

**Fedora/RHEL:**
```bash
sudo dnf install ddcutil
```

**Debian/Ubuntu:**
```bash
sudo apt install ddcutil
```

**Arch Linux:**
```bash
sudo pacman -S ddcutil
```

### Step 2: Configure permissions (optional, but recommended)

If you receive a permission error when using ddcutil:
```bash
# Add your user to the i2c group
sudo usermod -a -G i2c $USER

# Log out and log back in
```

Or alternatively, use `sudo` when running ddcutil:
```bash
ddcutil detect --sudo
```

### Step 3: Clone the repository

```bash
# Clone to a temporary folder
git clone https://github.com/your-user/com.pedroluizmossi.ddccontrol.git
cd com.pedroluizmossi.ddccontrol
```

### Step 4: Install the Plasmoid

```bash
# Create the directory if it doesn't exist
mkdir -p ~/.local/share/plasma/plasmoids

# Copy the plasmoid to the correct folder
cp -r . ~/.local/share/plasma/plasmoids/com.pedroluizmossi.ddccontrol/
```

### Step 5: Restart Plasma Shell

```bash
# Restart Plasma Shell to load the new widget
kquitapp plasmashell && kstart5 plasmashell &
```

### Step 6: Add the widget to the panel

1. Right-click on the Plasma panel
2. Select "Edit Panel"
3. Search for "DDC Brightness"
4. Add to your taskbar

### Verification

After installation, you can verify that everything is working:

```bash
# Test if ddcutil is working
ddcutil detect

# You should see a list of connected monitors with DDC-CI support
```

## Usage

1. Add the widget to your Plasma panel
2. The widget will automatically detect connected monitors that support DDC-CI
3. Use the dropdown to select which monitor to control
4. Use the slider to adjust brightness
5. Click the refresh button (🔄) to re-detect monitors

## Project Structure

```
com.pedroluizmossi.ddccontrol/
├── metadata.json          # Plasmoid metadata
├── contents/
│   ├── config/
│   │   └── config.ui      # Configuration interface
│   └── ui/
│       └── main.qml       # Main interface (QML)
├── README.md              # This file
└── .gitignore             # Files to ignore in git
```

## Features

- ✅ Automatically detect monitors with DDC-CI support
- ✅ Select which monitor to control
- ✅ Adjust brightness via slider
- ✅ Remember last monitor selection
- ✅ Re-detect monitors with refresh button

## Troubleshooting

**Error: "ddcutil not found"**
- Verify that ddcutil was installed correctly
- Run `which ddcutil` to confirm the path

**Widget does not detect monitors**
- Test `ddcutil detect` in the terminal
- Check if you have sufficient permissions
- Add your user to the i2c group: `sudo usermod -a -G i2c $USER` (requires logout/login)
- Verify that your monitor supports DDC-CI

**Widget loading infinitely**
- Test `ddcutil detect` in the terminal
- Check if you have sufficient permissions

**Slider does not control brightness**
- Test manually: `ddcutil setvcp 10 50 --bus=XX` (replace XX with your bus number)

**No monitors detected**
- Not all monitors support DDC-CI
- Connect the monitor directly (not via USB-C or docks)
- Verify that the monitor is powered on

## Uninstallation

If you need to remove the widget:

```bash
rm -rf ~/.local/share/plasma/plasmoids/com.pedroluizmossi.ddccontrol
# Restart Plasma Shell
kquitapp plasmashell && kstart5 plasmashell &
```

## Author

Pedro Luiz Mossi

## License

MIT
