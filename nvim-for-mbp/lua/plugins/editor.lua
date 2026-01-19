return {
  -- 1. 文件管理器 (Neo-tree)
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
    },
    -- 设置快捷键：空格+e 打开文件树
    keys = {
      { "<leader>e", "<cmd>Neotree toggle<cr>", desc = "Explorer" },
    },
    config = function()
      require("neo-tree").setup({
        window = { width = 30 }, -- 设置侧边栏宽度
        filesystem = {
          filtered_items = { visible = true }, -- 显示隐藏文件 (.gitignore 等)
        },
      })
    end,
  },

  -- 2. 模糊搜索神器 (Telescope)
  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    -- 设置快捷键
    keys = {
      -- 空格+ff：搜索文件名
      { "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Find Files" },
      -- 空格+fg：搜索文件内容 (Grep)
      { "<leader>fg", "<cmd>Telescope live_grep<cr>", desc = "Grep Text" },
      -- 空格+fb：搜索已打开的缓冲区
      { "<leader>fb", "<cmd>Telescope buffers<cr>", desc = "Buffers" },
    },
    config = true,
  },

  -- 3. 快捷键提示 (Which-key) - 新手必备
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    init = function()
      vim.o.timeout = true
      vim.o.timeoutlen = 300
    end,
    opts = {}, -- 使用默认配置
  },
}
