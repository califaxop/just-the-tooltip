# Changelog

## 1.9.0 (Milestone 4: customization and presentation; test build)

- New in the settings: choose where each line shows: on the game's tooltip, on chat links, on
  comparisons (Item ID, Spell ID, Item level, Where gear comes from). Everything is on as before
  until you change it.
- Put the lines on items in your own order (Up / Down).
- More detail (off by default): pick Alt or Ctrl. Hold it over a tooltip to see every source (not
  only three), each tagged with where Just the Tooltip! learned it, and IDs and item level even
  where they're turned off.
- At 100% size, tooltips keep their own size, so one another addon sizes is no longer reset.
- Profiles: keep several sets of settings and pick one per character. Your current settings are
  the shared ones every character uses until it picks a profile.
- `/jtt source` says which of its drop lines NeedRoll's newer line replaces on the tooltip.

## 1.8.0 (Milestone 3: information engine; test build)

- Each tooltip's item, spell or unit details are read once and shared by every line and colour,
  so fewer questions go to the game for each tooltip.
- An item's kind is known before the game has its full details. The item level still appears once
  they arrive.
- Each kind of information works on its own: if one runs into an error, the rest of the tooltip
  still appears. The error is said once and listed in the new `/jtt info`.
- An item level or target line another addon already shows isn't added a second time, and Just the
  Tooltip!'s own lines never appear twice on one tooltip.
- New `/jtt source <item>`: every place an item comes from, where Just the Tooltip! learned it
  (its data, Questie, NeedRoll), and how far to trust it. Drops are marked as ordered by Classic
  1.12 drop chances. The tooltips themselves stay as they were.

## 1.7.0 (Milestone 2: tooltip lifecycle and compatibility; test build)

- Each tooltip starts with a clean slate. Nothing about the tooltip before it (a unit, a thing in
  the world, the frame you were over) carries over.
- A frame's tooltip is hidden when you move off the frame only if you were on it. A tooltip an
  addon or the keyboard shows for a frame you're not over stays up. A frame that hides takes its
  tooltip with it.
- Blizzard's look puts back the tooltip border's own transparency and colour, so a border another
  addon tinted or faded stays as that addon set it.
- Comparison and other tooltips the game makes after login get JTT's look too.
- New `/jtt compat`: other tooltip addons, whether anything moves tooltips after JTT places them,
  which tooltips are styled, and what JTT does with NeedRoll, Auctionator and Questie. It's in
  `/jtt report` too.

## 1.6.0 (Milestone 1: tooltip accuracy and reliability; test build)

- Fixed: a Spell ID or Item ID could be left out when the tooltip already showed a longer number
  containing it (Spell ID 1234 next to "Item ID: 12345"). IDs are now matched as whole numbers,
  and other addons' ID lines are recognised in their own wordings.
- Fixed: with the tooltip following the cursor, its distance from the cursor grew and shrank with
  the Size slider. It's now the distance you set at any size. Changing the size moves the tooltip
  at once, even with the mouse still.
- Fixed: a unit detail the game hides (or that fails to read) could stop a tooltip's target line
  and colours with an error. Now that detail is just left out.
- Fixed: hovering new gear in the first seconds after login, before Questie was ready, could stop
  Questie's sources from showing for the rest of the session.
- `/jtt report` also shows the source data's and Questie's state.

Earlier versions: README.md, "Recent changes".
