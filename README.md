# First Names - WoW Forever Addon

**First Names** is a World of Warcraft addon created specifically for **WoW Forever** that hides character last names across the game interface while preserving full game functionality (whispering, targeting, inspecting, inviting, etc.).

On WoW Forever, character names may include both a first name and a last name, separated by at most one single space. This addon identifies last names using this rule and cleanly hides them.

---

## Important: Overhead Names & Friendly Nameplates

World of Warcraft’s default native overhead names (rendered directly into the 3D world as raw text) are locked by the game engine and cannot be modified by addons.

To hide last names above players' heads, Friendly Nameplates must be enabled. The addon automatically sets them to clean Headline Mode (showing only the player's name without health bars) so overhead names become editable UI elements. If you ever disable friendly nameplates, overhead names will revert to the game's default native full names.

---

## Features

* Chat Window Cleaning: Displays player chat links as [FirstName] instead of [FirstName LastName].
* Seamless Whispering: Underlying hyperlinks remain intact. Clicking a name to whisper, invite, inspect, or /who always uses the player's full server name.
* Overhead Player Names: Hides last names above characters in the 3D world using clean headline-style nameplates.
* Smart Player Detection: Strictly modifies player characters only—NPCs, guards, vendors, pets, and monsters remain untouched.
* Unit Frames Support: Cleans up last names on Target, Focus, Player, and Party frames.
* Nameplate Height Adjustment: Includes a slider to fine-tune the vertical height of overhead names above character models.
* Instant Toggle & Keybind: Easily bind a key in the settings panel to toggle last names on and off whenever you need to check someone's full name.

---

## Configuration

* `/fn` or `/firstnames` — Open the configuration panel
* `/fn toggle` — Toggle last names on / off
* `/fn status` — Show current visibility state and bound key