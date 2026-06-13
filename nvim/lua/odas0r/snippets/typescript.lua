local ls = require("luasnip")
local s = ls.snippet
local i = ls.insert_node
local rep = require("luasnip.extras").rep
local fmt = require("luasnip.extras.fmt").fmt

local function afmt(body, nodes)
  return fmt(body, nodes, { delimiters = "^~" })
end

return {
  s(
    "imp",
    afmt(
      [[import { ^imports~ } from "^module~";]],
      { imports = i(1), module = i(2, "module") }
    )
  ),
  s(
    "imd",
    afmt(
      [[import ^name~ from "^module~";]],
      { name = i(1, "name"), module = i(2, "module") }
    )
  ),
  s(
    "ima",
    afmt(
      [[import * as ^name~ from "^module~";]],
      { name = i(1, "name"), module = i(2, "module") }
    )
  ),
  s("exp", afmt([[export { ^exports~ };]], { exports = i(1) })),

  s(
    "type",
    afmt(
      [[
type ^Name~ = {
  ^fields~
};]],
      { Name = i(1, "Name"), fields = i(0) }
    )
  ),

  s(
    "interface",
    afmt(
      [[
interface ^Name~ {
  ^fields~
}]],
      { Name = i(1, "Name"), fields = i(0) }
    )
  ),

  s(
    "enum",
    afmt(
      [[
enum ^Name~ {
  ^Member~ = "^value~",
}]],
      { Name = i(1, "Name"), Member = i(2, "Member"), value = i(3, "value") }
    )
  ),

  s(
    "fn",
    afmt(
      [[
function ^name~(^args~): ^return_type~ {
  ^body~
}]],
      {
        name = i(1, "name"),
        args = i(2),
        return_type = i(3, "void"),
        body = i(0),
      }
    )
  ),

  s(
    "afn",
    afmt(
      [[
async function ^name~(^args~): ^return_type~ {
  ^body~
}]],
      {
        name = i(1, "name"),
        args = i(2),
        return_type = i(3, "Promise^void~"),
        body = i(0),
      }
    )
  ),

  s(
    "arrow",
    afmt(
      [[
const ^name~ = (^args~): ^return_type~ => {
  ^body~
};]],
      {
        name = i(1, "name"),
        args = i(2),
        return_type = i(3, "void"),
        body = i(0),
      }
    )
  ),

  s(
    "aarr",
    afmt(
      [[
const ^name~ = async (^args~): ^return_type~ => {
  ^body~
};]],
      {
        name = i(1, "name"),
        args = i(2),
        return_type = i(3, "Promise^void~"),
        body = i(0),
      }
    )
  ),

  s(
    "clg",
    afmt(
      [[console.log("^label~", ^value~);]],
      { label = i(1, "label"), value = i(2, "value") }
    )
  ),
  s(
    "cerr",
    afmt(
      [[console.error("^label~", ^error~);]],
      { label = i(1, "error"), error = i(2, "error") }
    )
  ),

  s(
    "try",
    afmt(
      [[
try {
  ^body~
} catch (^error~) {
  ^handler~
}]],
      {
        body = i(1),
        error = i(2, "error"),
        handler = i(0, "console.error(error);"),
      }
    )
  ),

  s(
    "forof",
    afmt(
      [[
for (const ^item~ of ^items~) {
  ^body~
}]],
      { item = i(1, "item"), items = i(2, "items"), body = i(0) }
    )
  ),

  s(
    "map",
    afmt(
      [[^items~.map((^item~) => ^body~)]],
      { items = i(1, "items"), item = i(2, "item"), body = i(0, "item") }
    )
  ),

  s(
    "filter",
    afmt(
      [[^items~.filter((^item~) => ^predicate~)]],
      {
        items = i(1, "items"),
        item = i(2, "item"),
        predicate = i(0, "Boolean(item)"),
      }
    )
  ),

  s(
    "reduce",
    afmt(
      [[^items~.reduce((^acc~, ^item~) => {
  ^body~
  return ^acc_return~;
}, ^initial~)]],
      {
        items = i(1, "items"),
        acc = i(2, "acc"),
        item = i(3, "item"),
        body = i(4),
        acc_return = rep(2),
        initial = i(0, "initial"),
      }
    )
  ),

  s(
    "fetch",
    afmt(
      [[
const response = await fetch("^url~", {
  method: "^method~",
  headers: {
    "Content-Type": "application/json",
  },
  body: JSON.stringify(^body~),
});

if (!response.ok) {
  throw new Error(`Request failed: ${response.status}`);
}

const ^data~ = await response.json();]],
      {
        url = i(1, "/api"),
        method = i(2, "POST"),
        body = i(3, "payload"),
        data = i(0, "data"),
      }
    )
  ),

  s(
    "test",
    afmt(
      [[
test("^name~", () => {
  ^body~
});]],
      { name = i(1, "does something"), body = i(0) }
    )
  ),

  s(
    "atest",
    afmt(
      [[
test("^name~", async () => {
  ^body~
});]],
      { name = i(1, "does something"), body = i(0) }
    )
  ),

  s(
    "describe",
    afmt(
      [[
describe("^subject~", () => {
  test("^name~", () => {
    ^body~
  });
});]],
      { subject = i(1, "subject"), name = i(2, "does something"), body = i(0) }
    )
  ),

  s(
    "expect",
    afmt(
      [[expect(^actual~).toEqual(^expected~);]],
      { actual = i(1, "actual"), expected = i(0, "expected") }
    )
  ),
  s("todo", afmt([[test.todo("^name~");]], { name = i(1, "does something") })),
}
