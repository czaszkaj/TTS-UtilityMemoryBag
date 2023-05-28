-- Utility memory bag by Directsun
-- Version 2.7.0
-- Fork of Memory Bag 2.0 by MrStump
--
-- Want to contribute? Create an issue or fork the code on GitHub and submit a pull request:
-- https://github.com/sunflowermans/TTS-UtilityMemoryBag

CONFIG = {
    MEMORY_GROUP = {
        -- This determines how many frames to wait before actually placing objects onto the table when the "Place" button is clicked.
        -- This gives the other bags time to recall their objects.
        -- The delay ONLY occurs if other bags have objects out.
        FRAME_DELAY_BEFORE_PLACING_OBJECTS = 30,
    },
}

--[[ Addons ]]-------------------------------------------------------
-- button backgound color
button_bg_color_on = {0,1,0}
button_bg_color_off = {1,1,1}
-- start position for additional button on top of the bag
add_position = {2,0.3,2.2}
-- distance between buttons
distance = 0.8
-- id of first button id of an objects, after bag buttons
first_obj_button_id = 9
--[[
Remove buttons on object after selecting one to move.
Helps for small objects that are smaller then sreated buttons.
--]]
add_clear_for_small_obj = true
--[[
Do not create buttons or add tagged objects to bag.
--]]
add_select_ignore_tags = true -- use to turn on/off the addon
add_select_ignore_tags_id = 4
add_select_ignore_tags_status = false
--[[
Select tagged obejcts by default
--]]
add_select_tag = true -- use to turn on/off the addon
add_select_tag_id = 5
add_select_tag_status = false
--[[
Select all objects from provided zone guid
--]]
add_select_zone = true -- use to turn on/off the addon
add_select_zone_id = 6
add_select_zone_status = false
--[[
is anny selection addon on
used also for enabling/disablig Buttons
the name should be updated
--]]
add_select_addon_on =
  add_select_tag or
  add_select_zone
add_select_addon_on_id = 7
add_select_addon_on_status = true

--[[ Memory Bag Groups ]]-------------------------------------------------------
--[[
Utility Memory Bags may be added to a named group, called a "memory group".

You can add a bag to a group through the bag's UI: "Setup" > "Group Name" (to the left of the bag).

Only one bag from a group may have it's contents placed on the table at a time.
When "Place" is clicked on a bag, the other bags in it's memory group are recalled.

By default a memory bag is not in any group. It's memory group is "nil".
--]]

memoryGroupName = {memoryBag=self}
function memoryGroupName:get()
    return self._name
end
function memoryGroupName:set(newName)
    GlobalMemoryGroups:unregisterBagInGroup(self:get(), self.memoryBag.getGUID())
    GlobalMemoryGroups:registerBagInGroup(newName, self.memoryBag.getGUID())

    if newName == "" then
        self._name = nil
    else
        self._name = newName
    end
end

-- Click the "Recall" button on all other bags in my memory group.
function recallOtherBagsInMyGroup()
    for _,bag in ipairs(getOtherBagsInMyGroup()) do
        bag.call('buttonClick_recall')
    end
end

-- Return "true" if another bag in my memory group has any objects out on the table.
function anyOtherBagsInMyGroupArePlaced()
    for _,bag in ipairs(getOtherBagsInMyGroup()) do
        local state = bag.call('areAnyOfMyObjectsPlaced')
        if state then return true end
    end

    return false
end

-- Return "true" if at least one object from this memory bag is out on the table.
function areAnyOfMyObjectsPlaced()
    for guid,_ in pairs(memoryList) do
        local obj = getObjectFromGUID(guid)
        if obj ~= nil then
            return true
        end
    end
    return false
end

function getOtherBagsInMyGroup()
    local bags = {}
    for bagGuid,_ in pairs(GlobalMemoryGroups:getGroup(memoryGroupName:get())) do
        if bagGuid ~= self.getGUID() then
            bag = getObjectFromGUID(bagGuid)
            -- "bag" is nill if it has been deleted since the last time onLoad() was called.
            if bag ~= nil then
                table.insert(bags, bag)
            end
        end
    end
    return bags
end


