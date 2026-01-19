return {
  -- 1. 颜色主题：Catppuccin (摩卡口味)
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000, -- 确保它在启动时最先加载
    config = function()
      -- 加载主题
      vim.cmd.colorscheme("catppuccin-mocha")
    end,
  },

  -- 2. 底部状态栏：Lualine
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" }, -- 依赖图标
    config = function()
      require("lualine").setup({
        options = { 
          theme = "catppuccin" -- 让状态栏也用这个主题
        },
      })
    end,
  },
  
  -- 3. 图标插件 (很多插件都需要它)
  { "nvim-tree/nvim-web-devicons", lazy = true },
}
