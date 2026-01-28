return {

  {
    "nvim-lua/plenary.nvim",
    name = "plenary",
    lazy = true,
  },

  {
    "eandrju/cellular-automaton.nvim",
    cmd = "CellularAutomaton",
    dependencies = { "plenary" },
  },
}
