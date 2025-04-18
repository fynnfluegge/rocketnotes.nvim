<div align="center">
  
  # rocketnotes.nvim
  
  [![Build](https://github.com/fynnfluegge/rocketnotes.nvim/actions/workflows/ci.yml/badge.svg)](https://github.com/fynnfluegge/rocketnotes.nvim/actions/workflows/ci.yml)
  [![License](https://img.shields.io/badge/License-MIT%20-green.svg)](https://opensource.org/licenses/MIT)

</div>

#### Neovim plugin for [rocketnotes](https://www.takeniftynotes.net/). Synchronize all documents locally inside Neovim with ease.

## 📦 Installation

```lua
{
  "fynnfluegge/rocketnotes.nvim",
  dependencies = {
    "OXY2DEV/markview.nvim",
  },
}

```

## 🚀 Usage

- `:RockentNotesAuth`
  - Enter config token. Can be found in User info as `Vim Config Token`:  
    <img width="256" src="https://github.com/user-attachments/assets/9da5522f-1927-42cd-81fe-190104df83e5" />
  - Enter username
  - Enter password
  - Stores authentication data under `~/Library/Application Support/rocketnotes/tokens.json`
- `:RockentNotesSync`
  - Synchronizes all documents to `~/.rocketnotes`
  - Stores cache files for all subsequent synchronizations under `~/Library/Application Support/rocketnotes`

> [!TIP]
> Establish git in `~/.rocketnotes` to enable backup and versioning with `cd ~/.rocketnotes && git init --initial-branch=main`

## Limitations

- [ ] Newly created documents locally are not synched. New documents must be added via webapp.
- [ ] Remotely renamed or restructured documents are synched, but old documents remain locally and must be deleted manually.
- [ ] Conflicts are not merged but needs to be resolved manually. Both conflicting files are kept for this.
