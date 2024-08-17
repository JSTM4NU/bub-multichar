local function GiveStarterItems(source)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    for _, v in pairs(QBCore.Shared.StarterItems) do
        local info = {}
        if v.item == "id_card" then
            info.citizenid = Player.PlayerData.citizenid
            info.firstname = Player.PlayerData.charinfo.firstname
            info.lastname = Player.PlayerData.charinfo.lastname
            info.birthdate = Player.PlayerData.charinfo.birthdate
            info.gender = Player.PlayerData.charinfo.gender
            info.nationality = Player.PlayerData.charinfo.nationality
        elseif v.item == "driver_license" then
            info.firstname = Player.PlayerData.charinfo.firstname
            info.lastname = Player.PlayerData.charinfo.lastname
            info.birthdate = Player.PlayerData.charinfo.birthdate
            info.type = "Class C Driver License"
        end
        Player.Functions.AddItem(v.item, v.amount, false, info)
    end
end

local function fetchPlayerSkin(citizenId)
  return MySQL.single.await('SELECT * FROM playerskins WHERE citizenid = ? AND active = 1', {citizenId})
end

local function fetchAllPlayerEntities(license2, license)
  local chars = {}
  local result = MySQL.query.await('SELECT * FROM players WHERE license = ? OR license = ?', {license, license2})

  for i = 1, #result do
    local charinfo = json.decode(result[i].charinfo)
    chars[i] = {
      citizenid = '',
      name = '',
      cid = 0,
      metadata = {}
    }
    chars[i].citizenid = result[i].citizenid
    chars[i].name = charinfo.firstname .. ' ' .. charinfo.lastname
    chars[i].cid = charinfo.cid
    chars[i].metadata = {
      { key = "job", value = json.decode(result[i].job).label .. ' (' .. json.decode(result[i].job).grade.name .. ')' },
      { key = "nationality", value = charinfo.nationality },
      { key = "bank", value = lib.math.groupdigits(json.decode(result[i].money).bank) },
      { key = "cash", value = lib.math.groupdigits(json.decode(result[i].money).cash) },
      { key = "birthdate", value = charinfo.birthdate },
      { key = "gender", value = charinfo.gender == 0 and 'Male' or 'Female' },
    }
  end

  return chars
end

lib.callback.register('bub-multichar:server:getCharacters', function(source)
  local license2, license = GetPlayerIdentifierByType(source, 'license2'), GetPlayerIdentifierByType(source, 'license')
  local chars = fetchAllPlayerEntities(license2, license)
  local allowedAmount = 0
  local sortedChars = {}
  if next(Config.PlayersNumberOfCharacters) then
        for _, v in pairs(Config.PlayersNumberOfCharacters) do
            if license2 == v.license2 then
                allowedAmount = v.allowedAmount
                break
            else
                allowedAmount = Config.DefaultNumberOfCharacters
            end
        end
    else
        allowedAmount = Config.DefaultNumberOfCharacters
    end
  for i = 1, #chars do
    local char = chars[i]
    sortedChars[char.cid] = char
  end
  print(allowedAmount)
  return sortedChars, allowedAmount
end)

lib.callback.register('bub-multichar:server:getPreviewPedData', function(_, citizenId)
  local ped = fetchPlayerSkin(citizenId)
  if not ped then return end

  return ped.skin, ped.model and joaat(ped.model)
end)

lib.callback.register('bub-multichar:server:loadCharacter', function(source, citizenId)
  local success = exports.qbx_core:Login(source, citizenId)
  if not success then return end

  exports.qbx_core:SetPlayerBucket(source, 0)
  lib.print.info(('%s (Citizen ID: %s) has successfully loaded!'):format(GetPlayerName(source), citizenId))
end)

---@param data unknown
---@return table? newData
lib.callback.register('bub-multichar:server:createCharacter', function(source, data)
  local newData = {}
  newData.charinfo = data

  local success = exports.qbx_core:Login(source, nil, newData)
  if not success then return end

  GiveStarterItems(source)
  exports.qbx_core:SetPlayerBucket(source, 0)

  lib.print.info(('%s has created a character'):format(GetPlayerName(source)))
  return newData
end)

lib.callback.register('bub-multichar:server:setCharBucket', function(source)
  exports.qbx_core:SetPlayerBucket(source, source)
  assert(GetPlayerRoutingBucket(source) == source, 'Multicharacter bucket not set.')
end)

RegisterNetEvent('bub-multichar:server:deleteCharacter', function(citizenId)
  local src = source
  exports.qbx_core:DeleteCharacter(citizenId)
  exports.qbx_core:Notify(src, 'Successfully deleted your character', 'success')
end)
