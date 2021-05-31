They're a bit of a mess and are constantly changing -- be warned.

# Requirements:

```
brew install rcm
```

# NeoVim

## Setup:

```
rcup
```

```
brew install luajit --HEAD
brew install nvim --HEAD
```

Upon entering NeoVim for the first time, [Packer](https://github.com/wbthomason/packer.nvim) should automatically install.

Afterwards, in NeoVim:
```
:PackerInstall
```

### Built-in LSP

Right now, there are only a few languages I have configured. They can be installed as such:

```
:LspInstall typescript
```
