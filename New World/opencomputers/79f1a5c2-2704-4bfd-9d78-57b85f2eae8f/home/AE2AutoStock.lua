local component = require("component")
local fs = require("filesystem")
local serialization = require("serialization")
local meController = component.proxy(component.me_controller.address)
local gpu = component.gpu
gpu.setResolution(160,50)
local gui = require("gui")
local event = require("event")

gui.checkVersion(2,5)

local prgName = "Applied Energistics 2 Auto Stock"
local version = "v1.3"
local lines = {}
local items = {}
local craftTasks = {}
local maxCpuUsage = 1
local currentCpuUsage = 0

local function LoadConfig()
	local file,err = io.open("config.cfg", "r")
	if err == nil then
		local data = file:read("*n")
		maxCpuUsage = tonumber(data)
		gui.setText(mainGui, CpuMaxUsage, maxCpuUsage .. "")
		file:close()
	end
end

local function SaveConfig()
	local file,err = io.open("config.cfg", "w")
	file:write(maxCpuUsage)
	file:close()
end

local function LoadItems()
	local file,err = io.open("items.cfg", "r")
	if err == nil then
		local data = file:read("*a")
		file:close()

		local itemsToLoad = serialization.unserialize(data)
		items = {}
		for index = 1, #itemsToLoad do
			items[index] = itemsToLoad[index]
		end

		for index = 1, #items do
			items[index]["Name"] = ""
			items[index]["CurrentCraftAmount"] = 0
			items[index]["CurrentValue"] = 0
			items[index]["Message"] = ""
		end
	end
end

local function SaveItems()
	local file,err = io.open("items.cfg", "w")
	local itemsToSave = {}
	for index = 1, #items do
		itemsToSave[index] = {}
		itemsToSave[index]["rawItemName"] = items[index]["rawItemName"]
		itemsToSave[index]["rawItemDamage"] = items[index]["rawItemDamage"]
		itemsToSave[index]["Setpoint"] = items[index]["Setpoint"]
		itemsToSave[index]["CraftAmount"] = items[index]["CraftAmount"]
	end
	file:write(serialization.serialize(itemsToSave))
	file:close()

	LoadItems()
end

mainGui = gui.newGui(1, 2, 159, 48, true)

local function DrawHeaders()
	Header_Name = gui.newLabel(mainGui, 4, 2, "Name", 0xc0c0c0, 0x0, 30)
	Header_Current = gui.newLabel(mainGui, 35, 2, "Current (Setpoint)", 0xc0c0c0, 0x0, 18)
	Header_Crafting = gui.newLabel(mainGui, 54, 2, "Crafting", 0xc0c0c0, 0x0, 8)
	Header_Message = gui.newLabel(mainGui, 63, 2, "Message", 0xc0c0c0, 0x0, 15)
	Header_Line = gui.newHLine(mainGui, 1, 3, 76)
	Header2_Name = gui.newLabel(mainGui, 84, 2, "Name", 0xc0c0c0, 0x0, 30)
	Header2_Current = gui.newLabel(mainGui, 115, 2, "Current (Setpoint)", 0xc0c0c0, 0x0, 18)
	Header2_Crafting = gui.newLabel(mainGui, 134, 2, "Crafting", 0xc0c0c0, 0x0, 8)
	Header2_Message = gui.newLabel(mainGui, 143, 2, "Message", 0xc0c0c0, 0x0, 15)
	Header2_Line = gui.newHLine(mainGui, 81, 3, 76)
end

