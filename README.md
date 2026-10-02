# First Names - WoW Forever Addon

**First Names** is a World of Warcraft addon created specifically for **WoW Forever** that hides character last names across the game interface while preserving full game functionality (whispering, targeting, inspecting, inviting, etc.).

On WoW Forever, character names may include both a first name and a last name, separated by at most one single space. This addon identifies last names using this rule and cleanly hides them.

---

## Features

- **Chat Window**:
  - Automatically hides last names in all player chat links (`[FirstName LastName]` becomes `[FirstName]`).
  - Underlying hyperlink targets remain untouched so clicking names to whisper, invite, inspect, or who works normally.
  - Formats channel messages, whispers, emotes, and system notifications.
- **Above Characters (Nameplates)**:
  - Hides last names on overhead player nameplates in the 3D world.
- **Unit Frames**:
  - Hides last names on `TargetFrame`, `FocusFrame`, `PlayerFrame`, Target of Target, Focus of Target, and Party/Raid frames.
- **In-Game Options & Key Binding**:
  - Fully integrated into the WoW Settings / Interface Options menu (`Options` -> `AddOns` -> `First Names`).
  - Interactive keybind button in the options panel allows you to bind any key or key combination to toggle last names back on and off at will.
  - Also declared in `Bindings.xml` under `Game Menu` -> `Key Bindings` -> `AddOns` -> `First Names`.
  - Audio and chat notifications when toggling.
  - Immediately refreshes visible nameplates and unit frames upon toggling.

---

## Commands

- `/firstnames` or `/fn` - Open the First Names options panel
- `/fn toggle` or `/firstnames toggle` - Toggle last names on / off
- `/fn status` - Check current visibility state and bound key
- `/fn help` - Display command help

---

## Configuration

In `Options` -> `AddOns` -> `First Names`:
- **Hide Character Last Names (Master Toggle)**: Master on/off switch for hiding last names.
- **Chat Window**: Enable/disable hiding in chat.
- **Above Characters (Nameplates)**: Enable/disable hiding on nameplates.
- **Auto-Enable Friendly Nameplates (Headline Mode)**: Automatically activates friendly nameplates in Name-Only mode (without health bars) so overhead names become modifiable UI frames.
- **Nameplate Height Offset (Slider)**: Adjust the vertical height of nameplates above characters (range: -60 to +120). Includes a Reset button to return to default (0). Updates all visible nameplates in real time as you drag the slider.
- **Unit Frames**: Enable/disable hiding on Target, Focus, Player, and Party frames.
- **Toggle Key Binding**: Click to bind a key or combination (e.g. `F10`, `CTRL-L`, `SHIFT-N`), press `ESC` to cancel, or click `Clear` to unbind.
