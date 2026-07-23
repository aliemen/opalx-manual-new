function Div(div)
  if not FORMAT:match("latex") then
    return nil
  end

  local label = nil
  if div.classes:includes("feature-opalx") then
    label = "OPALX"
  elseif div.classes:includes("feature-opal") then
    label = "OPAL"
  end

  if label then
    table.insert(div.content, 1, pandoc.Para({pandoc.Strong(label)}))
    return div
  end
end
