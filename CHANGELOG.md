# Changelog

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