local function DrawLines()
	local rowCount = 1
	for index = 1, 86 do
		if index % 2 == 1 then
			lines[index] = {}
			lines[index]["Radio"] = gui.newRadio(mainGui, 1, 3 + rowCount)
			lines[index]["Name"] = gui.newLabel(mainGui, 4, 3 + rowCount, "", 0xc0c0c0, 0x0, 30)
			lines[index]["Current"] = gui.newLabel(mainGui, 35, 3 + rowCount, "", 0xc0c0c0, 0x0, 18)
			lines[index]["Crafting"] = gui.newLabel(mainGui, 54, 3 + rowCount, "", 0xc0c0c0, 0x0, 8)
			lines[index]["Message"] = gui.newLabel(mainGui, 63, 3 + rowCount, "", 0xc0c0c0, 0x0, 15)
		else
			lines[index] = {}
			lines[index]["Radio"] = gui.newRadio(mainGui, 81, 3 + rowCount)
			lines[index]["Name"] = gui.newLabel(mainGui, 84, 3 + rowCount, "", 0xc0c0c0, 0x0, 30)
			lines[index]["Current"] = gui.newLabel(mainGui, 115, 3 + rowCount, "", 0xc0c0c0, 0x0, 18)
			lines[index]["Crafting"] = gui.newLabel(mainGui, 134, 3 + rowCount, "", 0xc0c0c0, 0x0, 8)
			lines[index]["Message"] = gui.newLabel(mainGui, 143, 3 + rowCount, "", 0xc0c0c0, 0x0, 15)
			rowCount = rowCount + 1
		end
	end

	for index = 1, 86 do
		gui.setVisible(mainGui, lines[index]["Radio"], false, true)
	end
end

local function EmptyLines()
	for index = 1, 86 do
		gui.setVisible(mainGui, lines[index]["Radio"], false, true)
		gui.setText(mainGui, lines[index]["Name"], "")
		gui.setText(mainGui, lines[index]["Current"], "")
		gui.setText(mainGui, lines[index]["Crafting"], "")
		gui.setText(mainGui, lines[index]["Message"], "")
	end
end

local function FillLines()
	for index = 1, #items do
		gui.setVisible(mainGui, lines[index]["Radio"], true, true)
		gui.setEnable(mainGui, lines[index]["Radio"], true, true)
		gui.setText(mainGui, lines[index]["Name"], items[index]["Name"])
		gui.setText(mainGui, lines[index]["Current"], items[index]["CurrentValue"] .. " (" .. items[index]["Setpoint"] .. ")")
		if items[index]["CurrentCraftAmount"] > 0 then
			gui.setText(mainGui, lines[index]["Crafting"], items[index]["CurrentCraftAmount"] .. "")
		else
			gui.setText(mainGui, lines[index]["Crafting"], "")
		end
		gui.setText(mainGui, lines[index]["Message"], items[index]["Message"])
	end
end

local addGui_Open
local changeGui_Open
local addItem = {}
local changeItemIndex

local function Item_Name_Callback(guiID, textID, text)
   addItem["Name"] = text
end

local function Setpoint_Callback(guiID, textID, text)
   addItem["Setpoint"] = tonumber(text)
end

local function ItemDamage_Callback(guiID, textID, text)
   addItem["Damage"] = tonumber(text)
end

local function CraftAmount_Callback(guiID, textID, text)
   addItem["CraftAmount"] = tonumber(text)
end

local function addButtonCallback(guiID, id)
	index = #items + 1
	if index <= 86 then
		items[index] = {}
		items[index]["rawItemName"] = addItem["Name"]
		items[index]["rawItemDamage"] = addItem["Damage"]
		items[index]["Setpoint"] = addItem["Setpoint"]
		items[index]["CraftAmount"] = addItem["CraftAmount"]

		SaveItems()

		addGui_Open = false
	else
		addGui_Open = false
		gui.showMsg("Maximum number of items reached (86 items).")
	end
end

local function changeButtonCallback(guiID, id)
	index = changeItemIndex
	items[index] = {}
	items[index]["rawItemName"] = addItem["Name"]
	items[index]["rawItemDamage"] = addItem["Damage"]
	items[index]["Setpoint"] = addItem["Setpoint"]
	items[index]["CraftAmount"] = addItem["CraftAmount"]

	SaveItems()

	changeGui_Open = false
end

local function exitButtonCallback(guiID, id)
	addGui_Open = false
	changeGui_Open = false
end

