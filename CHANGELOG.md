# Changelog

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
