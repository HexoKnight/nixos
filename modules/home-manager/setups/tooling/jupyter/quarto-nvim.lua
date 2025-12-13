require('otter')

local quarto = require('quarto')
quarto.setup({
    lspFeatures = {
        languages = { "python" },
        chunks = "all",
    },
    codeRunner = {
        enabled = true,
        default_method = "molten",
    },
})

local runner = require("quarto.runner")
vim.keymap.set("n", "<localleader>rc", runner.run_cell,  { desc = "run cell", silent = true })
vim.keymap.set("n", "<localleader>rk", runner.run_above, { desc = "run cell and above", silent = true })
vim.keymap.set("n", "<localleader>rj", runner.run_below, { desc = "run cell and below", silent = true })
vim.keymap.set("n", "<localleader>ra", runner.run_all,   { desc = "run all cells", silent = true })
vim.keymap.set("n", "<localleader>rl", runner.run_line,  { desc = "run line", silent = true })
vim.keymap.set("v", "<localleader>r",  runner.run_range, { desc = "run visual range", silent = true })
vim.keymap.set("n", "<localleader>rA", function()
    runner.run_all(true)
end, { desc = "run all cells of all languages", silent = true })

vim.api.nvim_create_autocmd("FileType", {
    pattern = "markdown",
    callback = function()
        if vim.api.nvim_buf_get_name(0):match(".ipynb$") then
            quarto.activate()
            vim.cmd[[MoltenInit]]
        end
    end,
})