local function AddItem_Callback(guiID, buttonID)
	local addGui = gui.newGui("center", "center", 62, 10, true, "Add Item")
	Item_Name_Label = gui.newLabel(addGui, 1, 1, "   Item Name: ", 0xc0c0c0, 0x0, 7)
	Item_Name = gui.newText(addGui, 15, 1, 30, "", Item_Name_Callback, 30, false)
	Item_Damage_Label = gui.newLabel(addGui, 1, 3, " Item Damage: ", 0xc0c0c0, 0x0, 7)
	Item_Damage = gui.newText(addGui, 15, 3, 8, "", ItemDamage_Callback, 8, false)
	Item_Damage_Help = gui.newLabel(addGui, 24, 3, "(Metadata number of item)", 0xc0c0c0, 0x0, 7)
	Setpoint_Label = gui.newLabel(addGui, 1, 5, "    Setpoint: ", 0xc0c0c0, 0x0, 7)
	Setpoint = gui.newText(addGui, 15, 5, 8, "", Setpoint_Callback, 8, false)
	Setpoint_Help = gui.newLabel(addGui, 24, 5, "(How many items to keep in stock)", 0xc0c0c0, 0x0, 7)	
	CraftAmount_Label = gui.newLabel(addGui, 1, 7, "Craft Amount: ", 0xc0c0c0, 0x0, 7)
	CraftAmount = gui.newText(addGui, 15, 7, 8, "", CraftAmount_Callback, 8, false)
	CraftAmount_Help = gui.newLabel(addGui, 24, 7, "(How many items to craft max at once)", 0xc0c0c0, 0x0, 7)
	addButton = gui.newButton(addGui, 41, 9, "Add Item", addButtonCallback)
	exitButton = gui.newButton(addGui, 52, 9, "Cancel", exitButtonCallback)

	addGui_Open = true
	addItem = {}

	gui.displayGui(addGui)
	while addGui_Open do
		gui.runGui(addGui)
	end
	gui.closeGui(addGui)
end

local function RemoveItem_Callback(guiID, buttonID)
   local radioIndex = gui.getRadio(guiID)
   local removeIndex

   for index = 1, #lines do
		if lines[index]["Radio"] == radioIndex then
			removeIndex = index
		end
   end
   
   table.remove(items, removeIndex)
   saveItems()
   EmptyLines()
end

local function ChangeItem_Callback(guiID, buttonID)
	local radioIndex = gui.getRadio(guiID)
	if radioIndex > 0 then
		for index = 1, #lines do
			if lines[index]["Radio"] == radioIndex then
				changeItemIndex = index
			end
		end

		local changeGui = gui.newGui("center", "center", 62, 10, true, "Change Item")
		Item_Name_Label = gui.newLabel(changeGui, 1, 1, "   Item Name: ", 0xc0c0c0, 0x0, 7)
		Item_Name = gui.newText(changeGui, 15, 1, 30, items[changeItemIndex]["rawItemName"], Item_Name_Callback, 30, false)
		Item_Damage_Label = gui.newLabel(changeGui, 1, 3, " Item Damage: ", 0xc0c0c0, 0x0, 7)
		Item_Damage = gui.newText(changeGui, 15, 3, 8, items[changeItemIndex]["rawItemDamage"], ItemDamage_Callback, 8, false)
		Item_Damage_Help = gui.newLabel(changeGui, 24, 3, "(Metadata number of item)", 0xc0c0c0, 0x0, 7)
		Setpoint_Label = gui.newLabel(changeGui, 1, 5, "    Setpoint: ", 0xc0c0c0, 0x0, 7)
		Setpoint = gui.newText(changeGui, 15, 5, 8, items[changeItemIndex]["Setpoint"], Setpoint_Callback, 8, false)
		Setpoint_Help = gui.newLabel(changeGui, 24, 5, "(How many items to keep in stock)", 0xc0c0c0, 0x0, 7)	
		CraftAmount_Label = gui.newLabel(changeGui, 1, 7, "Craft Amount: ", 0xc0c0c0, 0x0, 7)
		CraftAmount = gui.newText(changeGui, 15, 7, 8, items[changeItemIndex]["CraftAmount"], CraftAmount_Callback, 8, false)
		CraftAmount_Help = gui.newLabel(changeGui, 24, 7, "(How many items to craft max at once)", 0xc0c0c0, 0x0, 7)
		changeButton = gui.newButton(changeGui, 38, 9, "Change Item", changeButtonCallback)
		exitButton = gui.newButton(changeGui, 52, 9, "Cancel", exitButtonCallback)

		changeGui_Open = true
		addItem = {}
		addItem["Name"] = items[changeItemIndex]["rawItemName"]
		addItem["Damage"] = items[changeItemIndex]["rawItemDamage"]
		addItem["Setpoint"] = items[changeItemIndex]["Setpoint"]
		addItem["CraftAmount"] = items[changeItemIndex]["CraftAmount"]

		gui.displayGui(changeGui)
		while changeGui_Open do
			gui.runGui(changeGui)
		end
		gui.closeGui(changeGui)
	end