--[[
This object provides access to a variable stored on the "Global script".
The variable holds the names & guids of all memory bag groups.

The global variable is a table and holds data like this:
{
    'My First Group Name' = {
        '805ebd' = {},
        '35cc21' = {},
        'fc8886' = {},
    },
    'My Second Group Name' = {
        'f50264' = {},
        '5f5f63' = {},
    },
}
--]]
GlobalMemoryGroups = {
    NAME_OF_GLOBAL_VARIABLE = '_GlobalUtilityMemoryBagGroups',
}

-- Call me inside this script's "onLoad()" method!
function GlobalMemoryGroups:onLoad(myGuid)
    -- Create and initialize the global variable if it doesn't already exist:
    if self:_getGroups() == nil then
        self:_setGroups({})
    end
end

-- Return the GUIDs of all bags in the "groupName". The return value is a dictionary that maps [GUID -> empty table].
function GlobalMemoryGroups:getGroup(groupName)
    guids = self:_getGroups()[groupName] or {}
    return guids
end

-- Registers a bag in a memory group. Creates a new group if one doesn't exist.
function GlobalMemoryGroups:registerBagInGroup(groupName, bagGuid)
    if groupName == nil or groupName == "" then
        return
    end

    self:_tryCreateNewGroup(groupName)
    local groups = self:_getGroups()
    groups[groupName][bagGuid] = {}
    self:_setGroups(groups)
end

-- Removes this bag from the memory group.
function GlobalMemoryGroups:unregisterBagInGroup(groupName, bagGuid)
    local groups = self:_getGroups()
    local group = groups[groupName]
    if group ~= nil then
        group[bagGuid] = nil
        self:_setGroups(groups)
    end
end

-- Return the global variable, which is a table holding all memory group names & guids.
function GlobalMemoryGroups:_getGroups()
    return Global.getTable(self.NAME_OF_GLOBAL_VARIABLE)
end

-- Override the global variable (i.e. the entire table).
function GlobalMemoryGroups:_setGroups(newTable)
    Global.setTable(self.NAME_OF_GLOBAL_VARIABLE, newTable)
end

-- Add a new memory group named "groupName" to the global variable, if one doesn't already exist.
function GlobalMemoryGroups:_tryCreateNewGroup(groupName)
    local groups = self:_getGroups()
    if groups[groupName] == nil then
        groups[groupName] = {}
        self:_setGroups(groups)
    end
end


-- This object controls the "Group Name" input text field that is part of the bag's ingame UI.
groupNameInput = {
    greyedOutText = "Group Name",
    widthPerCharacter = 100,
    padding = 4,
    memoryBag=self,
}
function groupNameInput:create(optionalStartingValue)
    local effectiveText = optionalStartingValue or self.greyedOutText
    local width = self:computeWidth(effectiveText)

    self.memoryBag.createInput({
        label=self.greyedOutText,
        value=optionalStartingValue or nil,
        alignment=3, -- Center aligned
        input_function="groupNameInput_onCharacterTyped", function_owner=self.memoryBag,
        position={2.1,0.3,0}, rotation={0,270,0}, width=width, height=350,
        font_size=250, color={0,0,0}, font_color={1,1,1},
    })
end
function groupNameInput:computeWidth(text)
    return (string.len(text) + self.padding) * self.widthPerCharacter
end
function groupNameInput:updatedWidth(text)
    self.memoryBag.editInput({
        index=0,
        width=self:computeWidth(text)
    })
end
function groupNameInput:onCharacterTyped(text, stillEditing)
    if stillEditing then
        self:updatedWidth(text)
    else
        if text == "" then
            self:updatedWidth(self.greyedOutText)
        end
    end
end
function groupNameInput_onCharacterTyped(memoryBag, playerColor, text, stillEditing)
    groupNameInput:onCharacterTyped(text, stillEditing)
end
function groupNameInput:setGroupNameToInputField()
    local inputFields = self.memoryBag.getInputs()
    if inputFields ~= nil then
        -- Get input field 0, which corresponds to the groupNameInput.
        -- Unfortunately "self.getInputs()" doesn't return the inputs in a guaranteed order.
        local nameField = nil
        for _,field in ipairs(inputFields) do
            if field.index == 0 then
                nameField = field
            end
        end

        memoryGroupName:set(nameField.value)
    end
