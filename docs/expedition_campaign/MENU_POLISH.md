# Menu presentation pass

The title, pause menu, combat inventory, and campaign gear services share the existing slate/bronze palette through locally duplicated themes. Other UiStyle consumers retain their own theme instances.

The title gives a resumable campaign first keyboard focus and shows its saved hero, realm, phase, and gold. New Campaign becomes the default when no campaign can continue. Damaged saves keep Continue available for the existing recovery flow; abandoned campaigns are described as previous journeys. Summary reads never write a save. Classic realms, hero selection, account services, and suspended-night resume remain available.

Inventory now separates worn gear, backpack, and selected gear into cards. Its comparison uses the existing item-local modifier aggregation, keeps Added/Increased/More distinct, includes both legendary power descriptions, and tints individual changes according to each stat's direction. The existing likely-upgrade score remains explicitly an estimate. Campaign equipment and market cards preserve all actions and detailed rolls; equipment comparison width grows with available space. Long item titles wrap and long details scroll.

## Safe preview

From the repository root:

```sh
godot --path . -s tools/menu_polish_preview.gd
```

The preview runs the real game with a new campaign in a unique `user://menu_polish_previews/` directory. Account writes are disabled, and campaign, Classic, and profile paths are all redirected before the main scene loads. Continue Campaign opens town equipment and the market; a Classic Night provides the pause and combat inventory screens. Regular saves are untouched.

## Verification

```sh
godot --headless --path . -s tools/menu_polish_ui_test.gd -- --screen=behavior
godot --headless --path . -s tools/ui_test.gd
godot --headless --path . -s tools/campaign_ui_test.gd -- --screen=behavior
godot --headless --path . -s tools/campaign_settlement_stories_test.gd
godot --headless --path . -s tools/menu_polish_preview.gd -- --self-test
```

All checks above passed on Godot 4.7.2. Rendered title (valid/no/damaged save), Classic/campaign pause, full inventory, market, equipment, and legendary comparisons were captured at 1280×720 and 1920×1080. Focus, recovery, save immutability, operation labels, special powers, and full-backpack behavior were checked. Some scene-based harnesses still report resource/object cleanup warnings on shutdown; passing checks do not establish a warning-free engine shutdown. No balance, economy, save-format, or campaign-controller changes are included.
