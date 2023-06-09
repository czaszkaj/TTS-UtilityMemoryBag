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
local enable_addons = {
  -- clear buttons after selecting object to move
  clear_for_small_obj = true
  -- Do not create buttons or add tagged objects to bag.
  ignore_tags = true
  -- Select tagged obejcts by default (expect "ignore_tags")
  select_tags = true
  -- Select all objects from provided zone guid by default (expect "ignore_tags")
  select_zones = true
  -- Create buttons for objects (expect "ignore_tags")
  select_buttons = true
}
--[[ END: Addons ]]-------------------------------------------------------

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

function getAllObjectsForMemory()
  return getAllObjects() -- TODO extend getAllObjectsForMemory
end

--Creates selection buttons on objects
function createButtonsOnAllObjects(move)
    if move == false and add_select_addon_on_status == false then
      return
    end

    buttonIndexMap = {}
    local howManyButtons = 0

    local objsToHaveButtons = {}
    if move == true then
        objsToHaveButtons = getAllObjectsInMemory()
    else
        howManyButtons = #self.getButtons()
        add_first_obj_button_id = howManyButtons
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
    if move then
        theList = moveList
        if addon_handler.addons.clear_for_small_obj.state == false then
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

    if move and addon_handler.addons.clear_for_small_obj.state then
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

--[[----------------------------------------------------------------------------
Functions for addons
* save/load
* select options
--]]----------------------------------------------------------------------------

-- debug
function list_ids()
  print("Print:Buttons")
  for _, obj in ipairs(self.getButtons()) do
    if obj.label ~= nil then
      print("ID[", obj.index, "] Label = ", obj.label)
    end
  end
  print("Print:Inputs")
  for _, obj in ipairs(self.getInputs()) do
    if obj.label ~= nil then
      print("ID[", obj.index, "] Label = ", obj.label)
    end
  end
end

--[[ Addons ]]-------------------------------------------------------
--------------------------------------------------------------------------------
-- help funciton
--------------------------------------------------------------------------------

-- Copy table provided by Tyler from StackOverflow
-- https://stackoverflow.com/questions/640642/how-do-you-copy-a-lua-table-by-value
function copy(obj, seen)
  if type(obj) ~= 'table' then return obj end
  if seen and seen[obj] then return seen[obj] end
  local s = seen or {}
  local res = setmetatable({}, getmetatable(obj))
  s[obj] = res
  for k, v in pairs(obj) do res[copy(k, s)] = copy(v, s) end
  return res
end

--[[ "class" Addon handler for data and functionality ]]

AddonHandler = {}
AddonHandler.bagObj = self
AddonHandler.settings = {
--  sepparator = ";"
  -- order from top !!!
--  buttons_order = {"add_select_ignore_tags", "add_select_tag",
--       "add_select_zone", "add_select_addon_on"}
  color = {
    green = {0,1,0}
    black = {1,1,1}
    white = {0,0,0}
  }
  position = {
    start = {1.6,0.3,2.2}
    dist  = 0.8
  }
  button = {
    bg = { color_on = nil, color_off = nil }
    font = { color_on = nil, color_off = nil }
  }
  input = {
    bg = { color_on = nil, color_off = nil }
    font = { color_on = nil, color_off = nil }
  }
  base_button_count = 0;
  base_input_count = 0;
}

function AddonHandler:new(o)
  o = o or {}   -- create object if user does not provide one
  setmetatable(o, self)
  self.__index = self
  return o
end

function AddonHandler:Init(load_addons)
  -- set settings
  -- button
  self.settings.button.bg.color_on    = self.settings.color.black
  self.settings.button.bg.color_off   = self.settings.color.black
  self.settings.button.font.color_on  = self.settings.color.green
  self.settings.button.font.color_off = self.settings.color.white
  -- input
  self.settings.button.bg.color_on    = self.settings.color.white
  self.settings.button.bg.color_off   = self.settings.color.white
  self.settings.button.font.color_on  = self.settings.color.black
  self.settings.button.font.color_off = self.settings.color.black
  -- enable addons
  self.addon = {}
  self.count_enabled = 0;
  -- Init all
  for key, value in pairs(load_addons) do
    self.addon[key] = {}
    self.addon[key].enabled = false -- addon enabled
    self.addon[key].state = false -- addon selected
    self.addon[key].input = nil
    --{id = 0, label = "Missing.", valid = false, type = "text"},
    self.addon[key].button = nil
    --{id = 0, label = "Missing.", valid = false},
    self.addon[key].value = { "" }}
  end

  -- create and enable
  if load_addons.show_hide then
    self.AddAddon(name="show_hide", state = true)
  end
  if load_addons.clear_for_small_obj then
    self.AddAddon(name="clear_for_small_obj")
  end
  if load_addons.ignore_tags then
    self.AddAddon(name="ignore_tags", button = true, input = true)
  end
  if load_addons.select_tags then
    self.AddAddon(name="select_tags", button = true, input = true)
  end
  if load_addons.select_zones then
    self.AddAddon(name="select_zones", button = true, input = true, input_type = "guid")
  end
  if load_addons.select_buttons then
    self.AddAddon(name="select_buttons", button = true, state = true)
  end
  if self.enabled_count > 0 then
    self.AddAddon(name="show_hide", button = true)
  end
end