end





--//////////////////////////////////////////////////////////////////////////////


function updateSave()
    local data_to_save = {
      ["ml"]=memoryList,
      ["groupName"]=memoryGroupName:get(),
      ["addon"]=save_addon()}
    saved_data = JSON.encode(data_to_save)
    self.script_state = saved_data
end

function combineMemoryFromBagsWithin()
    local bagObjList = self.getObjects()
    for _, bagObj in ipairs(bagObjList) do
        local data = bagObj.lua_script_state
        if data ~= nil then
            local j = JSON.decode(data)
            if j ~= nil and j.ml ~= nil then
                for guid, entry in pairs(j.ml) do
                    memoryList[guid] = entry
                end
            end
        end
    end
end

function updateMemoryWithMoves()
    memoryList = memoryListBackup
    --get the first transposed object's coordinates
    local obj = getObjectFromGUID(moveGuid)

    -- p1 is where needs to go, p2 is where it was
    local refObjPos = memoryList[moveGuid].pos
    local deltaPos = findOffsetDistance(obj.getPosition(), refObjPos, nil)
    local movedRotation = obj.getRotation()
    for guid, entry in pairs(memoryList) do
        memoryList[guid].pos.x = entry.pos.x - deltaPos.x
        memoryList[guid].pos.y = entry.pos.y - deltaPos.y
        memoryList[guid].pos.z = entry.pos.z - deltaPos.z
        -- memoryList[guid].rot.x = movedRotation.x
        -- memoryList[guid].rot.y = movedRotation.y
        -- memoryList[guid].rot.z = movedRotation.z
    end

    --theList[obj.getGUID()] = {
    --    pos={x=round(pos.x,4), y=round(pos.y,4), z=round(pos.z,4)},
    --    rot={x=round(rot.x,4), y=round(rot.y,4), z=round(rot.z,4)},
    --    lock=obj.getLock()
    --}
    moveList = {}
end

function onload(saved_data)
    GlobalMemoryGroups:onLoad(self.getGUID())
    AllMemoryBagsInScene:add(self.getGUID())

    fresh = true
    if saved_data ~= "" then
        local loaded_data = JSON.decode(saved_data)
        --Set up information off of loaded_data
        memoryList = loaded_data.ml
        memoryGroupName:set(loaded_data.groupName)
        load_addon(loaded_data.addon)
    else
        --Set up information for if there is no saved saved data
        memoryList = {}
        memoryGroupName:set(nil)
    end

    moveList = {}
    moveGuid = nil

    if next(memoryList) == nil then
        createSetupButton()
    else
        fresh = false
        createMemoryActionButtons()
    end
end


--Beginning Setup


--Make setup button
function createSetupButton()
    self.createButton({
        label="Setup", click_function="buttonClick_setup", function_owner=self,
        position={0,0.3,-2}, rotation={0,180,0}, height=350, width=800,
        font_size=250, color={0,0,0}, font_color={1,1,1}
    })
end

--Triggered by Transpose button
function buttonClick_transpose()
    moveGuid = nil
    broadcastToAll("Select one object and move it- all objects will move relative to the new location", {0.75, 0.75, 1})
    memoryListBackup = duplicateTable(memoryList)
    memoryList = {}
    moveList = {}
    self.clearButtons()
    self.clearInputs()
    createSetupActionButtons(true) -- call first for const button ids
    createButtonsOnAllObjects(true)
end

--Triggered by setup button,
function buttonClick_setup()
    memoryListBackup = duplicateTable(memoryList)
    memoryList = {}
    self.clearButtons()
    self.clearInputs()
    createSetupActionButtons(false) -- call first for const button ids
    createButtonsOnAllObjects(false)
end

function getAllObjectsInMemory()
    local objTable = {}
    local curObj = {}

    for guid in pairs(memoryListBackup) do
        curObj = getObjectFromGUID(guid)
        table.insert(objTable, curObj)
    end

    return objTable
    -- return getAllObjects()
end

