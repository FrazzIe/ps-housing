local Freecam = exports['fivem-freecam']


local function RequestSpawnObject(object)
    RequestModel(object)
    while not HasModelLoaded(object) do 
        Wait(0)
    end
end

local function CamThread()
    CreateThread(function()
        local IsDisabledControlJustPressed = IsDisabledControlJustPressed
        local DisableControlAction = DisableControlAction
        while Modeler.IsFreecamMode do
            if IsDisabledControlJustPressed(0, 26) then -- C
                Modeler.IsFreecamMode = false
                Modeler:FreecamMode(false)
                break
            end
            DisableControlAction(0, 199, true) -- P
            DisableControlAction(0, 200, true) -- ESC
            Wait(0)
        end
    end)
end


AddEventHandler('freecam:onTick', function()
    if not Modeler.IsFreecamMode then return end
    Modeler.CurrentCameraLookAt =  Freecam:GetTarget(5.0)
    Modeler.CurrentCameraPosition = Freecam:GetPosition()
    SendNUIMessage({
        action = "updateCamera",
        data = {
            cameraPosition = Modeler.CurrentCameraPosition,
            cameraLookAt = Modeler.CurrentCameraLookAt,
        }
    })
  end)


-- WHERE THE ACTUAL CLASS STARTS

Modeler = {

    IsMenuActive = false,
    IsFreecamMode = false,

    CurrentObject = nil,
    CurrentCameraPosition = nil,
    CurrentCameraLookAt = nil,
    CurrentObjectAlpha = 200,
    Cart = {},

    OpenMenu = function(self)
        if not Property.inShell and Property.hasKey then return end
        self.IsMenuActive = true
        SendNUIMessage({
            action = "setVisible",
            data = true
        })
        SendNUIMessage({
            action = "setFurnituresData",
            data = Config.Furnitures
        })
        SetNuiFocus(true, true)
        self:FreecamActive(true)
        self:FreecamMode(false)
    end,

    CloseMenu = function(self)
        self.IsMenuActive = false
        self:ClearCart()
        SendNUIMessage({
            action = "setVisible",
            data = false
        })
        SetNuiFocus(false, false)
        self:CancelPlacement()
        self:FreecamActive(false)
        self.CurrentCameraPosition = nil
        self.CurrentCameraLookAt = nil
    end,

    FreecamActive = function(self, bool)
        if bool then
            Freecam:SetActive(true)
            Freecam:SetKeyboardSetting('BASE_MOVE_MULTIPLIER', 0.1)
            Freecam:SetKeyboardSetting('FAST_MOVE_MULTIPLIER', 2)
            Freecam:SetKeyboardSetting('SLOW_MOVE_MULTIPLIER', 2)
            Freecam:SetFov(45.0)
        else
            Freecam:SetActive(false)
            --reset to default
            Freecam:SetKeyboardSetting('BASE_MOVE_MULTIPLIER', 5)
            Freecam:SetKeyboardSetting('FAST_MOVE_MULTIPLIER', 10)
            Freecam:SetKeyboardSetting('SLOW_MOVE_MULTIPLIER', 10)
            self.IsFreecamMode = false
        end
    end,

    FreecamMode = function(self, bool)
        if bool then --not in UI
            self.IsFreecamMode = true
            CamThread()
            Freecam:SetFrozen(false)
            SetNuiFocus(false, false)
        else -- in UI
            self.IsFreecamMode = false
            Freecam:SetFrozen(true)
            SetNuiFocus(true, true)
            SendNUIMessage({
                action = "freecamMode",
                data = false
            })
        end
    end,

    StartPlacement = function(self, data)
        local object = data.object
        local curObject
        local objectRot
        local objectPos

        if data.entity then
            curObject = data.entity
            objectPos = data.position
            objectRot = data.rotation
        else 
            if self.CurrentObject ~= nil then
                self:CancelPlacement()
            end
            RequestSpawnObject(object)
            curObject = CreateObject(GetHashKey(object), 0.0, 0.0, 0.0, false, true, false)
            Modeler.CurrentCameraLookAt =  Freecam:GetTarget(5.0)
            Modeler.CurrentCameraPosition = Freecam:GetPosition()
            SetEntityCoords(curObject, self.CurrentCameraLookAt.x, self.CurrentCameraLookAt.y, self.CurrentCameraLookAt.z)
            objectRot = GetEntityRotation(curObject)
            objectPos = self.CurrentCameraLookAt
        end


        FreezeEntityPosition(curObject, true)
        SetEntityCollision(curObject, false, false)
        SetEntityAlpha(curObject, self.CurrentObjectAlpha, false)
        SetEntityDrawOutline(curObject, true)
        SetEntityDrawOutlineColor(255, 255, 255, 255)
        SetEntityDrawOutlineShader(0)
        SendNUIMessage({
            action = "setObjectAlpha",
            data = self.CurrentObjectAlpha
        })


        SendNUIMessage({ 
            action = "setupModel",
            data = {
                objectPosition = objectPos,
                objectRotation = objectRot,
                cameraPosition = self.CurrentCameraPosition,
                cameraLookAt = self.CurrentCameraLookAt,
                cartIndex = data.entity or nil,
            }
        })
        SetNuiFocus(true, true)
        self.CurrentObject = curObject
    end,

    MoveObject = function (self, data)
        SetEntityCoords(self.CurrentObject, data.x + 0.0, data.y + 0.0, data.z + 0.0)
    end,

    RotateObject = function (self, data)
        SetEntityRotation(self.CurrentObject, data.x + 0.0, data.y + 0.0, data.z + 0.0)
    end,

    CancelPlacement = function (self)
        local inCart = false
        for k, v in pairs(self.Cart) do
            if k == self.CurrentObject then
                inCart = true
                break
            end
        end
        if not inCart then
            DeleteEntity(self.CurrentObject)
        end
        SetEntityDrawOutline(self.CurrentObject, false)
        SetEntityAlpha(self.CurrentObject, 255, false)
        self.CurrentObject = nil
    end,

    SetObjectAlpha = function (self, data)
        self.CurrentObjectAlpha = data.alpha
        SetEntityAlpha(self.CurrentObject, self.CurrentObjectAlpha, false)
    end,

    PlaceOnGround = function (self)
        local x, y, z = table.unpack(GetEntityCoords(self.CurrentObject))
        local ground, z = GetGroundZFor_3dCoord(x, y, z, 0)
        SetEntityCoords(self.CurrentObject, x, y, z)

        return {x = x, y = y, z = z}
    end,

    SelectCartItem = function (self, data)
        if self.CurrentObject ~= nil then
            self:CancelPlacement()
        end
        if data ~= nil then
            self:StartPlacement(data)
        end
    end,

    AddToCart = function (self, data)
        local item = {
            label = data.label,
            object = data.object,
            price = data.price,
            entity = self.CurrentObject,
            position = GetEntityCoords(self.CurrentObject),
            rotation = GetEntityRotation(self.CurrentObject),
        }
        self.Cart[self.CurrentObject] = item
        SendNUIMessage({
            action = "addToCart",
            data = item
        })
        self:CancelPlacement()
        self.CurrentObject = nil
    end,

    RemoveFromCart = function (self, data)
        local item = data
        if item ~= nil then
            DeleteEntity(item.entity)
            SendNUIMessage({
                action = "removeFromCart",
                data = item
            })
            self.Cart[data.entity] = nil
        end
    end,

    UpdateCartItem = function (self, data)
        local item = self.Cart[data.entity]
        if item ~= nil then
            item = data
        end
    end,

    ClearCart = function (self)
        for k, v in pairs(self.Cart) do
            DeleteEntity(v.entity)
        end
        self.Cart = {}
        SendNUIMessage({
            action = "clearCart"
        })
    end,

    BuyCart = function (self)

        local shellPos = GetEntityCoords(Property.shellObj)
        local items = {}
        local totalPrice = 0
        -- seperate loop to get total price so it doesnt have to do all that math for no reason
        for k, v in pairs(self.Cart) do
            totalPrice = totalPrice + v.price
        end

        local PlayerData = QBCore.Functions.GetPlayerData()
        if PlayerData.money.cash < totalPrice then
            lib.notify({title= "You don't have enough money!", type = "error"})
            return
        end

        for k, v in pairs(self.Cart) do
            local offsetPos = {
                x = math.floor((v.position.x - shellPos.x) * 100) / 100,
                y = math.floor((v.position.y - shellPos.y) * 100) / 100,
                z = math.floor((v.position.z - shellPos.z) * 100) / 100,
            }
            items[#items + 1] = {
                object = v.object, 
                position = offsetPos,
                rotation = v.rotation,
            }
        end

        if totalPrice > 0 then
            local currentproperty_id = Property.property_id
            TriggerServerEvent("ps-housing:server:buyFurniture", currentproperty_id, items, totalPrice)
        end
        self:ClearCart()
    end,

    -- Hover stuff
    IsHovering = false,
    HoverObject = nil,
    HoverDistance = 5.0,

    SetHoverDistance = function (self, data)
        self.HoverDistance = data + 0.0
    end,

    HoverIn = function (self, data)
        self:HoverOut()
        local object = data.object
        if object == nil then return end
        RequestSpawnObject(object)
        self.HoverObject = CreateObject(GetHashKey(object), 0.0, 0.0, 0.0, false, true, false)
        Modeler.CurrentCameraLookAt =  Freecam:GetTarget(self.HoverDistance)
        local camRot = Freecam:GetRotation()

        SetEntityCoords(self.HoverObject, self.CurrentCameraLookAt.x, self.CurrentCameraLookAt.y, self.CurrentCameraLookAt.z)
        FreezeEntityPosition(self.HoverObject, true)
        SetEntityCollision(self.HoverObject, false, false)
        SetEntityRotation(self.HoverObject, 0.0, 0.0, camRot.z)
        self.IsHovering = true
        while self.IsHovering do
            local rot = GetEntityRotation(self.HoverObject)
            SetEntityRotation(self.HoverObject, rot.x, rot.y, rot.z + 0.1)
            Wait(0)
        end
    end,

    HoverOut = function (self)
        DeleteEntity(self.HoverObject)
        self.HoverObject = nil
        self.IsHovering = false
    end,
}

