return {
  -- 1. 语法高亮引擎 (Treesitter)
  -- 它是 Neovim 的核心，能把代码解析成语法树，让高亮更精准
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate", -- 安装后自动更新解析器
    event = { "BufReadPost", "BufNewFile" }, -- 打开文件时才加载，加快启动
    config = function() 
      require("nvim-treesitter").setup({
        -- 自动安装这些语言的解析器 (你可以根据需要添加，比如 "python", "go", "java")
        ensure_installed = { "bash", "c", "html", "lua", "luadoc", "markdown", "vim", "vimdoc", "query", "javascript", "typescript" },
        
        -- 自动安装缺失的解析器
        auto_install = true,
        
        -- 启用高亮
        highlight = {
          enable = true,
          additional_vim_regex_highlighting = false,
        },
        
        -- 启用基于缩进的代码折叠
        indent = { enable = true },
      })
    end
  },

  -- 2. Git 状态提示 (Gitsigns)
  -- 在行号左边显示新增(绿)、修改(蓝)、删除(红)的竖条
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {}, -- 使用默认配置
  },
}