--Creates selection buttons on objects
function createButtonsOnAllObjects(move)
    if move == false and add_select_addon_on_status == false then
      return
    end

    buttonIndexMap = {}
    local howManyButtons = first_obj_button_id

    local objsToHaveButtons = {}
    if move == true then
        objsToHaveButtons = getAllObjectsInMemory()
    else
        objsToHaveButtons = getAllObjects()
    end

    for _, obj in ipairs(objsToHaveButtons) do
        if obj ~= self then
            --On a normal bag, the button positions aren't the same size as the bag.
            globalScaleFactor = 1.25 * 1/self.getScale().x
            --Super sweet math to set button positions
            local selfPos = self.getPosition()
            local objPos = obj.getPosition()
            local deltaPos = findOffsetDistance(selfPos, objPos, obj)
            local objPos = rotateLocalCoordinates(deltaPos, self)
            objPos.x = -objPos.x * globalScaleFactor
            objPos.y = objPos.y * globalScaleFactor
            objPos.z = objPos.z * globalScaleFactor
            --Workaround for custom PDFs
            if obj.Book then
                objPos.y = objPos.y + 0.5
            end
            --Offset rotation of bag
            local rot = self.getRotation()
            rot.y = -rot.y + 180
            --Create function
            local funcName = "selectButton_" .. howManyButtons
            local func = function() buttonClick_selection(obj, move) end
            local color = {0.75,0.25,0.25,0.6}
            local colorMove = {0,0,1,0.6}
            if move == true then
                color = colorMove
            end
            self.setVar(funcName, func)
            self.createButton({
                click_function=funcName, function_owner=self,
                position=objPos, rotation=rot, height=1000, width=1000,
                color=color,
            })
            buttonIndexMap[obj.getGUID()] = howManyButtons
            howManyButtons = howManyButtons + 1
        end
    end
end

--Creates submit and cancel buttons
function createSetupActionButtons(move)
    self.createButton({
        label="Cancel", click_function="buttonClick_cancel", function_owner=self,
        position={0,0.3,-2}, rotation={0,180,0}, height=350, width=1100,
        font_size=250, color={0,0,0}, font_color={1,1,1}
    })

    self.createButton({
        label="Submit", click_function="buttonClick_submit", function_owner=self,
        position={0,0.3,-2.8}, rotation={0,180,0}, height=350, width=1100,
        font_size=250, color={0,0,0}, font_color={1,1,1}
    })

    if move == false then
        self.createButton({
            label="Add", click_function="buttonClick_add", function_owner=self,
            position={0,0.3,-3.6}, rotation={0,180,0}, height=350, width=1100,
            font_size=250, color={0,0,0}, font_color={0.25,1,0.25}
        })

        self.createButton({
            label="Selection", click_function="editDragSelection", function_owner=self,
            position={0,0.3,2}, rotation={0,180,0}, height=350, width=1100,
            font_size=250, color={0,0,0}, font_color={1,1,1}
        })
        groupNameInput:create(memoryGroupName:get())

        if fresh == false then
            self.createButton({
                label="Set New", click_function="buttonClick_setNew", function_owner=self,
                position={0,0.3,-4.4}, rotation={0,180,0}, height=350, width=1100,
                font_size=250, color={0,0,0}, font_color={0.75,0.75,1}
            })
            self.createButton({
                label="Remove", click_function="buttonClick_remove", function_owner=self,
                position={0,0.3,-5.2}, rotation={0,180,0}, height=350, width=1100,
                font_size=250, color={0,0,0}, font_color={1,0.25,0.25}
            })
        end

        --Addon Selection Buttons
        if add_select_ignore_tags == true then
            add_position[3] = add_position[3] + distance
            self.createButton({
                label="Ignore tags:", click_function="buttonClick_ignoreTags", function_owner=self,
                position=add_position, rotation={0,180,0}, height=350, width=1500,
                font_size=250, font_color=get_bg_color(add_select_ignore_tags_status), color={0,0,0}
            })
        end
        if add_select_tag == true then
            add_position[3] = add_position[3] + distance
            self.createButton({
                label="Select Tags:", click_function="buttonClick_selectTags", function_owner=self,
                position=add_position, rotation={0,180,0}, height=350, width=1500,
                font_size=250, font_color=get_bg_color(add_select_tag_status), color={0,0,0}
            })
        end
        if add_select_zone == true then
            add_position[3] = add_position[3] + distance
            self.createButton({
                label="Select Zones:", click_function="buttonClick_selectZones", function_owner=self,
                position=add_position, rotation={0,180,0}, height=350, width=1500,
                font_size=250, font_color=get_bg_color(add_select_zone_status), color={0,0,0}
            })
        end
        if add_select_addon_on == true then
            add_position[3] = add_position[3] + distance
            add_position[1] = 0
            self.createButton({
                label="Use Buttons", click_function="buttonClick_createButtons", function_owner=self,
                position=add_position, rotation={0,180,0}, height=350, width=1500,
                font_size=250, font_color=get_bg_color(add_select_addon_on_status), color={0,0,0}
            })
        end
        --END: Addon Selection Buttons
    end

    self.createButton({
        label="Reset", click_function="buttonClick_reset", function_owner=self,
        position={-2,0.3,0}, rotation={0,270,0}, height=350, width=800,
        font_size=250, color={0,0,0}, font_color={1,1,1}
    })
