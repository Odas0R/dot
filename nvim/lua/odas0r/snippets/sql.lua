local ls = require("luasnip")
local s = ls.snippet
local i = ls.insert_node
local f = ls.function_node
local fmt = require("luasnip.extras.fmt").fmt

local function system_uuid()
  local uuid = vim.trim(vim.fn.system("uuidgen"))
  if uuid == "" then
    return "00000000-0000-0000-0000-000000000000"
  end
  return string.lower(uuid)
end

return {
  s("uuid", {
    f(function()
      return system_uuid()
    end),
  }),

  s(
    "sel",
    fmt(
      [[
SELECT {}
FROM {}
WHERE {};]],
      { i(1, "*"), i(2, "table_name"), i(0, "condition") }
    )
  ),

  s(
    "ins",
    fmt(
      [[
INSERT INTO {} ({})
VALUES ({})
RETURNING *;]],
      { i(1, "table_name"), i(2, "columns"), i(0, "values") }
    )
  ),

  s(
    "upd",
    fmt(
      [[
UPDATE {}
SET {} = {}
WHERE {}
RETURNING *;]],
      { i(1, "table_name"), i(2, "column"), i(3, "value"), i(0, "condition") }
    )
  ),

  s(
    "del",
    fmt(
      [[
DELETE FROM {}
WHERE {}
RETURNING *;]],
      { i(1, "table_name"), i(0, "condition") }
    )
  ),

  s(
    "cte",
    fmt(
      [[
WITH {} AS (
  {}
)
SELECT *
FROM {};]],
      { i(1, "cte_name"), i(2, "SELECT ..."), i(0, "cte_name") }
    )
  ),

  s(
    "tx",
    fmt(
      [[
BEGIN;

{}

COMMIT;]],
      { i(0, "-- statements") }
    )
  ),

  s(
    "table",
    fmt(
      [[
CREATE TABLE {} (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  {},
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);]],
      { i(1, "table_name"), i(0, "name text NOT NULL") }
    )
  ),

  s(
    "idx",
    fmt(
      [[
CREATE INDEX {} ON {} ({});]],
      { i(1, "idx_table_column"), i(2, "table_name"), i(0, "column") }
    )
  ),

  s(
    "uidx",
    fmt(
      [[
CREATE UNIQUE INDEX {} ON {} ({});]],
      { i(1, "uidx_table_column"), i(2, "table_name"), i(0, "column") }
    )
  ),

  s(
    "fk",
    fmt(
      [[
ALTER TABLE {}
ADD CONSTRAINT {}
FOREIGN KEY ({}) REFERENCES {}({});]],
      { i(1, "table_name"), i(2, "fk_table_ref"), i(3, "ref_id"), i(4, "ref_table"), i(0, "id") }
    )
  ),

  s(
    "upsert",
    fmt(
      [[
INSERT INTO {} ({})
VALUES ({})
ON CONFLICT ({}) DO UPDATE
SET {} = EXCLUDED.{}
RETURNING *;]],
      { i(1, "table_name"), i(2, "columns"), i(3, "values"), i(4, "unique_column"), i(5, "column"), i(6, "column") }
    )
  ),

  s(
    "explain",
    fmt(
      [[
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
{}]],
      { i(0, "SELECT ...;") }
    )
  ),
}
