return {
  root_markers = { "tsconfig.json", "jsconfig.json" },
  settings = {
    typescript = {
      inlayHints = {
        parameterNames = { enabled = "literals" },
        parameterTypes = { enabled = true },
        variableTypes = { enabled = true },
        propertyDeclarationTypes = { enabled = true },
        functionLikeReturnTypes = { enabled = true },
        enumMemberValues = { enabled = true },
      },
      suggest = { completeFunctionCalls = true },
    },
    vtsls = {
      experimental = {
        completion = { enableServerSideFuzzyMatch = true },
      },
    },
  },
}