end


--During Setup


--Checks or unchecks buttons
function buttonClick_selection(obj, move)
    local index = buttonIndexMap[obj.getGUID()]
    local colorMove = {0,0,1,0.6}
    local color = {0,1,0,0.6}

    previousGuid = selectedGuid
    selectedGuid = obj.getGUID()

    theList = memoryList
    if move == true then
        theList = moveList
        if add_clear_for_small_obj == false then
          if previousGuid ~= nil and previousGuid ~= selectedGuid then
              local prevObj = getObjectFromGUID(previousGuid)
              prevObj.highlightOff()
              self.editButton({index=previousIndex, color=colorMove})
              theList[previousGuid] = nil
          end
          previousIndex = index
        end

    end

    if theList[selectedGuid] == nil then
        self.editButton({index=index, color=color})
        --Adding pos/rot to memory table
        local pos, rot = obj.getPosition(), obj.getRotation()
        --I need to add it like this or it won't save due to indexing issue
        theList[obj.getGUID()] = {
            pos={x=round(pos.x,4), y=round(pos.y,4), z=round(pos.z,4)},
            rot={x=round(rot.x,4), y=round(rot.y,4), z=round(rot.z,4)},
            lock=obj.getLock(),
            tint=obj.getColorTint()
        }
        obj.highlightOn({0,1,0})
    else
        color = {0.75,0.25,0.25,0.6}
        if move == true then
            color = colorMove
        end
        self.editButton({index=index, color=color})
        theList[obj.getGUID()] = nil
        obj.highlightOff()
    end

    if move == true  and add_clear_for_small_obj == true then
      self.clearButtons()
      createSetupActionButtons(true)
    end
end

function editDragSelection(bagObj, player, remove)
    local selectedObjs = Player[player].getSelectedObjects()
    if not remove then
        for _, obj in ipairs(selectedObjs) do
            local index = buttonIndexMap[obj.getGUID()]
            --Ignore if already in the memory list, or does not have a button
            if index and not memoryList[obj.getGUID()] then
                self.editButton({index=index, color={0,1,0,0.6}})
                --Adding pos/rot to memory table
                local pos, rot = obj.getPosition(), obj.getRotation()
                --I need to add it like this or it won't save due to indexing issue
                memoryList[obj.getGUID()] = {
                    pos={x=round(pos.x,4), y=round(pos.y,4), z=round(pos.z,4)},
                    rot={x=round(rot.x,4), y=round(rot.y,4), z=round(rot.z,4)},
                    lock=obj.getLock(),
                    tint=obj.getColorTint()
                }
                obj.highlightOn({0,1,0})
            end
        end
    else
        for _, obj in ipairs(selectedObjs) do
            local index = buttonIndexMap[obj.getGUID()]
            if index and memoryList[obj.getGUID()] then
                color = {0.75,0.25,0.25,0.6}
                self.editButton({index=index, color=color})
                memoryList[obj.getGUID()] = nil
                obj.highlightOff()
            end
        end
    end
end

