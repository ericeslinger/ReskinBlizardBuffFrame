# ReskinBlizzardBuffFrame

Moves and scales Blizzard's own `BuffFrame` and `DebuffFrame` on clients whose Edit Mode
does not expose them — written for **WoW: Forever**.

Why keep Blizzard's frame at all? Under Forever's aura restrictions, addon-drawn aura
displays (Arc Auras unit-aura groups and the like) cannot offer tooltips or right-click
cancel: they render through Blizzard's secure `AuraContainer` with the mouse disabled.
Blizzard's frame still has both. This addon just puts it where you want it.

## Commands

```
/rbf                      help and current settings
/rbf unlock | lock        drag the frames by their blue overlay; lock saves
/rbf scale <n>            scale both frames (0.5 - 2)
/rbf buffs <point> <x> <y>     e.g. /rbf buffs TOPRIGHT -10 -40
/rbf debuffs <point> <x> <y>
/rbf debuffs follow       hang the debuffs under the buffs (default)
/rbf reset                defaults
```

Points are the usual anchor names (`TOPLEFT`, `TOPRIGHT`, `CENTER`, …), offsets are in
UI units from that corner of the screen.

## Behaviour

- Anchors are re-applied after any `SetPoint` the game performs on the frames, so a UI
  layout refresh cannot move them back.
- Nothing is touched in combat; a change made in combat is applied on leaving it.
- Settings are account-wide (`ReskinBlizzardBuffFrameDB`).

## Install

Copy the `ReskinBlizzardBuffFrame` folder into `Interface/AddOns/`.

## License

MIT
