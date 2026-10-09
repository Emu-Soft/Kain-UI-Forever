<p align="center">
  <img src=".github/logo.png" alt="K-UI: Forever" width="128">
</p>

<h1 align="center">K-UI: Forever</h1>

<p align="center">
  Edit Mode+ for <b>World of Warcraft: Forever</b>.<br>
</p>

<p align="center">
  <a href="../../releases/latest"><b>Download the latest release</b></a> &nbsp;·&nbsp; <a href="#with-wowup-recommended"><b>Install with WowUp</b></a>
</p>

---

## Installing

### With WowUp (recommended)

[WowUp](https://wowup.io) installs the addon for you and keeps it up to date.

1. Open WowUp and pick **WoW Forever** in the game dropdown at the top left.
2. Click **Get Addons** on the left, then **Install from URL** at the top right.
3. Paste `https://github.com/Emu-Soft/Kain-UI-Forever` into the box and click **Import**.
4. Restart the game (a `/reload` isn't enough the first time), then type `/kui` to open the settings.

<img src=".github/wowup-install-steps.png" alt="WowUp: pick WoW Forever, click Get Addons, then Install from URL, paste the link and click Import">

From then on, WowUp shows an update whenever a new version is released.

### Manually

1. Download **Kain-UI-Forever.zip** from the [latest release](../../releases/latest).
2. Unzip it. You'll get a folder called `Kain-UI-Forever`.
3. Put that folder in your WoW: Forever `Interface\AddOns` folder. The folder name must stay exactly `Kain-UI-Forever`.
4. Restart the game (a `/reload` isn't enough the first time), then type `/kui` to open the settings.

To update, replace the `Kain-UI-Forever` folder with the one from the newest release. Your settings are kept.

## Getting started

Every option starts switched off on a new character, so you only get the changes you choose.

- **Kain's preset** sets every option the recommended way in one click.
- **Import Kain-UI Profile** sets up the recommended screen layout and switches on the extra action bars.

Hover the small **i** icons in the settings to read what an option does. The blue gem in the bottom-left corner opens the patch notes, and the version you're running is shown in the bottom-right corner.

## Features

### Tooltips
- **Grow Right**: tooltips always appear in the same spot and grow to the right, so they don't jump around or cover things. Unlock the anchor to choose the spot.
- **Cast By**: buff and debuff tooltips show who cast them, in the caster's class colour. Works on you, your target and your party, and remembers the caster after they've left, gone out of range, or you've taken a boat.
- **Wowhead search**: hover an item, spell or quest (including links in chat) and press **Ctrl+Shift+W** to get a Wowhead search link, ready to copy. Change the key under *Key Bindings > AddOns > K-UI: Forever*.

### Chat
- **Enhance Chat**: timestamps, short channel names like `[1]`, clickable web links, a copy-chat button, hidden scroll bars, and the Up arrow to bring back messages you've sent. These pause inside dungeons and raids so chat always keeps working.
- **Emoji**: type codes like `:smile:` or pick one from the face button by the chat box. Over 1,500 to choose from.
- **Movable social button**: drag the friends button anywhere; friend pop-ups follow it.
- **Recent Allies notes**: right-click someone in Recent Allies and choose *Set Note*. All your characters can see it.

### Minimap
- **Square Minimap** with a metal border and soft inner shadow.
- **Minimap button box**: addon minimap buttons are tidied away; right-click the minimap to open them (with Square Minimap).
- **Detach and unlock minimap elements**: split off the zone bar, and move the mail icon, day/night indicator and difficulty badge.
- Let the minimap sit partly off the edge of the screen.

### XP bar
- **XP bar under your portrait**, with a gold marker where rested XP starts, and the option to hide Blizzard's.
- **XP per hour**: hover the bar and hold **Shift** to see XP per hour (killing, with travel, from quests), an estimate, and time to level.
- **Screenshot on level up**: a screenshot of every milestone, saved to your Screenshots folder.

### Windows, bags and loot
- **Global Dragging**: move the Character, Spellbook, Talents, Map, Quest Log, bags, professions, vendor, Social and more by their title bar.
- **Fast loot**, and **draggable loot roll windows** that never end up off-screen.
- Hide any **bag slot** (keyring included) and the bag bar's background art.
- Hide any **micro menu** button, or the whole menu.
- **Vendor**: auto-sell greys and auto-repair, optionally with guild funds.

### Questing
- **K-Key**: talk to NPCs from the keyboard. Number keys pick options and rewards; Space accepts quests and moves the text along.
- **K-Targeter**: one macro that always targets whatever your tracked quest needs next.
- **Quest item sparkles**: things you need for a quest sparkle so they're easy to spot.
- **RestedXP Guides tweaks**: guide arrow distance in metres, and hide Blizzard's quest tracker while the guide is showing.

### Graphics, camera and nameplates
- **Contrast**: recommended contrast and brightness, with a button to restore yours.
- **Weather intensity** and **max zoom distance** sliders.
- **Plater style** nameplates. Untick to get your own settings back.

### Macros
- **Weapon Swap Macro Helper**: drag your weapons into the slots at the top of the settings for a one-click swap macro.
- **Macro icon names**: hover any macro icon to see its name, or search icons by name.
- **Starter macros**: coin flip, skull and cross raid markers, and a guild inviter.

### Layout
- **Snap to elements**: things you move snap into line, with an alignment grid while you arrange.

## Commands

`/kainui` works anywhere `/kui` does. Type `/kui help` in game for this list.

| Command | What it does |
|---|---|
| `/kui` | Open the settings. |
| `/kui help` | Show the list of commands. |
| `/kui snapshot` | Everything needed for a bug report: your settings, any errors from this addon, and your other addons. |
| `/kui clearerrors` | Empty the list of errors in `/kui snapshot` (after you've sent it). |
| `/kui resetdrag` | Put windows you've dragged back where they started. |
| `/kui resetlootroll` | Put loot roll windows back in their normal place. |
| `/kui zonebarreset` | Put the zone bar back in its starting spot. |
| `/kui xpreset` | Start counting XP per hour again (handy after a break). |
| `/kui installmacros` | Add the starter macros again. |
| `/kui weaponswap` | Rebuild the weapon swap macro. |
| `/kui linksoff` | Switch Enhance Chat off straight away, if chat ever misbehaves. |
| `/kui factoryreset confirm` | Erase all of this addon's settings and start fresh. Can't be undone. |
| `/kainuiemoji on` / `off` | Show or hide emoji in chat. |
| `/kainuiemoji list` | List every emoji code you can type. |
| `/kkey` | K-Key options. |
| `/kt` | K-Targeter options. |
| `/rl` | Reload your interface. |
| `/flip` (or `/coin`) | Flip a coin as an emote. Target someone first to flip for them. |

| Key | What it does |
|---|---|
| **Ctrl+Shift+W** | Wowhead search for the item, spell or quest under your mouse. |

## Reporting a problem

1. Type `/kui snapshot` in game. A window opens with everything needed to look into it: your settings, any errors the addon has run into (with where you were at the time), your game version and your other addons.
2. Press **Ctrl+C** to copy it, and paste it into your report along with a few words on what happened.
3. Once it's sent, `/kui clearerrors` empties the error list so the next report starts fresh.

No extra addon is needed. If you use BugSack, its errors from this addon are included too.