function AddonHandler:NameToStr(name)
  return string.gsub(string.upper(name),"_"," ")[1]
end

function AddonHandler:AddAddon(name, button = false, input = false,
                               input_type="tag", state=false, label=nil)
  self.addon[key].state = state
  self.addon[key].enabled = true
  self.addon[key].position = self.setting.position.start
  self.addon[key].getColor = function (on=self.settings.color.green, off=self.settings.color.white)
    if self.state then
      return on
    else
      return off
    end
  end

  if button then
    self.addon[key].button = {id = 0, label = label or self:NameToStr(name), valid = false}
  end
  if input then
    self.addon[key].input = {id = 0, label = label or self:NameToStr(name), valid = false, type = input_type},
  else
    self.addon[key].position[1] = 0
  end
  self.count_enabled = self.count_enabled + 1
  self.addon[key].id = self.count_enabled -- count from 1
end

function AddonHandler:GetBagBaseButtonCount()
  return self.setting.base_button_count
end

function AddonHandler:GetBagAllButtonCount()
  return self.setting.base_button_count + self.count_enabled
end

function AddonHandler:GetBagBaseInputCount()
  return self.setting.base_input_count
end

-- remove all object buttons for selection
function AddonHandler:removeButtonsOnAllObjects()
  buttons = self.bagObj.getButtons()
  for i = #buttons - 1, self:GetBagAllButtonCount(), -1 do
    -- remove last
    self.bagObj.removeButton(i)
  end
end

-- use to ignore button creation
function AddonHandler:validObject(obj)
  if self.addon.ignore_tags.enabled then
    return not obj.hasTag(self.addon.ignore_tags.value[1])
  end
end

-- use during setup to select obj by default
function AddonHandler:selectObject(obj)
  if self.addon.ignore_tags.enabled then
    return not obj.hasTag(self.addon.ignore_tags.value[1])
  end
  if self.addon.select_tags.enabled then
    return obj.hasTag(self.addon.select_tags.value[1])
  end
end

function AddonHandler:CreateUI()
  -- create Show/Hide button
  if self.enabled_count > 0 then
    self.createButton("show_hide", self.addon.show_hide)
  else
    return
  end
  -- create addon buttons
  for name, obj in self.addon do
    if obj.enabled then
      if obj.button ~= nil then
        self.createButton(name, obj)
      end
      if obj.input ~= nil then
        self.createInput(name, obj)
      end
    end
  end
end

function AddonHandler:getColor(element, type, status)
  if status then
    return self.settings[element][type].color_on
  else
    return self.settings[element][type].color_off
  end
end

function AddonHandler:createButton(name, args)
  if name ~= show_hide and self.addons.show_hide.state ~= false then
    return
  end
  local button_args = {
    label=args.label,
    position=args.position,
    rotation={0,180,0},
    height=350,
    width=1550,
    font_size=250,
    font_color=self.getColor("button", "font", args.status),
    color=self.getColor("button", "bg", args.status),
    function_owner=self.bagObj,
    click_function=self.createButtonClick(name, args)
  }
  -- move buttton up per distance
  button_args.position[3] = button_args.position[3] + self.setting.positon.dist * args.id
  self.createButton(button_args)
end

function AddonHandler:createInput(name, args)
  if name ~= show_hide and self.addons.show_hide.state ~= false then
    return
  end
  local input_args = {
    label=args.label,
    position=args.position,
    rotation={0,180,0},
    aligment = 1,
    height=350,
    width=1550,
    font_size=250,
    font_color=self.getColor("input", "font", args.status),
    color=self.getColor("input", "bg", args.status),
    function_owner=self.bagObj,
    input_function=self.createInputChange(name, args)
  }
  -- move buttton up per distance
  input_args.position[1] = 0 -- ?
  button_args.position[3] = button_args.position[3] + self.setting.positon.dist * args.id
  self.createInput(input_args)
end

-- Add option to show hide buttons
enable_addons.show_hide = {}
enable_addons.show_hide.state = true

-- Create Addon Handler
local addon_handler = AddonHandler:new()
addon_handler:Init(enable_addons)

----------
-- TODO --
----------

function AddonHandler:createButtonClick(name, addon_data)
  print("TODO")
  return function()
    addon_data.state = not addon_data.stat
    if name == "ignore_tags" or
       name == "select_tags" or
       name == "select_zones" then
      -- retrigger select (clear reselect)
        print("TODO")

    else name == "show_hide" then
      if self.addon.show_hide.state == false then
        self:removeAddonButtons()
      else
        self.bagObj.clearButtons()
        self.bagObj.clearInputs()
        createSetupActionButtons(true) -- call first for const button ids
        createButtonsOnAllObjects(false)
      end
    else  name == "select_buttons" then
      -- create / clear buttons
      self:removeButtonsOnAllObjects()
      createButtonsOnAllObjects(false)
    end

  end
end

function AddonHandler::createInputChange(name, addon_data)
  print("TODO")
  return function(obj, playerColor, text, stillEditing)
    addon_data.value = text
    if stillEditing == false thenen
        -- retrigger select (clear reselect)
          print("TODO")
    end
  end
end

function AddonHandler::OnSave()
  print("TODO")
  return {}
end

function AddonHandler::OnLoad(data)
  print("TODO")
end

-- check legacy "select selected" functionality if works

--[[ END: Addons ]]-------------------------------------------------------
