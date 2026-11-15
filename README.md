# OctoThreat — WotLK-Style Threat Meter & Target Debuff Timers (WoW 1.12.1)

![WoW Version](https://img.shields.io/badge/WoW-Vanilla%201.12.1-orange.svg)
![Interface](https://img.shields.io/badge/Interface-11200-blue.svg)
![Lua](https://img.shields.io/badge/Lua-5.0-yellow.svg)

**OctoThreat** is a lightweight, standalone UnitFrame Threat Meter and Target Debuff Timer AddOn built specifically for **World of Warcraft: Vanilla (1.12.1)**. It brings the iconic **Wrath of the Lich King (WotLK)** beveled metallic threat indicator tab, dynamic target aggro glows, smart Hunter Pet / Tank taunt synchronization, and Plater-style debuff countdowns directly to the default 1.12.1 TargetFrame.

---

## ✨ Key Features

### 1. WotLK Beveled Threat Tab & Dynamic Target Glow
* **Authentic WotLK Threat Badge:** Displays your real-time threat percentage (`0%` – `100%+`) inside a custom-textured, chamfered metallic tab (`ThreatTabBorder.tga` & `ThreatTabFill.tga`) mounted cleanly above the Target Name Bar or Target Portrait.
* **Color-Coded Threat States & Pulsing Glows:**
  * **Safe Zone (`< 50%`):** Muted olive-green fill with no distracting glow—continue your normal DPS rotation.
  * **Medium Threat (`50% – 79%`):** Amber-olive fill with a subtle top aura glow (`ThreatTopGlow.tga`).
  * **High Threat Warning (`80% – 99%`):** Bright WotLK gold/yellow fill with a pulsing golden-orange warning glow around the TargetFrame—throttle DPS so your Tank or Pet can build a lead.
  * **Aggro / Over-Threat (`100%+`):** Crimson red fill with a pulsing red border flash around the entire TargetFrame.
* **Party Threat Tabs:** Displays compact threat percentage tabs next to `PartyMemberFrame1` through `PartyMemberFrame4`.

### 2. Free Drag & Drop Placement (`ALT + Left-Click`)
* Hold **`ALT + Left-Click`** on the Target Threat Tab at any time (including in `/ot test` mode) to drag it anywhere on your screen.
* Coordinates are automatically saved per character in `OctoThreatDB` and persist across sessions.

### 3. Smart Hunter Pet `Growl` & Tank `Taunt` Synchronization
* **Pet Action Bar Cooldown Scanner:** In Vanilla 1.12.1, Hunter Pet `Growl` and Warlock Voidwalker `Torment` / `Suffering` often do not print numerical threat lines in the Combat Log. **OctoThreat** directly monitors your Pet Action Bar slots (`1..10`) and immediately syncs your Pet's threat to match the highest threat on the table plus the flat taunt bonus whenever `Growl` or `Torment` triggers its cooldown—even if you attacked the mob before sending in your pet.
* **Real-Time Aggro Transition Detection:** Monitors `targettarget` transitions so when a Tank or Pet pulls aggro off you, their baseline threat is immediately synchronized—preventing false `400%+` threat spikes.
* **Threat Drops:** Automatically detects Hunter `Feign Death` (instant `0%` threat reset), Rogue `Feint`, Priest `Fade`, and Pet `Cower`.
* **Standalone + KLHThreatMeter (KTM) Integration:** Works 100% standalone out of the box via Combat Log parsing, and automatically reads raid/party threat data from **KLHThreatMeter** if installed.

### 4. Plater-Style TargetFrame Debuff Timers (OmniCC Blocked)
* **Built-In Clockwise Sweep & Countdown:** Renders a 4-quadrant clockwise shade sweep and crisp outlined countdown text directly on `TargetFrameDebuff1..16` (`White` -> `Yellow` at `<= 6s` -> `Red` with `0.1s` decimals at `<= 3.5s`).
* **Zero OmniCC Overlap:** Automatically sets `noomnicc` and `noCooldownCount` flags on TargetFrame debuff icons so external cooldown addons never draw duplicate overlapping numbers.
* **Dynamic Spellbook, Rank, Talent & Combo Point Scanner:** Automatically scans your Spellbook and ActionBar tooltips to learn exact durations for your current character level, spell rank, talents, and Rogue Combo Points.

---

## 📦 Installation

1. Download the repository and extract the **`OctoThreat`** folder.
2. Make sure the folder is named **`OctoThreat`** and contains:
   ```text
   Interface/AddOns/OctoThreat/
   ├── OctoThreat.toc
   ├── OctoThreat.lua
   └── Textures/
       ├── ThreatTabBorder.tga
       ├── ThreatTabFill.tga
       └── ThreatTopGlow.tga
   ```
3. Copy the `OctoThreat` folder into your World of Warcraft directory:
   ```text
   World of Warcraft\Interface\AddOns\OctoThreat
   ```
4. Restart World of Warcraft (required when loading new `.tga` textures for the first time) and ensure **OctoThreat** is enabled in the AddOns menu.

---

## 💻 Slash Commands

Type `/ot` or `/octothreat` in-game to access all commands:

| Command | Description |
| :--- | :--- |
| **`ALT + Left-Click Drag`** | Freely drag the Target Threat Tab anywhere on screen and auto-save its position. |
| `/ot test` | Toggle Test Mode (`93%` preview with Gold Glow). Use `/ot test 100` to preview Red Aggro Glow. |
| `/ot pos` | Reset/toggle tab position between **Above Target Name Bar (WotLK)** and **Above Target Portrait**. |
| `/ot glow` | Toggle the TargetFrame threat glow ON or OFF. |
| `/ot size <w> <h>` | Set custom width and height for the Threat Tab (Default: `/ot size 64 22`). |
| `/ot offset <x> <y>` | Fine-tune X and Y pixel offsets (Default: `/ot offset 0 2`). |
| `/ot debuffs` | Toggle the built-in Plater-style countdown timers on TargetFrame debuff icons. |
| `/ot playerbar` | Toggle an optional secondary threat tab underneath your `PlayerFrame` Mana Bar. |
| `/ot tank` | Lock your current friendly target as the Main Tank (or clear target and type `/ot tank` for Auto mode). |
| `/ot reset` | Manually reset the active threat table. |

---

## 🤝 Compatibility

* **Client:** World of Warcraft 1.12.1 (Interface `11200`)
* **Optional Dependencies:** `KLHThreatMeter` (auto-detected if present)
* **UnitFrames:** Modifies **only** `TargetFrame` (and `PartyMemberFrame1..4`), leaving `PlayerFrame` untouched for full compatibility with custom player frame addons.