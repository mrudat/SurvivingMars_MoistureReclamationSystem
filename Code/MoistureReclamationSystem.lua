local orig_print = print
if Mods.mrudat_TestingMods then
  print = orig_print
else
  print = empty_func
end

local CurrentModId = rawget(_G, 'CurrentModId') or rawget(_G, 'CurrentModId_X')
local CurrentModDef = rawget(_G, 'CurrentModDef') or rawget(_G, 'CurrentModDef_X')
if not CurrentModId then

  -- copied shamelessly from Expanded Cheat Menu
  local Mods, rawset = Mods, rawset
  for id, mod in pairs(Mods) do
    rawset(mod.env, "CurrentModId_X", id)
    rawset(mod.env, "CurrentModDef_X", mod)
  end

  CurrentModId = CurrentModId_X
  CurrentModDef = CurrentModDef_X
end

orig_print("loading", CurrentModId, "-", CurrentModDef.title)

local victim_classes = {
  'Farm',
  'HangingGardens'
}

if InsidePasture then
  victim_classes[#victim_classes + 1] = 'InsidePasture'
end

-- unforbid MoistureVaporator from being built inside.
mrudat_AllowBuildingInDome.forbidden_template_classes.MoistureVaporator = nil

local wrap_method = mrudat_AllowBuildingInDome.wrap_method

-- we could use OnMsg.OnSetWorking, but then we'd need to undo some of the things MoistureVaporator:OnSetWorking does.
wrap_method('MoistureVaporator','OnSetWorking',function(self, orig_func, working)
  local dome = self.parent_dome
  if not dome or dome.open_air then
    if self.mrudat_MoistureReclamationSystem_no_moisture then
      self.mrudat_MoistureReclamationSystem_no_moisture = nil
      vaporator:AttachSign(false, "SignNoWater")
    end
    if self.mrudat_MoistureReclamationSystem_boost then
      self:SetModifier('water_production', 'mrudat_MoistureReclamationSystem_boost', 0, 0)
      self.mrudat_MoistureReclamationSystem_boost = nil
    end
    return orig_func(self, working)
  end

  WaterProducer.OnSetWorking(self, working)

  -- we limit total water production in a different way.
  if self.nearby_vaporators > 0 then
    self:UpdateNearbyVaporatorsCount(-self.nearby_vaporators)
  end
  dome:Notify("mrudat_MoistureReclamationSystem_UpdateMoistureVaporators")
end)

function MoistureVaporator:mrudat_MoistureReclamationSystem_applyBoost()
  local modifier = self:FindModifier('TP Boost Water', 'water_production')
  local amount = 0
  local percent = 100
  if modifier then
    amount = amount - modifier.amount
    percent = percent - modifier.percent
  end
  self:SetModifier('water_production', 'mrudat_MoistureReclamationSystem_boost', amount, percent)
  self.mrudat_MoistureReclamationSystem_boost = true
end

function MoistureVaporator:mrudat_MoistureReclamationSystem_AssignProduction(max_production)
  print("AssignProduction", max_production)
  if not self.working and not self.mrudat_MoistureReclamationSystem_no_moisture then return 0 end
  local water_production = self.water_production
  if max_production == 0 then
    self.mrudat_MoistureReclamationSystem_no_moisture = true
    self:AttachSign(true, "SignNoWater")
  else
    self.mrudat_MoistureReclamationSystem_no_moisture = false
    self:AttachSign(false, "SignNoWater")
  end
  if max_production >= water_production then
    self.water:SetProduction(water_production, 0)
    return water_production
  else
    self.water:SetProduction(max_production, water_production - max_production)
    return max_production
  end
end

function Dome:mrudat_MoistureReclamationSystem_UpdateMoistureVaporators()
  if self.open_air then return end

  local labels = self.labels

  local vaporators = labels.MoistureVaporator
  if not vaporators or #vaporators == 0 then return end

  local total_water_consumption = self.water_consumption

  for _, class in ipairs(victim_classes) do
    local victims = labels[class] or empty_table
    print(class, #victims)
    for _, victim in ipairs(victims) do
      if victim.working then
        total_water_consumption = total_water_consumption + victim.water_consumption
      end
    end
  end

  local max_recovered_water = total_water_consumption // 2
  orig_print("Maximum possible recovered water", max_recovered_water)

  -- TP Boost Water only applies to the great outdoors, we're in a dome, but in an earth-like atmosphere, so output is boosted by 100%
  for _, vaporator in ipairs(vaporators) do
    vaporator:mrudat_MoistureReclamationSystem_applyBoost()
  end

  --table.sort(vaporators, function (a,b) return a.water_production > b.water_production end)
  table.sortby_field_descending(vaporators, 'water_production')

  for _, vaporator in ipairs(vaporators) do
    max_recovered_water = max_recovered_water - vaporator:mrudat_MoistureReclamationSystem_AssignProduction(max_recovered_water)
    vaporator:Notify("UpdateWorking")
  end
end

wrap_method('MoistureVaporator','GetWorkNotPossibleReason', function(self, orig_func)
  if self.mrudat_MoistureReclamationSystem_no_moisture then
    return "NoWater"
  end
  return orig_func(self)
end)

local function watch_water_production(self, orig_func, prop, old_value, new_value)
  orig_func(self, prop, old_value, new_value)

  local dome = self.parent_dome
  if not dome or dome.open_air then return end
  if prop == 'water_production' then
    dome:Notify("mrudat_MoistureReclamationSystem_UpdateMoistureVaporators")
  end
end

wrap_method('MoistureVaporator','OnModifiableValueChanged', watch_water_production)

local function watch_water_consumption(self, orig_func, prop, old_value, new_value)
  orig_func(self, prop, old_value, new_value)

  local dome = self.parent_dome
  if not dome or dome.open_air then return end
  if prop == 'water_consumption' then
    dome:Notify("mrudat_MoistureReclamationSystem_UpdateMoistureVaporators")
  end
end

for _, victim_class in ipairs(victim_classes) do
  wrap_method(victim_class, 'OnModifiableValueChanged', watch_water_consumption)
end

wrap_method('Dome', 'OnModifiableValueChanged', function(self, orig_func, prop, old_value, new_value)
  orig_func(self, prop, old_value, new_value)

  if self.open_air then return end

  if prop == 'water_consumption' then
    self:Notify("mrudat_MoistureReclamationSystem_UpdateMoistureVaporators")
  end
end)

if OpenAirBuilding and OpenAirBuilding.ChangeOpenAirState then
  wrap_method('Dome', 'ChangeOpenAirState', function(self, orig_func, open)
    orig_func(self, open)

    for _, vaporator in ipairs(self.labels.MoistureVaporator or empty_table) do
      -- recalculate neighbour penalty, now that we're running in the open air (or not)
      vaporator:OnSetWorking(vaporator.working)
    end
  end)
end

local function construct_or_demolish(building)
  print("construct_or_demolish", building:GetPos())
  for _, class in ipairs(victim_classes) do
    if building:IsKindOf(class) then
      local dome = building.parent_dome
      if not dome then
        dome = GetDomeAtPoint(building:GetPos())
      end
      if not dome or dome.open_air then return end
      dome:Notify("mrudat_MoistureReclamationSystem_UpdateMoistureVaporators")
    end
  end
end

OnMsg.ConstructionComplete = construct_or_demolish
OnMsg.Demolished = construct_or_demolish

orig_print("loaded", CurrentModId, "-", CurrentModDef.title)