AddEventHandler("ps-housing:client:furnitureMenu", function(resource)
    Modeler:OpenMenu()
end)

RegisterNUICallback("previewFurniture", function(data, cb)
	Modeler:StartPlacement(data)
	cb("ok")
end)

RegisterNUICallback("moveObject", function(data, cb)
    Modeler:MoveObject(data)
    cb("ok")
end)

RegisterNUICallback("rotateObject", function(data, cb)
    Modeler:RotateObject(data)
    cb("ok")
end)

RegisterNUICallback("cancelPlacement", function(data, cb)
    Modeler:CancelPlacement()
    cb("ok")
end)

RegisterNUICallback("setObjectAlpha", function(data, cb)
    Modeler:SetObjectAlpha(data)
    cb("ok")
end)

RegisterNUICallback("hideUI", function(data, cb)
    Modeler:CloseMenu()
	cb("ok")
end)

RegisterNUICallback("freecamMode", function(data, cb)
    Modeler:FreecamMode(data)
    cb("ok")
end)

RegisterNUICallback("placeOnGround", function(data, cb)
    local coords = Modeler:PlaceOnGround()
    cb(coords)
end)

RegisterNUICallback("selectCartItem", function(data, cb)
    Modeler:SelectCartItem(data)
    cb("ok")
end)

RegisterNUICallback("addToCart", function(data, cb)
    Modeler:AddToCart(data)
    cb("ok")
end)

RegisterNUICallback("removeCartItem", function(data, cb)
    Modeler:RemoveFromCart(data)
    cb("ok")
end)

RegisterNUICallback("updateCartItem", function(data, cb)
    Modeler:UpdateCartItem(data)
    cb("ok")
end)

RegisterNUICallback("buyCartItems", function(data, cb)
    Modeler:BuyCart()
    cb("ok")
end)

RegisterNUICallback("hoverIn", function(data, cb)
    Modeler:HoverIn(data)
    cb("ok")
end)

RegisterNUICallback("hoverOut", function(data, cb)
    Modeler:HoverOut()
    cb("ok")
end)

RegisterNUICallback("setHoverDistance", function(data, cb)
    Modeler:SetHoverDistance(data)
    cb("ok")
end)