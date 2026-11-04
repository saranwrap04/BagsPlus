<p align="center"><img src="images/logo.png" width="128" alt="Bags Plus"></p>

# Bags Plus

One window for your bags, bank and guild bank on **World of Warcraft 3.3.5a** (ChromieCraft / AzerothCore), with categories, search, sorting and the saved items of every character.

**Version 1.0.12** - by Saranwrap

## Features

- **Bags and bank in one window each**, replacing the default windows
- **Two layouts**: a single grid or grouped categories (click a section title to collapse it)
- **Nothing re-sorts by itself** unless you turn that on; items keep their bag order until you press Sort
- **Sort in place**: merges partial stacks, fills special bags, sorts by type, quality, name or item level (bank included)
- **Search** that dims what does not match, with filters such as `q:>=rare`, `ilvl:>=200`, `type:armor`, `slot:head`, `boe`, `unusable`, `price:>5g`, `tt:text`, plus `!` to exclude and `or` for alternatives
- **Borders** for every quality, and **colour-coded slots for special bags** (engineering, herbs, enchanting, mining, inscription, leatherworking, gems, quiver, soul bags, keys)
- **Item buttons**: quality borders, item level, bind type, junk coin, equipment set and quest markers, red tint for unusable items, pulsing new items
- **Item order per category**: right-click a section title to sort that category by type, quality, name, item level or bag order (or reversed)
- **Custom categories** from a search rule and/or item IDs, with reordering and enable/disable of every category; click a built-in category to rename it or move items into it
- **All characters**: pick a character from the name button to see their saved bags and bank, offline
- **Guild bank** saved when viewed, readable anywhere with `/bplus guild`
- **Resize** from the bottom-right corner (changes the number of columns)
- **Bag slots strip**: show only one bag, drag bags in and out; special bags (quiver, herbs...) get their own section
- Keyring kept out of the main view: click **Bags** at the top, then the keyring button, to see only your keys. Watched currencies, money, free slot count, bank slot purchase, sell junk button at vendors
- Flat dark look with a gold accent; settings in a side-bar window

## Install

1. Download the zip and copy the `BagsPlus` folder into `Interface\AddOns`.
2. Restart the game (a full restart, not `/reload`, when updating from an older version that added files).
3. Open the settings with `/bplus`.

## Commands

| Command | What it does |
| --- | --- |
| `/bplus` | Settings |
| `/bplus bags`, `bank`, `guild` | Open a window |
| `/bplus sort` | Sort bags (or bank when it is open) |
| `/bplus search <text>` | Search your bags |
| `/bplus reset` | Reset window positions |

## Search

Plain words match name, type and slot. Combine terms with spaces (and), `or` or `|`, exclude with `!`.

`q:epic` `q:>=rare` `ilvl:>=200` `ilvl:180-200` `req:>=70` `count:>1` `type:armor` `sub:plate` `slot:head` `set:any` `boe` `bop` `bou` `boa` `soulbound` `junk` `new` `quest` `unusable` `usable` `price:>5g` `bag:2` `tt:text`

## Notes

- A character's bank is saved each time that character opens it.
- Turn on *Show category and item type in tooltips* (Settings > Item buttons) to see which category an item is in and the type, sub-type and slot the game reports; any item can be moved with a custom category.
- Each equipment set gets its own section named after the set (sets made with the in-game equipment manager).
- Sub-type categories (Food & Drink, Potions & Elixirs) follow English item names; other client languages fall back to Consumables.
- SavedVariables: `BagsPlusDB`, `BagsPlusChars`, `BagsPlusGuilds`.

## Author

Saranwrap - [github.com/saranwrap04](https://github.com/saranwrap04)
