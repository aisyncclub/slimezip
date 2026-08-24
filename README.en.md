<div align="center">

<img src="docs/img/appicon.png" width="112" alt="SlimeZIP">

# SlimeZIP

### Stop scanning your menu bar for the icon you need

A single slime swallows your Mac's menu bar icons.
Keep the few you use; the rest go in and out with one click.

<br>

[한국어](README.md) · **English** · [日本語](README.ja.md) · [简体中文](README.zh.md)

[**Install**](docs/INSTALL.md) · [Website](https://aisyncclub.github.io/slimezip/) · [Latest release](https://github.com/aisyncclub/slimezip/releases/latest)

[![GitHub stars](https://img.shields.io/github/stars/aisyncclub/slimezip?style=for-the-badge&logo=github&label=star%20this%20repo&color=f5c518)](https://github.com/aisyncclub/slimezip/stargazers)
[![macOS](https://img.shields.io/badge/macOS-14%2B-0f7a66?style=for-the-badge&logo=apple&logoColor=white)](docs/INSTALL.md)
[![License](https://img.shields.io/badge/free-open%20source-0a5d4e?style=for-the-badge)](#license)

**If it saved you a minute, a star is the whole reward.**

</div>

> [!IMPORTANT]
> **The app's interface is Korean only.** This README is translated; the app is not,
> at least not yet. If that is a problem for you, it is a problem — please say so in an
> [issue](https://github.com/aisyncclub/slimezip/issues) and it moves up the list.
> Everything else below applies regardless of language.

<br>

<img src="docs/img/hero.png" alt="A menu bar overflowing without SlimeZIP, and the same bar with one slime holding the rest">

<br>

## The problem

Past about twenty icons, three things happen at once on a MacBook, Mac Studio or Mac mini.

| | |
|---|---|
| **Overflow just disappears** | No warning, no marker. Icons are cut from the left. A notch eats them sooner. |
| **You cannot tell whose icon it is** | Since macOS 26, Control Center draws them, so the window list reports every icon as its own. |
| **⌘-drag is the only way to move one** | One at a time, and you forget where you put it. |

---

## What it looks like

<table>
<tr>
<td width="42%" valign="top">

<img src="docs/img/ui-panel.png" alt="The panel that opens when you click the slime">

</td>
<td valign="top">

### Click the slime, get the panel

Every icon currently in the bar, **with the name of the app that owns it**.

- Blue button at the top — **reveal / hide again**. Instant, no restart.
- `‹ ›` on each row — reorder
- **Put in · take out** on each row — move across the hidden boundary
- Orange strip — which apps are waiting to apply, and how many
- Bottom — version, update check, credits, banner

</td>
</tr>
</table>

<table>
<tr>
<td valign="top">

<img src="docs/img/ui-welcome.png" alt="The Get Started screen in settings">

**Get started** — where settings opens the first time. Three steps and a tour.

</td>
<td valign="top">

<img src="docs/img/ui-icons.png" alt="The icon list in settings">

**Icons** — the wide list, for sorting several at once.

</td>
</tr>
<tr>
<td valign="top">

<img src="docs/img/ui-creator.png" alt="The creator screen in settings">

**Creator** — links, plus this copy's version and update.

</td>
<td valign="top">

<img src="docs/img/ui-diagnostics.png" alt="The diagnostics screen in settings">

**Diagnostics** — what works and what does not on this Mac.

</td>
</tr>
</table>

---

## What it does

### A squashed slime — the icon stays 22pt wide

<img src="docs/img/scale.png" alt="The slime flattening as the hidden count rises from zero to five or more">

**Hiding more never widens the icon.** A number would cost space, so the slimes squeeze
each other flat in the same slot instead. They blink, and they breathe.

### Everything else

| | |
|---|---|
| **Named, not guessed** | With Accessibility permission it reads what each app publishes, so you see "Tailscale", not an anonymous square. On this Mac, 35 of 43 items resolved to a name. |
| **In and out with a button** | No wrestling with ⌘-drag. |
| **Reorder** | `‹ ›` moves an icon left or right. |
| **Move SlimeZIP itself** | The panel's "position `‹ ›`". Ours to create, so no restart needed. |
| **Notices changes while hidden** | If a hidden icon's artwork changes, the slime twitches and an orange dot appears. |
| **Groups** | Several groups, collapsed and expanded independently. An "always hidden" group does not open on a normal click. |
| **Update check** | New releases show up in the panel; one button downloads and replaces this copy. |
| **0.0% CPU at rest** | Nothing is polled. |

---

## Install

### From a download

1. Get `SlimeZIP-*.zip` from [releases](https://github.com/aisyncclub/slimezip/releases/latest)
2. Unzip and drag `SlimeZIP.app` to **Applications**
3. macOS blocks the first launch → **System Settings → Privacy & Security**, scroll to the bottom, **Open Anyway**
4. Turn SlimeZIP on in **System Settings → Accessibility**

> **Right-click → Open no longer works.** Apple removed that route in macOS Sequoia.
> The System Settings path in step 3 is the only one left. Older guides on the web still
> say right-click; they predate Sequoia.

### From a terminal

```bash
curl -fsSL https://raw.githubusercontent.com/aisyncclub/slimezip/master/scripts/install.sh | bash
```

Same thing, minus step 3. [Read the script first](scripts/install.sh) if you like — piping
an unknown script into a shell is not a habit worth having.

The step-by-step guide with pictures is in [docs/INSTALL.md](docs/INSTALL.md) (Korean).

---

## How you use it

Two actions, and **the everyday one costs nothing.**

| Action | Restart | How often |
|---|---|---|
| **Reveal / hide again**, top of the panel | **none** | daily |
| **Put in · take out**, on a row | that app, once | only when placing an icon |

The blue button inflates and deflates a separator. No stored position is touched, so it is
instant.

Put in / take out moves the icon **across** that boundary for good, which means rewriting
the position macOS has stored for it — and macOS reads that value **only when the app
starts.** So that app restarts once. Once per app, however many of its icons moved.

### Controls

| | |
|---|---|
| **Click** | open the panel |
| **⌥ + click** | collapse ↔ expand directly |
| **Right-click** | settings and quit |

### Control Center icons are the exception

Wi-Fi, Battery, Sound and Bluetooth are drawn by Control Center on macOS 26. Writing their
position works, but quitting the process that draws half the menu bar to move one icon is
not a trade this app makes on your behalf. Those show **"applies at next login"** instead
of a restart button.

---

## How it works

macOS broke this area twice in a row. macOS 26 Tahoe poisoned window ownership, and macOS 27
Golden Gate restructured the menu bar outright — Bartender, Ice, Barbee, Thaw and
BetterTouchTool's menu bar features all stopped working. The measurements are in
[docs/RESEARCH.md](docs/RESEARCH.md) (Korean).

So the design principle is **runtime capability probing**. Nothing is hardcoded; the app asks
the OS what works and exposes only that. When something is unavailable it says so in a banner
rather than failing quietly.

```
UI  ────────────────────────  features switch on per Capabilities
MenuBarEngine  ─────────────  single source of truth for groups, order, state
HidingStrategy (protocol) ──  ★ an OS change is rewritten only down to here
  └ SpacerStrategy           length inflation · zero permissions · macOS 14–26
  └ (Phase 2) BridgeStrategy enumerate · move · remote click
```

### The hiding mechanism

Each group owns one invisible **separator** in the bar. Collapsing inflates that separator to
twice the screen width, which pushes **everything to its left off-screen.** Expanding shrinks
it back to 1pt. No permissions, no private API.

So "hidden" means "sits left of the separator", and moving an icon there is the one moment a
stored position gets rewritten.

### Measured

All of it taken on one machine — Mac Studio, macOS 26.5.

| | |
|---|---|
| **43** | menu bar items enumerated by the Accessibility sweep |
| **35** | resolved to an app name |
| **22pt** | icon width, whatever the hidden count |
| **0.0%** | CPU at rest |

What macOS permits was measured too.

| | |
|---|---|
| Enumerate · identify | ✅ via the Accessibility sweep |
| Hide | ✅ via separator inflation |
| Remote click | ✅ via `AXPress` |
| Write position through Accessibility | ❌ 0 of 34 succeeded |
| Synthesised ⌘-drag | ❌ moved 0pt |
| Write stored position + restart the app | ✅ works (461 → 792 confirmed) |

The last row is the mechanism in use.

### Not possible yet

- Icons already behind the notch cannot be pulled out this way
- System-priority items such as the screen-recording indicator cannot be hidden
- **Unread counts** of hidden apps are unknowable — macOS does not publish another app's
  badge state, so the slime twitches on artwork changes instead

---

## Privacy and network

**Two reads, at most once every six hours, and only while you have the panel open.**

| What | Where |
|---|---|
| Whether a newer release exists | `api.github.com/repos/aisyncclub/slimezip` |
| The banner copy | [`app-config.json`](web/app-config.json), on this repo's GitHub Pages |

**Nothing is sent.** Not your icon list, not usage, not an identifier. The Accessibility
permission is used to **read** only — no key capture, no logging. See
[the source](Sources/ZipBarKit/Services).

To switch the checks off:

```bash
defaults write com.zipbar.ZipBar com.zipbar.checkForUpdates -bool NO
```

The "check for updates" button still works with that off. Not wanting to be contacted
unasked and not wanting an answer when you ask are different things.

---

## Development

No Xcode required — Command Line Tools are enough.

```bash
swift build && swift test     # build + 113 tests
./scripts/build-app.sh        # produces dist/SlimeZIP.app
./scripts/release.sh v0.2.0   # stamp version, build, zip, publish a GitHub release
```

### Diagnostics

Run these first after any OS update, especially a beta.

```bash
./.build/debug/zipbar-probe capabilities   # what each backend can do here
./.build/debug/zipbar-probe list           # full enumeration
./.build/debug/zipbar-probe ax             # Accessibility sweep detail (needs permission)
```

UI is verified by drawing it, not by asserting it. These environment variables write the real
view hierarchy to a PNG — no screen recording permission, nobody at the keyboard.

```bash
ZIPBAR_PROBE_PANEL_SHOT=1     ZIPBAR_PANEL_OUT=/tmp/panel.png      # the panel
ZIPBAR_PROBE_SETTINGS_SHOT=1  ZIPBAR_SETTINGS_TAB=creator          # settings, per tab
ZIPBAR_PROBE_UPDATE=1                                              # the whole update path
```

Every screenshot in this README was taken that way.

### Distribution constraints

Accessibility permission means **no sandbox and no Mac App Store.** Direct distribution is the
only route.

Not notarised yet — that needs a $99/year Developer ID. Hence the System Settings step on
first launch. Notarising removes it and opens the door to a Homebrew cask.

### Contributing

Bug reports and pull requests welcome. In an
[issue](https://github.com/aisyncclub/slimezip/issues), say **what you were doing, where it
stopped, and your macOS version** — that is usually enough.

---

## License

Free, with the source open.

`Ice` is GPL-3.0. To keep future licensing options open, **its source is neither read nor
referenced here.** Only its behaviour was observed.

---

<div align="center">

**If you read this far, a star would mean a lot.** ⭐

[![GitHub stars](https://img.shields.io/github/stars/aisyncclub/slimezip?style=for-the-badge&logo=github&label=star%20this%20repo&color=f5c518)](https://github.com/aisyncclub/slimezip/stargazers)

<sub>SlimeZIP · by Ai싱크클럽 (AI Sync Club) · macOS 14+ · free · open source</sub>

</div>