end

local function CpuMaxUsage_Callback(guiID, textID, text)
	maxCpuUsage = tonumber(text)
	SaveConfig()
end

local function DrawButtons()
	AddButton = gui.newButton(mainGui, 1, 1, "Add Item", AddItem_Callback)
	RemoveButton = gui.newButton(mainGui, 12, 1, "Remove Item", RemoveItem_Callback)
	ChangeButton = gui.newButton(mainGui, 26, 1, "Change Item", ChangeItem_Callback)
	CpuUsageLabel = gui.newLabel(mainGui, 118, 1, "CPU usage: ", 0xc0c0c0, 0x0, 13)
	CpuMaxUsageLabel = gui.newLabel(mainGui, 134, 1, "Max CPU usage: ", 0xc0c0c0, 0x0, 15)
	CpuMaxUsage = gui.newText(mainGui, 149, 1, 4, maxCpuUsage .. "", CpuMaxUsage_Callback, 4, false)
end

function CheckItemsAndCraft()
	for index = 1, #items do
		items[index]["Message"] = ""
		items[index]["CurrentValue"] = 0
		items[index]["Name"] = ""
		
		local meItem = meController.getItemsInNetwork({ name = items[index]["rawItemName"], damage = items[index]["rawItemDamage"]})
		if meItem.n >= 1 then
			if not meItem[1].isCraftable then
				items[index]["Message"] = "Not Craftable"
			end

			items[index]["CurrentValue"] = meItem[1].size
			items[index]["Name"] = meItem[1].label

			indexCraftTask = 1
			for indexCraftTasks = 1, #craftTasks do
				if craftTasks[indexCraftTasks].Id == index then indexCraftTask = indexCraftTasks end
			end

			if craftTasks[indexCraftTask].task ~= nil and indexCraftTask > 1 then
				if craftTasks[indexCraftTask].task.isDone() or craftTasks[indexCraftTask].task.isCanceled() then
					currentCpuUsage = currentCpuUsage - 1
					items[index]["CurrentCraftAmount"] = 0
					table.remove(craftTasks, indexCraftTask)
				end
			else
				if items[index]["CurrentCraftAmount"] == 0 and items[index]["CurrentValue"] < items[index]["Setpoint"] then
					if currentCpuUsage < maxCpuUsage then
						local meCpus = meController.getCpus()
						local occupiedCpus = 0
						for cpuIndex = 1, #meCpus do
							if meCpus[cpuIndex].busy then occupiedCpus = occupiedCpus + 1 end
						end
					
						if occupiedCpus < #meCpus then
							local currentCraftAmount = items[index]["Setpoint"] - items[index]["CurrentValue"]
							if currentCraftAmount > items[index]["CraftAmount"] then
								currentCraftAmount = items[index]["CraftAmount"]
							end

							local craftables = meController.getCraftables({ name = items[index]["rawItemName"], damage = items[index]["rawItemDamage"]})
							if craftables.n >= 1 then
								craftTask = craftables[1].request(currentCraftAmount)

								if craftTask.isCanceled() then
									items[index]["Message"] = "No ingredients"
								else
									items[index]["CurrentCraftAmount"] = currentCraftAmount
									craftTaskWithId = { Id = index, task = craftTask }
									newIndex = #craftTasks + 1
									craftTasks[newIndex] = craftTaskWithId
									currentCpuUsage = currentCpuUsage + 1
								end
							end
						else
							items[index]["Message"] = "All CPUs busy"
						end
					else
						items[index]["Message"] = "All CPUs busy"
					end
				end
			end
		end
	end

	gui.setText(mainGui, CpuUsageLabel, "CPU Usage: " .. currentCpuUsage)
end

DrawHeaders()
DrawLines()
DrawButtons()
LoadConfig()
LoadItems()

gui.clearScreen()
gui.setTop("Applied Energistics 2 Auto Stock")
gui.setBottom("")

-- Create Empty craftTask
craftTasks[1] = { Id = 0, task = "" }

-- Main loop
while true do
   gui.runGui(mainGui)
   CheckItemsAndCraft()
   FillLines()
end