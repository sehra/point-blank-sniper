PointBlankSniperDataItemKeyLoaderMixin = {}

function PointBlankSniperDataItemKeyLoaderMixin:StartLoading()
  PointBlankSniper.Utilities.Message(POINT_BLANK_SNIPER_L_ITEM_INFO_DB_CREATING)

  self.index = 1
  self.source = POINT_BLANK_SNIPER_KNOWN_COMMODITY_KEYS
  self.namePairs = {}
  self.waiting = #self.source.itemKeyStrings
  self.elapsed = 0
  POINT_BLANK_SNIPER_ITEM_CACHE.updateInProgress = true

  self:ConvertToPartialPairs()
  self:SetScript("OnUpdate", self.OnUpdate)
end

function PointBlankSniperDataItemKeyLoaderMixin:ConvertToPartialPairs()
  local seen = {}
  for _, keyString in ipairs(self.source.itemKeyStrings) do
    local itemKey = PointBlankSniper.Utilities.CleanItemKey(PointBlankSniper.Utilities.ItemKeyStringToItemKey(keyString))
    local newKeyString = Auctionator.Utilities.ItemKeyString(itemKey)
    if seen[newKeyString] == nil then
      seen[newKeyString] = true
      table.insert(self.namePairs, {
        name = "",
        itemKey = itemKey,
      })
    end
  end
end

function PointBlankSniperDataItemKeyLoaderMixin:ProcessCompleteNamePairs()
  table.sort(self.namePairs, function(a, b)
    return a.name < b.name
  end)
  local names, itemKeyStrings = {}, {}
  for _, nameAndKey in ipairs(self.namePairs) do
    local itemKeyString = Auctionator.Utilities.ItemKeyString(nameAndKey.itemKey)
    if nameAndKey.name ~= "" then
      table.insert(names, nameAndKey.name)
      table.insert(itemKeyStrings, itemKeyString)
      POINT_BLANK_SNIPER_ITEM_CACHE.keysSeen[itemKeyString] = true
    else
      table.insert(POINT_BLANK_SNIPER_ITEM_CACHE.missing, itemKeyString)
      PointBlankSniper.Utilities.Message(POINT_BLANK_SNIPER_L_ITEM_INFO_DB_MISSING_ID_X:format(itemKeyString))
    end
  end
  POINT_BLANK_SNIPER_ITEM_CACHE.orderedKeys.itemKeyStrings = itemKeyStrings
  POINT_BLANK_SNIPER_ITEM_CACHE.orderedKeys.names = names
  POINT_BLANK_SNIPER_ITEM_CACHE.orderedKeys.timestamp = time()
  POINT_BLANK_SNIPER_ITEM_CACHE.updateInProgress = true
end

function PointBlankSniperDataItemKeyLoaderMixin:ProcessNextBatch()
  local leftInBatch = 500
  while self.index <= #self.namePairs and leftInBatch > 0 do
    local localIndex = self.index
    PointBlankSniper.ItemKeyCache.CleanGetItemKeyInfo(self.namePairs[self.index].itemKey, function(itemKeyInfo)
      self.namePairs[localIndex].name = PointBlankSniper.Utilities.CleanSearchString(itemKeyInfo.itemName)
      self.waiting = self.waiting - 1
    end)

    self.index = self.index + 1
    leftInBatch = leftInBatch - 1
  end
end

function PointBlankSniperDataItemKeyLoaderMixin:OnUpdate(elapsed)
  if self.index <= #self.namePairs then
    self:ProcessNextBatch()
  else
    self.elapsed = self.elapsed + elapsed
  end
  if self.waiting <= 0 or self.elapsed > 30 then
    self.source = nil
    self:SetScript("OnUpdate", nil)
    self:ProcessCompleteNamePairs()
    if #POINT_BLANK_SNIPER_ITEM_CACHE.missing > 0 then
      PointBlankSniper.Utilities.Message(POINT_BLANK_SNIPER_L_ITEM_INFO_DB_MISSING)
    else
      PointBlankSniper.Utilities.Message(POINT_BLANK_SNIPER_L_ITEM_INFO_DB_CREATED)
    end
  end
end