local isDead = false
local cam = nil
local angleZ, angleY = 0, 0

function secondsToClock(seconds)
  local seconds, hours, mins, secs = tonumber(seconds), 0, 0, 0

  if seconds <= 0 then
    return 0, 0
  else
    local hours = string.format('%02.f', math.floor(seconds / 3600))
    local mins = string.format('%02.f', math.floor(seconds / 60 - (hours * 60)))
    local secs = string.format('%02.f', math.floor(seconds - hours * 3600 - mins * 60))

    return mins, secs
  end
end

function DrawGenericTextThisFrame()
    SetTextFont(4)
    SetTextScale(0.0, 0.5)
    SetTextColour(255, 255, 255, 255)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextDropShadow()
    SetTextOutline()
    SetTextCentre(true)
end

function StartDeathCam()
  ClearFocus()
  local playerPed = PlayerPedId()
  cam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", GetEntityCoords(playerPed), 0, 0, 0, GetGameplayCamFov())
  SetCamActive(cam, true)
  RenderScriptCams(true, true, 1000, true, false)
end

-- destroy camera

function EndDeathCam()
  ClearFocus()
  RenderScriptCams(false, false, 0, true, false)
  DestroyCam(cam, false)
  cam = nil
end

-- process camera controls
function ProcessCamControls()
  local playerPed = PlayerPedId()
  local playerCoords = GetEntityCoords(playerPed)
  -- disable 1st person as the 1st person camera can cause some glitches
  DisableFirstPersonCamThisFrame()
  -- calculate new position
  local newPos = ProcessNewPosition()
  SetFocusArea(newPos.x, newPos.y, newPos.z, 0.0, 0.0, 0.0)
  -- set coords of cam
  SetCamCoord(cam, newPos.x, newPos.y, newPos.z)
  -- set rotation
  PointCamAtCoord(cam, playerCoords.x, playerCoords.y, playerCoords.z + 0.5)
end

function ProcessNewPosition()
    local mouseX = 0.0
    local mouseY = 0.0
    -- keyboard
    if (IsInputDisabled(0)) then
        -- rotation
        mouseX = GetDisabledControlNormal(1, 1) * 8.0

        mouseY = GetDisabledControlNormal(1, 2) * 8.0
        -- controller
    else
        mouseX = GetDisabledControlNormal(1, 1) * 1.5

        mouseY = GetDisabledControlNormal(1, 2) * 1.5
    end

    angleZ = angleZ - mouseX -- around Z axis (left / right)

    angleY = angleY + mouseY -- up / down
    -- limit up / down angle to 90°

    if (angleY > 89.0) then
        angleY = 89.0
    elseif (angleY < -89.0) then
        angleY = -89.0
    end
    local pCoords = GetEntityCoords(PlayerPedId())
    local behindCam = {x = pCoords.x + ((Cos(angleZ) * Cos(angleY)) + (Cos(angleY) * Cos(angleZ))) / 2 * (5.5 + 0.5),

                        y = pCoords.y + ((Sin(angleZ) * Cos(angleY)) + (Cos(angleY) * Sin(angleZ))) / 2 * (5.5 + 0.5),

                        z = pCoords.z + ((Sin(angleY))) * (5.5 + 0.5)}
    local rayHandle = StartShapeTestRay(pCoords.x, pCoords.y, pCoords.z + 0.5, behindCam.x, behindCam.y, behindCam.z, -1, PlayerPedId(), 0)

    local a, hitBool, hitCoords, surfaceNormal, entityHit = GetShapeTestResult(rayHandle)

    local maxRadius = 1.9
    if (hitBool and Vdist(pCoords.x, pCoords.y, pCoords.z + 0.5, hitCoords) < 5.5 + 0.5) then
        maxRadius = Vdist(pCoords.x, pCoords.y, pCoords.z + 0.5, hitCoords)
    end

    local offset = {x = ((Cos(angleZ) * Cos(angleY)) + (Cos(angleY) * Cos(angleZ))) / 2 * maxRadius,
                    y = ((Sin(angleZ) * Cos(angleY)) + (Cos(angleY) * Sin(angleZ))) / 2 * maxRadius, z = ((Sin(angleY))) * maxRadius}

    local pos = {x = pCoords.x + offset.x, y = pCoords.y + offset.y, z = pCoords.z + offset.z}

    return pos
end

RegisterNetEvent('playerDied')
AddEventHandler('playerDied',function ()
    OnPlayerDeath()
end)

function OnPlayerDeath()
    isDead = true

    ClearTimecycleModifier()
    SetTimecycleModifier("REDMIST_blend")
    SetTimecycleModifierStrength(0.7)
    SetExtraTimecycleModifier("fp_vig_red")
    SetExtraTimecycleModifierStrength(1.0)
    SetPedMotionBlur(PlayerPedId(), true)
    StartDeathTimer()
    StartDeathCam()
end

local function threedots(value)
    return string.rep(".",value//300%4)
end

function StartDeathTimer()

    local bleedoutTimer = 600000 / 1000

    CreateThread(function()
        -- bleedout timer
        while bleedoutTimer > 0 and isDead do
        Wait(1000)

        if bleedoutTimer > 0 then
            bleedoutTimer = bleedoutTimer - 1
        end
        end
    end)

    CreateThread(function()
        local text, timeHeld, pressed = nil, 0, false

        -- early respawn timer
        while bleedoutTimer > 0 and isDead do
            DisableAllControlActions(0)
            EnableControlAction(0, 47, true) -- G 
            EnableControlAction(0, 245, true) -- T
            EnableControlAction(0, 38, true) -- E
            ProcessCamControls()

            if timeHeld < 2 then
                text = string.format("Appuyer sur ~r~[E]~w~ pour respawn\nRéanimation auto dans %s:%s",secondsToClock(bleedoutTimer)) -- ('respawn_available_in', )
            else
                text = string.format("\nRéanimation en cours%s",threedots(timeHeld))
            end

            DrawGenericTextThisFrame()
            BeginTextCommandDisplayText('STRING')
            AddTextComponentSubstringPlayerName(text)
            EndTextCommandDisplayText(0.5, 0.8)

            if IsControlJustPressed(0, 38) then
                pressed = true
            end

            if pressed then
                timeHeld = timeHeld + 10
            end

            if timeHeld > 2500 then
                TriggerEvent('revive')
            end

            Citizen.Wait(10)
        end

        if IsEntityDead(PlayerPedId()) then
            TriggerEvent('revive')
        end

        EnableAllControlActions(0)
    end)
end

function RespawnPed(ped, coords, heading)
    SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false)
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, heading, true, false)
    SetPlayerInvincible(ped, false)
    ClearPedBloodDamage(ped)
end

RegisterNetEvent('revive')
AddEventHandler('revive', function()
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)

    DoScreenFadeOut(800)

    while not IsScreenFadedOut() do
        Wait(50)
    end

    RespawnPed(playerPed, coords, 0.0)
    isDead = false
    ClearTimecycleModifier()
    SetPedMotionBlur(playerPed, false)
    ClearExtraTimecycleModifier()
    EndDeathCam()
    DoScreenFadeIn(800)
end)