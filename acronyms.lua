--[[
This filter facilitates the use of acronyms in markdown.  It
1. Expands the acronym on first use like this: Local Area Network (LAN).
2. Allows "+LANs" to be plurl and stil work.
3. Maintains a list of acronyms used so that "\printacronyms" will output
   only the acronyms used in the document.

acronyms:
  LAN: Local Area Network
  WAN: Wide Area Network

Is this plugged into the +LAN or +WAN port of the firewall?
]]

local logging = require 'logging'

local yaml_key = "acronyms"
local acronyms = {}
local used = {}
local plural_es = {}

local function deepcopy(o, seen)
  seen = seen or {}
  if o == nil then return nil end
  if seen[o] then return seen[o] end
  local no
  if type(o) == 'table' then
    no = {}
    seen[o] = no
    for k, v in next, o, nil do
      no[deepcopy(k, seen)] = deepcopy(v, seen)
    end
    setmetatable(no, deepcopy(getmetatable(o), seen))
  else
    no = o
  end
  return no
end

local function read_meta(m)
  if m[yaml_key] then -- if nil then don't bother
    for k,v in pairs(m[yaml_key]) do
      logging.info("Found acronym 	"..k.." 	-> "..pandoc.utils.stringify(v))
      acronyms[k] = v
    end
  end
end

function is_used(k)
  if used[k] == nil then
    return false
  end
  return true
end

function mark_used(k)
  used[k] = true
end

function get_values(k, plural)
  logging.info("plurl: "..tostring(plurl).." used: "..tostring(is_used(k)))
  if is_used(k) then
    local r = {pandoc.Str(k)}
    if plural then
      table.insert(r, pandoc.Str("s"))
    end
    return r
  else
    local r = deepcopy(acronyms[k])
    if plural then
      table.insert(r, pandoc.Str("s"))
    end
    r = {pandoc.Emph(r)}
    table.insert(r, pandoc.Space())
    table.insert(r, pandoc.Str("("))
    table.insert(r, pandoc.Str(k))
    if plural then -- Not everyone may want this
      table.insert(r, pandoc.Str("s"))
    end
    table.insert(r, pandoc.Str(")"))

    mark_used(k)
    return r
  end
end

function escape_pattern(s)
  return string.gsub(s, "-", "%%-")
end

function replace_str(elem)
  if string.sub(elem.text, 1, 1) ~= "+" then
    return elem
  end

  logging.info("TESTING: "..elem.text)

  for k, v in pairs(acronyms) do
    logging.info("  "..k.."s")

    -- The acronym is by itself, but plural
    if elem.text == "+"..k.."s" then
      return get_values(k, true)
    end

    logging.info("  "..k)
    -- The acronym is by itself.  This is pretty easy
    if elem.text == "+"..k then
      return get_values(k, false)
    end

    logging.info("  "..k..". (punct)")
    -- No parenthisis
    --   Find returns int for start and end then strings for each capture group
    --   We capture the content before the abbreviation and after in capture groups
    --   The substitution will be a tree of notes, so we need to add before and after
    --   to the table returned by deepcopy.
    local s, e, pl, after = string.find(elem.text, "^+"..escape_pattern(k).."(s?)%f[^%w_](.*)")
    logging.info("  s: "..tostring(s))
    if s ~= nil then
      logging.info("  e: "..tostring(e))
      logging.info("  pl: "..pl)
      logging.info("  after: "..after)

      local values = get_values(k, pl ~= "")

      if after ~= "" then
        table.insert(values,pandoc.Str(after))
      end
      return values
    end
  end

  -- Could not match acronym, leave the element untouched
  return elem
end

function key_set(t)
    local keys = {}
    for k, v in pairs(t) do
        table.insert(keys, k)
    end
    return keys
end

function toDef(key)
  local block = pandoc.Plain(acronyms[key])
  return {{pandoc.Str(key)}, {block}}
end

function generate_acronyms()
  local keys = key_set(acronyms)
  table.sort(keys)
  local defitems = {}
  for i,key in ipairs(keys) do
    if is_used(key) then
      table.insert(defitems, toDef(key))
    end
  end

  return pandoc.DefinitionList(defitems)
end

function generate_acronyms_typst()
  local blocks = {}

  -- one blank space ensures we start a new paragraph (block)
  local pre = pandoc.RawBlock('typst', "\
#{\
set terms(separator:[ -- ])\
set par(leading: .90em)\
[")
  local post = pandoc.RawBlock('typst', "]}\n")

  table.insert(blocks, pre)

  local keys = key_set(acronyms)
  table.sort(keys)
  for _,acronym in ipairs(keys) do
    if is_used(acronym) then
      local desc = pandoc.utils.stringify(acronyms[acronym])
      local typ = string.format("/ %s: %s\n", acronym, desc)
      local term = pandoc.RawBlock('typst', typ)
      table.insert(blocks, term)
    end
  end

  table.insert(blocks, post)

  return blocks
end

function print_acronyms(elem)
  local cmd = elem.text
  logging.info("cmd: "..cmd)
  if elem.format:match 'tex' and cmd:match('^\\printacronyms$') then
    if FORMAT == 'typst' then
      return {elem, table.unpack(generate_acronyms_typst())}
    else
      return {elem, generate_acronyms()}
    end
  else
    return elem
  end
end

function Pandoc(doc)
  -- Read acronyms from Meta
  read_meta(doc.meta)

  -- First replace all of the acronyms, tracking used
  doc = doc:walk({
    Str = replace_str,
  })

  -- Now that we know which are used, print them where the user wants
  return doc:walk({
    RawBlock = print_acronyms,
  })
end
