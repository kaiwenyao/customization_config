-- Match the VS Code theme: Catppuccin Latte
return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    opts = {
      flavour = "latte",
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin-latte",
    },
  },
}
