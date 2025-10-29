# Coreveo Help

## Permissions Overview

Coreveo needs limited system permissions to function. Here’s what each one means and how Coreveo uses it.

### Accessibility (Required for some features)
- Why: Needed for limited interactions with system UI in certain features.
- How to grant: System Settings → Privacy & Security → Accessibility → enable Coreveo.
- In-app: Use the "Open System Settings" button next to Accessibility to jump directly there.

### Full Disk Access (Optional)
- Why: Allows Coreveo to read certain protected system stats and logs that improve insights.
- How to grant: System Settings → Privacy & Security → Full Disk Access → enable Coreveo.
- In-app: Use the "Open System Settings" button next to Full Disk Access.

### Network (Not required)
- macOS does not have a general "Network permission". Only apps with a Network Extension (VPN, Content Filter, Packet Tunnel, etc.) require special user setup.
- Coreveo does not ship a Network Extension, so there is nothing to grant. You may see a "Network" info row during onboarding only if a Network Extension is present on the system; otherwise it’s hidden or marked "Not required on this Mac."

## General Settings

- Launch at Login: Start Coreveo automatically when you sign in.
- Start Monitoring on Launch: Begin collecting stats when the app launches.
- Show Menu Bar Item: Toggle the compact menu bar summary.
- Refresh Interval: Controls how often stats update (0.5s–5s).
- Temperature Units: Choose Celsius or Fahrenheit for temperature displays.

## Appearance

- Theme: System / Light / Dark.
- Accents: Uses your macOS accent color and adapts to theme.

## Troubleshooting

- I don’t see Coreveo in System Settings lists: Launch Coreveo once, then use the in‑app "Open System Settings" buttons.
- Stats don’t update: Increase Refresh Interval or toggle monitoring off/on.
- Menu bar item missing: Enable "Show Menu Bar Item" in General settings.

If you need more help, open an issue on the repository or contact support.