--Cancels selection process
function buttonClick_cancel()
    memoryList = memoryListBackup
    moveList = {}
    self.clearButtons()
    self.clearInputs()
    if next(memoryList) == nil then
        createSetupButton()
    else
        createMemoryActionButtons()
    end
    removeAllHighlights()
    broadcastToAll("Selection Canceled", {1,1,1})
    moveGuid = nil
end

--Saves selections
function buttonClick_submit()
    fresh = false
    if next(moveList) ~= nil then
        for guid in pairs(moveList) do
            moveGuid = guid
        end
        if memoryListBackup[moveGuid] == nil then
            broadcastToAll("Item selected for moving is not already in memory", {1, 0.25, 0.25})
        else
            broadcastToAll("Moving all items in memory relative to new objects position!", {0.75, 0.75, 1})
            self.clearButtons()
            self.clearInputs()
            createMemoryActionButtons()
            local count = 0
            for guid in pairs(moveList) do
                moveGuid = guid
                count = count + 1
                local obj = getObjectFromGUID(guid)
                if obj ~= nil then obj.highlightOff() end
            end
            updateMemoryWithMoves()
            updateSave()
            buttonClick_place()
        end
    elseif next(memoryList) == nil and moveGuid == nil then
        memoryList = memoryListBackup
        broadcastToAll("No selections made.", {0.75, 0.25, 0.25})
    end
    combineMemoryFromBagsWithin()
    groupNameInput:setGroupNameToInputField()
    self.clearButtons()
    self.clearInputs()
    createMemoryActionButtons()
    local count = 0
    for guid in pairs(memoryList) do
        count = count + 1
        local obj = getObjectFromGUID(guid)
        if obj ~= nil then obj.highlightOff() end
    end
    broadcastToAll(count.." Objects Saved", {1,1,1})
    updateSave()
    moveGuid = nil
end

function combineTables(first_table, second_table)
    for k,v in pairs(second_table) do first_table[k] = v end
end

function buttonClick_add()
    fresh = false
    combineTables(memoryList, memoryListBackup)
    broadcastToAll("Adding internal bags and selections to existing memory", {0.25, 0.75, 0.25})
    combineMemoryFromBagsWithin()
    self.clearButtons()
    self.clearInputs()
    createMemoryActionButtons()
    local count = 0
    for guid in pairs(memoryList) do
        count = count + 1
        local obj = getObjectFromGUID(guid)
        if obj ~= nil then obj.highlightOff() end
    end
    broadcastToAll(count.." Objects Saved", {1,1,1})
    updateSave()
end

function buttonClick_remove()
    broadcastToAll("Removing Selected Entries From Memory", {1.0, 0.25, 0.25})
    self.clearButtons()
    self.clearInputs()
    createMemoryActionButtons()
    local count = 0
    for guid in pairs(memoryList) do
        count = count + 1
        memoryListBackup[guid] = nil
        local obj = getObjectFromGUID(guid)
        if obj ~= nil then obj.highlightOff() end
    end
    broadcastToAll(count.." Objects Removed", {1,1,1})
    memoryList = memoryListBackup
    updateSave()
end

function buttonClick_setNew()
    broadcastToAll("Setting new position relative to items in memory", {0.75, 0.75, 1})
    self.clearButtons()
    self.clearInputs()
    createMemoryActionButtons()
    local count = 0
    for _, obj in ipairs(getAllObjects()) do
        guid = obj.guid
        if memoryListBackup[guid] ~= nil then
            count = count + 1
            memoryListBackup[guid].pos = obj.getPosition()
            memoryListBackup[guid].rot = obj.getRotation()
            memoryListBackup[guid].lock = obj.getLock()
            memoryListBackup[guid].tint = obj.getColorTint()
        end
    end
    broadcastToAll(count.." Objects Saved", {1,1,1})
    memoryList = memoryListBackup
    updateSave()
end

--Resets bag to starting status
function buttonClick_reset()
    fresh = true
    memoryList = {}
    memoryGroupName:set(nil)
    self.clearButtons()
    self.clearInputs()
    createSetupButton()
    removeAllHighlights()
    broadcastToAll("Tool Reset", {1,1,1})
    updateSave()
end


--After Setup


