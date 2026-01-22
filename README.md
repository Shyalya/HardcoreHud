# HardcoreHUD (WoW Classic)

HardcoreHUD is a lightweight heads-up display addon for **World of Warcraft Classic** that keeps key survival information close to the center of your screen.

It reduces the need to constantly look at default unit frames by presenting clean health/power bars, clear warning overlays, and a compact cooldown/utility row for quick decision-making—especially useful for Hardcore-style gameplay.

## Features

- Center-screen player (and optional target) health/power HUD bars
- Clear warning overlays for low health / out-of-mana situations
- Two-row cooldown layout:
  - **Utility row**: Healing potion, Mana potion (mana classes), Bandage, Hearthstone, and your racial ability (e.g., Escape Artist)
  - **Class cooldown row**: Shows key class defensives/mobility only when learned
- Cooldown spirals + readable countdown text for spells and items
- Bag-aware utility buttons:
  - Picks the highest-rank healing/mana potion available and binds it for click-to-use
  - Shows buttons dimmed/desaturated when you have none available
- Combat-safe UI updates to avoid protected-action errors during combat

## Compatibility

- Developed and tested for **World of Warcraft Classic (1.15.8)**.
- Uses Classic-compatible APIs and avoids insecure UI operations in combat where possible.

## Installation

1. Download or clone this repository.
2. Copy the `HardcoreHUD` folder into your Classic AddOns directory:

   ```text
   World of Warcraft/_classic_/Interface/AddOns/
   ```

3. Restart the game or run `/reload`.
4. Enable **HardcoreHUD** in the AddOns list on the character select screen.

## Helpful Commands

- `/hhdbg` — prints debug info about the HUD utility buttons (visibility, anchors, etc.)
- `/hhforce` — temporarily forces utility buttons to the screen center for troubleshooting

## Notes

- Some elements only appear when relevant (e.g., mana potion button for mana users, class cooldowns only if learned).
- If you find a missing racial/class cooldown, open an issue and include your class/race plus the spell name/ID.
