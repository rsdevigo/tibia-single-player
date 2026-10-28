-- Cast Helper: o bot só executa os .lua da raiz da config, então este arquivo carrega o resto na ordem.
-- O núcleo vem primeiro (define a tabela global `casthelper`, usada pelas abas).
local files = {
  "core",
  "foods",
  "healing",
  "tools",
  "combat",
}

for _, name in ipairs(files) do
  dofile("casthelper/" .. name .. ".lua")
end