--Creates recall and place buttons
function createMemoryActionButtons()
    self.createButton({
        label="Place", click_function="buttonClick_place", function_owner=self,
        position={0,0.3,-2}, rotation={0,180,0}, height=350, width=800,
        font_size=250, color={0,0,0}, font_color={1,1,1}
    })
    self.createButton({
        label="Recall", click_function="buttonClick_recall", function_owner=self,
        position={0,0.3,-2.8}, rotation={0,180,0}, height=350, width=800,
        font_size=250, color={0,0,0}, font_color={1,1,1}
    })
    self.createButton({
        label="Setup", click_function="buttonClick_setup", function_owner=self,
        position={-2,0.3,0}, rotation={0,270,0}, height=350, width=800,
        font_size=250, color={0,0,0}, font_color={1,1,1}
    })
    self.createButton({
        label="Move", click_function="buttonClick_transpose", function_owner=self,
        position={-2.8,0.3,0}, rotation={0,270,0}, height=350, width=800,
        font_size=250, color={0,0,0}, font_color={0.75,0.75,1}
    })
end

--Sends objects from bag/table to their saved position/rotation
function buttonClick_place()
    if anyOtherBagsInMyGroupArePlaced() then
        recallOtherBagsInMyGroup()
        Wait.frames(_placeObjects, CONFIG.MEMORY_GROUP.FRAME_DELAY_BEFORE_PLACING_OBJECTS)
    else
        _placeObjects()
    end
end

function _placeObjects()
    local bagObjList = self.getObjects()
    for guid, entry in pairs(memoryList) do
        local obj = getObjectFromGUID(guid)
        --If obj is out on the table, move it to the saved pos/rot
        if obj ~= nil then
            obj.setPositionSmooth(entry.pos)
            obj.setRotationSmooth(entry.rot)
            obj.setLock(entry.lock)
            obj.setColorTint(entry.tint)
        else
            --If obj is inside of the bag
            for _, bagObj in ipairs(bagObjList) do
                if bagObj.guid == guid then
                    local item = self.takeObject({
                        guid=guid, position=entry.pos, rotation=entry.rot, smooth=false
                    })
                    item.setLock(entry.lock)
                    item.setColorTint(entry.tint)
                    break
                end
            end
        end
    end
    broadcastToAll("Objects Placed", {1,1,1})
end

--Recalls objects to bag from table
function buttonClick_recall()
    for guid, entry in pairs(memoryList) do
        local obj = getObjectFromGUID(guid)
        if obj ~= nil then self.putObject(obj) end
    end
    broadcastToAll("Objects Recalled", {1,1,1})
end


--Utility functions


--Find delta (difference) between 2 x/y/z coordinates
function findOffsetDistance(p1, p2, obj)
    local yOffset = 0
    if obj ~= nil then
        local bounds = obj.getBounds()
        yOffset = (bounds.size.y - bounds.offset.y)
    end
    local deltaPos = {}
    deltaPos.x = (p2.x-p1.x)
    deltaPos.y = (p2.y-p1.y) + yOffset
    deltaPos.z = (p2.z-p1.z)
    return deltaPos
end

--Used to rotate a set of coordinates by an angle
function rotateLocalCoordinates(desiredPos, obj)
    local objPos, objRot = obj.getPosition(), obj.getRotation()
    local angle = math.rad(objRot.y)
    local x = desiredPos.x * math.cos(angle) - desiredPos.z * math.sin(angle)
    local z = desiredPos.x * math.sin(angle) + desiredPos.z * math.cos(angle)
    --return {x=objPos.x+x, y=objPos.y+desiredPos.y, z=objPos.z+z}
    return {x=x, y=desiredPos.y, z=z}
end

function rotateMyCoordinates(desiredPos, obj)
    local angle = math.rad(obj.getRotation().y)
    local x = desiredPos.x * math.sin(angle)
    local z = desiredPos.z * math.cos(angle)
    return {x=x, y=desiredPos.y, z=z}
end

--Coroutine delay, in seconds
function wait(time)
    local start = os.time()
    repeat coroutine.yield(0) until os.time() > start + time
end

