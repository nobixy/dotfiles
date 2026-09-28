return {
  "mfussenegger/nvim-dap",
  dependencies = {
    "rcarriga/nvim-dap-ui",
    "nvim-neotest/nvim-nio",
  },
  keys = {
    { "<leader>db", function() require("dap").toggle_breakpoint() end, desc = "Toggle breakpoint" },
    { "<leader>dc", function() require("dap").continue() end, desc = "Continue" },
    { "<leader>di", function() require("dap").step_into() end, desc = "Step into" },
    { "<leader>do", function() require("dap").step_over() end, desc = "Step over" },
    { "<leader>dO", function() require("dap").step_out() end, desc = "Step out" },
    { "<leader>dr", function() require("dap").repl.toggle() end, desc = "Toggle REPL" },
    { "<leader>du", function() require("dapui").toggle() end, desc = "Toggle DAP UI" },
  },
  config = function()
    local dap = require("dap")
    local dapui = require("dapui")

    dapui.setup()

    dap.listeners.after.event_initialized["dapui_config"] = function()
      dapui.open()
    end
    dap.listeners.before.event_terminated["dapui_config"] = function()
      dapui.close()
    end
    dap.listeners.before.event_exited["dapui_config"] = function()
      dapui.close()
    end

    -- Catppuccin Nerd Font Breakpoint Signs
    vim.fn.sign_define("DapBreakpoint", { text = "", texthl = "DiagnosticError", linehl = "", numhl = "" })
    vim.fn.sign_define("DapBreakpointCondition", { text = "", texthl = "DiagnosticWarn", linehl = "", numhl = "" })
    vim.fn.sign_define("DapBreakpointRejected", { text = "", texthl = "DiagnosticWarn", linehl = "", numhl = "" })
    vim.fn.sign_define("DapLogPoint", { text = "", texthl = "DiagnosticInfo", linehl = "", numhl = "" })
    vim.fn.sign_define("DapStopped", { text = "", texthl = "DiagnosticOk", linehl = "DapStoppedLine", numhl = "" })

    -- 1. C / C++ / Rust: gdb's built-in DAP server (gdb 14+), nothing extra to
    -- install. Compile with -g so gdb can map the program back to source lines.
    dap.adapters.gdb = {
      type = "executable",
      command = "gdb",
      args = { "--interpreter=dap", "--eval-command", "set print pretty on" },
    }

    local gdb_config = {
      {
        name = "Launch executable",
        type = "gdb",
        request = "launch",
        program = function()
          return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
        end,
        cwd = "${workspaceFolder}",
        stopAtBeginningOfMainSubprogram = false,
      },
    }
    dap.configurations.c = gdb_config
    dap.configurations.cpp = gdb_config
    dap.configurations.rust = gdb_config

    -- 2. Python (debugpy, installed by Mason)
    local debugpy_python = vim.fn.stdpath("data") .. "/mason/packages/debugpy/venv/bin/python"
    dap.adapters.python = function(cb, config)
      if config.request == "attach" then
        local port = (config.connect or config).port
        local host = (config.connect or config).host or "127.0.0.1"
        cb({
          type = "server",
          port = assert(port, "`connect.port` is required for a python `attach` configuration"),
          host = host,
          options = { source_filetype = "python" },
        })
      else
        local cmd = vim.fn.filereadable(debugpy_python) == 1 and debugpy_python or "python3"
        cb({
          type = "executable",
          command = cmd,
          args = { "-m", "debugpy.adapter" },
          options = { source_filetype = "python" },
        })
      end
    end

    dap.configurations.python = {
      {
        type = "python",
        request = "launch",
        name = "Launch file",
        program = "${file}",
        pythonPath = function()
          local venv = vim.env.VIRTUAL_ENV
          if venv and vim.fn.filereadable(venv .. "/bin/python") == 1 then
            return venv .. "/bin/python"
          end
          return "python3"
        end,
      },
    }

    -- 3. Go (delve, installed by Mason)
    local delve_path = vim.fn.exepath("dlv")
    if delve_path == "" then
      delve_path = vim.fn.stdpath("data") .. "/mason/bin/dlv"
    end

    dap.adapters.delve = {
      type = "server",
      port = "${port}",
      executable = {
        command = delve_path,
        args = { "dap", "-l", "127.0.0.1:${port}" },
      },
    }

    dap.configurations.go = {
      {
        type = "delve",
        name = "Debug file",
        request = "launch",
        program = "${file}",
      },
      {
        type = "delve",
        name = "Debug test",
        request = "launch",
        mode = "test",
        program = "${file}",
      },
      {
        type = "delve",
        name = "Debug package",
        request = "launch",
        program = "./${relativeFileDirname}",
      },
    }
  end,
}
