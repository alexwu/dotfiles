local ls = require "luasnip"
local snippet = ls.snippet
local text_node = ls.text_node
local insert_node = ls.insert_node
local function_node = ls.function_node
local types = require "luasnip.util.types"

ls.config.set_config {
  history = true,
  updateevents = "TextChanged,TextChangedI",
  delete_check_events = "InsertLeave",
  region_check_events = "InsertEnter",
  ext_opts = {
    [types.choiceNode] = {
      active = {
        virt_text = { { "●", "Comment" } },
      },
    },
    [types.insertNode] = {
      active = {
        virt_text = { { "●", "" } },
      },
    },
  },
  ext_base_prio = 300,
  ext_prio_increase = 1,
  enable_autosnippets = false,
}

local function copy(args)
  return args[1]
end

ls.snippets = {
  all = {},
  typescript = {
    snippet("() =>", {
      text_node { "(" },
      insert_node(1),
      text_node { ") => " },
      insert_node(0),
    }),
    snippet("() => { }", {
      text_node { "(" },
      insert_node(1),
      text_node { ") => { " },
      insert_node(0),
      text_node { "}" },
    }),
    snippet("describe(\"\", () => { }", {
      text_node { "describe(" },
      insert_node(1),
      text_node { ") => { " },
      insert_node(0),
      text_node { "}" },
    }),
  },
  lua = {
    snippet("function", {
      function_node(copy, 2),
      text_node { "function " },
      insert_node(1),
      text_node "(",
      insert_node(2, ""),
      text_node { ")", "\t" },
      insert_node(0),
      text_node { "", "end" },
    }),
  },
}

-- autotriggered snippets have to be defined in a separate table, luasnip.autosnippets.
ls.autosnippets = {
  all = {},
}

ls.filetype_extend("lua", { "c" })
ls.filetype_extend("tsx", { "ts" })
ls.filetype_extend("cpp", { "c" })

require("luasnip.loaders.from_vscode").load {}
