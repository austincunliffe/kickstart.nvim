vim.bo.expandtab = true
vim.bo.tabstop = 4
vim.bo.softtabstop = 4
vim.bo.shiftwidth = 4

local ok, jdtls = pcall(require, 'jdtls')
if not ok then
  return
end

local root_dir = require('jdtls.setup').find_root { '.git', 'mvnw', 'gradlew', 'pom.xml', 'build.gradle', 'settings.gradle' }
if not root_dir then
  return
end

local mason = vim.fn.stdpath 'data' .. '/mason/packages'
local jdtls_home = mason .. '/jdtls'
local launcher = vim.fn.glob(jdtls_home .. '/plugins/org.eclipse.equinox.launcher_*.jar')
local lombok = jdtls_home .. '/lombok.jar'

local uname = (vim.uv or vim.loop).os_uname()
local os_config
if vim.fn.has 'mac' == 1 then
  os_config = uname.machine == 'arm64' and 'config_mac_arm' or 'config_mac'
elseif vim.fn.has 'unix' == 1 then
  os_config = uname.machine == 'aarch64' and 'config_linux_arm' or 'config_linux'
else
  os_config = 'config_win'
end

-- Isolated workspace per project so jdtls doesn't cross-contaminate indexes
local workspace = vim.fn.stdpath 'data' .. '/jdtls-workspace/' .. vim.fn.fnamemodify(root_dir, ':p:h:t')

local bundles = {}
vim.list_extend(bundles, vim.split(vim.fn.glob(mason .. '/java-debug-adapter/extension/server/com.microsoft.java.debug.plugin-*.jar', true), '\n'))
vim.list_extend(bundles, vim.split(vim.fn.glob(mason .. '/java-test/extension/server/*.jar', true), '\n'))

jdtls.start_or_attach {
  cmd = {
    'java',
    '-Declipse.application=org.eclipse.jdt.ls.core.id1',
    '-Dosgi.bundles.defaultStartLevel=4',
    '-Declipse.product=org.eclipse.jdt.ls.core.product',
    '-Dlog.protocol=true',
    '-Dlog.level=ALL',
    '-Xmx1g',
    '--add-modules=ALL-SYSTEM',
    '--add-opens',
    'java.base/java.util=ALL-UNNAMED',
    '--add-opens',
    'java.base/java.lang=ALL-UNNAMED',
    '-javaagent:' .. lombok, -- enables Lombok annotation processing (fixes false "blank final field" errors)
    '-jar',
    launcher,
    '-configuration',
    jdtls_home .. '/' .. os_config,
    '-data',
    workspace,
  },
  root_dir = root_dir,
  capabilities = require('blink.cmp').get_lsp_capabilities(),
  init_options = { bundles = bundles },
  settings = {
    java = {
      -- Add JDK 25 here when the upgrade lands: { name = 'JavaSE-25', path = '<jdk25-home>' }
      configuration = { runtimes = {} },
      signatureHelp = { enabled = true },
      contentProvider = { preferred = 'fernflower' },
    },
  },
  on_attach = function(_, bufnr)
    local map = function(keys, fn, desc)
      vim.keymap.set('n', keys, fn, { buffer = bufnr, desc = 'Java: ' .. desc })
    end
    map('<leader>Jo', jdtls.organize_imports, '[O]rganize Imports')
    map('<leader>Jv', jdtls.extract_variable, 'Extract [V]ariable')
    map('<leader>Jc', jdtls.extract_constant, 'Extract [C]onstant')
    map('<leader>Jt', jdtls.test_nearest_method, '[T]est Nearest Method')
    map('<leader>JT', jdtls.test_class, '[T]est Class')
    vim.keymap.set('v', '<leader>Jm', function()
      jdtls.extract_method(true)
    end, { buffer = bufnr, desc = 'Java: Extract [M]ethod' })
  end,
}
