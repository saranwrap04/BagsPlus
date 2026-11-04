Bags Plus 1.0.12
by Saranwrap
For World of Warcraft 3.3.5a (Interface 30300)

One window for your bags, bank and guild bank, with categories, search,
sorting, and every character's saved items.

Install
  Copy the BagsPlus folder to Interface\AddOns and restart the game.
  Open the settings with /bplus.

Features
  Bags and bank
    - Your bags open as one window, your bank as another. The default bag and
      bank windows are replaced.
    - Two layouts: one single grid, or categories (New items, Equipment sets,
      Quest, Food & Drink, Potions & Elixirs, Consumables, Weapons, Armor,
      Trade Goods, Reagents, Gems, Glyphs, Recipes, Bags, Ammunition, Keys, Junk,
      Miscellaneous). Click a section title to collapse it.
    - Special bags (quiver, herb bag and so on) keep their own section.
    - Free slots shown as one button with the count, all slots, or hidden.
    - Resize a window from its bottom-right corner: dragging changes the number
      of columns (the height follows the contents).
    - Bag slots strip: click a bag to show only its items, drag bags in and out.
    - The keyring is not mixed into the main view. Click "Bags" at the top, then
      the keyring button, to see only your keys (click it again, or right-click,
      to go back). The K key opens the same view.
    - Watched currencies, money and free slot count in the footer.
    - Bank bag slots can be bought from the bank window.
  Sorting
    - By default nothing is re-sorted on its own: items stay in the order they
      have in your bags (and new items stay in their normal category, with the
      new-item glow) until you click Sort. Turn off "Sort only when I click
      Sort" in Settings > Layout to have categories sort themselves.
    - Sort button: combines partial stacks, fills special bags and sorts in
      place by type, quality, name or item level. Works for the bank too.
  Item buttons
    - Borders in the quality colour (common, uncommon, rare, epic, legendary,
      heirloom; the lowest quality that gets one is a setting). Slots of special
      bags are coloured by type: engineering orange, herbs green, enchanting
      blue, mining grey, inscription teal, leatherworking brown, gems red,
      quiver brown, soul purple, keys gold.
    - Stack counts use the same outlined font and size as the item level.
    - Quality borders, item level (white with a dark outline, size adjustable), bind type (BoE, BoP, BoU, BoA), a coin icon on every junk (grey) item,
      equipment set and quest markers in three corners.
    - Unusable items tinted red, new items pulse until you hover them. Items
      already in your bags when you log in are never marked new.
    - Windows open above the chat; the layer is a setting.
  Search
    - Type in the search box; items that do not match are dimmed.
    - Plain words match name, type and slot. Filters: q:epic, q:>=rare,
      ilvl:>=200, ilvl:180-200, req:>=70, count:>1, type:armor, sub:plate,
      slot:head, set:any, boe, bop, bou, boa, soulbound, junk, new, quest,
      unusable, usable, price:>5g, bag:2, tt:text in tooltip.
    - !word excludes, "|" or "or" combines alternatives.
  Custom categories
    - Settings > Categories: create your own sections from a search rule
      and/or a list of item IDs, reorder, enable or disable any category.
      Right-click a section title (or use Settings > Categories > Item order) to
      choose how the items in that category are ordered: type, quality, name,
      item level, bag order, or the reverse of those.
      Click any built-in category to rename it or move items into it (by rule,
      by item ID or by dropping an item on the button); Reset undoes it.
  Characters and guild bank
    - The name button at the top of a window lists every character; pick one
      to see their saved bags and bank, also while offline.
    - Guild bank contents are saved when you view them. /bplus guild shows the
      saved tabs from anywhere. "Scan tabs" at the guild bank opens each tab
      once to save everything.
  Vendors
    - Sell junk button at merchants, optional automatic selling.

Commands
  /bplus                  settings
  /bplus bags | bank | guild
  /bplus sort
  /bplus search <text>
  /bplus reset            reset window positions

Notes
  - Settings > Item buttons > "Show category and item type in tooltips" adds a
    line to every item tooltip naming its category and the type, sub-type and
    slot the game reports, useful for checking where an item belongs. Anything
    can be moved with a custom category (Settings > Categories).
  - The bank of a character is saved each time you open it.
  - Each equipment set gets its own section named after the set (sets made with
    the in-game equipment manager).
  - Category names for sub-types (Food & Drink, Potions) follow the English
    client item names; other languages fall back to Consumables.

SavedVariables: BagsPlusDB, BagsPlusChars, BagsPlusGuilds

Author: Saranwrap - github.com/saranwrap04