--Duplicates a table (needed to prevent it making reference to the same objects)
function duplicateTable(oldTable)
    local newTable = {}
    for k, v in pairs(oldTable) do
        newTable[k] = v
    end
    return newTable
end

--Moves scripted highlight from all objects
function removeAllHighlights()
    for _, obj in ipairs(getAllObjects()) do
        obj.highlightOff()
    end
end

--Round number (num) to the Nth decimal (dec)
function round(num, dec)
    local mult = 10^(dec or 0)
    return math.floor(num * mult + 0.5) / mult
end


--[[
This object provides access to a variable stored on the "Global script".
The variable holds the GUIDs for every Utility Memory Bag in the scene.

Example:
{'805ebd', '35cc21', 'fc8886', 'f50264', '5f5f63'}
--]]
AllMemoryBagsInScene = {
    NAME_OF_GLOBAL_VARIABLE = "_UtilityMemoryBag_AllMemoryBagsInScene"
}

function AllMemoryBagsInScene:add(guid)
    local guids = Global.getTable(self.NAME_OF_GLOBAL_VARIABLE) or {}
    table.insert(guids, guid)
    Global.setTable(self.NAME_OF_GLOBAL_VARIABLE, guids)
end

function AllMemoryBagsInScene:getGuidList()
    return Global.getTable(self.NAME_OF_GLOBAL_VARIABLE) or {}
end

--[[
Functions for addons
--]]

-- debug
function list_button_id()
  for _, obj in ipairs(self.getButtons()) do
    if obj.label == nil then
      print("ID[", obj.index, "] Label = ", obj.label)
    end
  end
end

-- save/load
function load_addon(data)
  load_addon_set(data, "add_clear_for_small_obj", false)
  load_addon_set(data, "add_select_ignore_tags", true)
  load_addon_set(data, "add_select_tag", true)
  load_addon_set(data, "add_select_zone", true)
  load_addon_set(data, "add_select_addon_on", true)
end

function load_addon_set(data, addon, suffix)
  if data == nil or data[addon] == nil then
    return
  end

  _G[addon] = data[addon]["on"]
  if suffix == true then
    _G[addon.."_id"] = data[addon]["id"]
    _G[addon.."_status"] = data[addon]["status"]
  end
end

function save_addon()
  addon_to_save = {}
  save_addon_get(addon_to_save, "add_clear_for_small_obj", false)
  save_addon_get(addon_to_save, "add_select_ignore_tags", true)
  save_addon_get(addon_to_save, "add_select_tag", true)
  save_addon_get(addon_to_save, "add_select_zone", true)
  save_addon_get(addon_to_save, "add_select_addon_on", true)
  return addon_to_save
end

function save_addon_get(data, addon, suffix)
  data[addon] = {}
  data[addon]["on"] = _G[addon]
  if suffix == true then
    data[addon]["id"] = _G[addon.."_id"]
    data[addon]["status"] = _G[addon.."_status"]
  end
end

-- button handling
function get_bg_color(enable)
  if enable == true then
    return button_bg_color_on
  else
    return button_bg_color_off
  end
end

function addon_updateButton(id, status)
  self.editButton({index=id, font_color=get_bg_color(status)})
end

-- common button update operation
function buttonClick_addon(addon, func, args)
  _G[addon.."_status"] = not _G[addon.."_status"]
  addon_updateButton(_G[addon.."_id"], _G[addon.."_status"])
  --temporary leava for not implemented buttons
  if func == nil  then
    return
  end
  func(args)
  updateSave()
end

function buttonClick_ignoreTags()
  buttonClick_addon("add_select_ignore_tags")
    -- TODO
end

function buttonClick_selectTags()
  buttonClick_addon("add_select_tag")
    -- TODO
end

function buttonClick_selectZones()
  buttonClick_addon("add_select_zone")
    -- TODO
end

function buttonClick_createButtons()
  buttonClick_addon("add_select_addon_on", addon_switch_button_usage)
end

function addon_switch_button_usage()
  removeButtonsOnAllObjects()
  createButtonsOnAllObjects(false)
end

function removeButtonsOnAllObjects()
  buttons = self.getButtons()
  for i = #buttons - 1, first_obj_button_id, -1 do
    self.removeButton(i)
  end
end
