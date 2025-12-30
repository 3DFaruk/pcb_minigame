local cfg = {
    defaultSec = 10, -- minigame timer default seconds
    failOnConfirm = false
}

-- RegisterCommand('pcb', function()
--     exports.pcb_minigame:startMinigame(3 --[[ solder count ]], 30 --[[ minigame seconds ]], function(success)
--         print('Minigame finished with success: ' .. tostring(success))
--     end)
-- end)

local gameBuild = GetGameBuildNumber()

if gameBuild < 3407 then
    AddTextEntry('CBH_QUIT', 'Quit')
    AddTextEntry('CBH_CONFI', 'Confirm')
    AddTextEntry('CBH_MV_UD', 'Move')
    AddTextEntry('CBH_MV_LR', 'Select')
    AddTextEntry('PCB_FAIL', 'FAIL')
end

local aspectRatio = GetAspectRatio(false)
local ratioCalculate = 1.778 / aspectRatio

local finishTime
local resultCooldown
local randomLevel
local state = 0
local minigameStatus = false
local soundIds = {}
local timeSteps = { 0, false }
local startSolders = {}
local endSolders = {}
local blockDict

local funcVal59 = 0.453
local funcVal60 = 0.074
local funcVal63 = 0.465
local funcVal64 = 0.081
local funcVal75 = 0.004
local funcVal76 = 0.0625
local funcVal77 = funcVal64 - 0.014

local currentBlockPos = {}
local currentSelected

local positionsConfig = {
    { block = {1, 1, 2, 1, 1, 1, 2, 1}, solder = {1, 1}},
    { block = {2, 0, 0, 2, 0, 1, 2, 0}, solder = {4, 4}},
    { block = {0, 0, 2, 2, 0, 2, 1, 0}, solder = {4, 4}},
    { block = {1, 0, 2, 0, 0, 2, 1, 0}, solder = {4, 4}},
    { block = {1, 0, 1, 1, 1, 0, 0, 1}, solder = {6, 3}},
    { block = {2, 0, 2, 2, 0, 2, 0, 2}, solder = {4, 4}},
    { block = {2, 0, 2, 0, 0, 1, 0, 2}, solder = {7, 4}},
    { block = {1, 0, 1, 2, 2, 0, 0, 2}, solder = {4, 7}},
    { block = {0, 0, 2, 2, 2, 0, 0, 2}, solder = {4, 7}},
    { block = {2, 0, 2, 1, 2, 0, 0, 0}, solder = {4, 5}},
}

local function disableControls()
    DisableAllControlActions(2)
end

local function freeDicts()
    SetStreamedTextureDictAsNoLongerNeeded('PCB_Hack_Assets_Foreground')
    SetStreamedTextureDictAsNoLongerNeeded('PCB_Hack_Assets_Backgrounds')
    SetStreamedTextureDictAsNoLongerNeeded(blockDict)
    ReleaseNamedScriptAudioBank('DLC_24-2/DLC_24-2_Circuit_Hack')
    SetStreamedTextureDictAsNoLongerNeeded('MPBeamHack')
    for i=1, #soundIds do
        StopSound(soundIds[i])
        ReleaseSoundId(soundIds[i])
        StopAudioScene('DLC_24-2_Hacking_Circuit_Scene')
    end
end

local function requestDicts()
    RequestStreamedTextureDict('CommonMenu', false)
    if not HasStreamedTextureDictLoaded('CommonMenu') then
        return
    end
    RequestStreamedTextureDict('PCB_Hack_Assets_Backgrounds', false)
    if not HasStreamedTextureDictLoaded('PCB_Hack_Assets_Backgrounds') then
        return
    end
    RequestStreamedTextureDict('PCB_Hack_Assets_Foreground', false)
    if not HasStreamedTextureDictLoaded('PCB_Hack_Assets_Foreground') then
        return
    end
    RequestStreamedTextureDict('MPBeamHack', false)
    if not HasStreamedTextureDictLoaded('MPBeamHack') then
        return
    end

    blockDict = getBlockDict(randomLevel)

    RequestStreamedTextureDict(blockDict, false)
    if not HasStreamedTextureDictLoaded(blockDict) then
        return
    end

    StartAudioScene('DLC_24-2_Hacking_Circuit_Scene')
    soundIds[1] = GetSoundId()
    PlaySoundFrontend(soundIds[1], 'Background_Loop', 'DLC_24-2_Hack_Circuit_Board', true)
    soundIds[2] = GetSoundId()
    PlaySoundFrontend(soundIds[2], 'Timer', 'DLC_24-2_Hack_Circuit_Board', true)

    local index = 1
    while index <= 8 do
        local randomBlockPos = math.random(0, 2)
        if positionsConfig[randomLevel + 1].block[index] ~= randomBlockPos then
            currentBlockPos[index] = randomBlockPos
            index = index + 1
        end
    end

    setState(1)
end

local function drawBackground()
    DrawRect(0.0, 0.0, 1.0, 1.0, 0, 0, 100, 255)
    DrawSprite('PCB_Hack_Assets_Backgrounds', 'PCB_Hack_Background', 0.5, 0.5, ratioCalculate, 1.0, 0.0, 255, 255, 255, 255, false, 0)
end

local time
local timeRemainingSoundCd
local function drawTimerText()
    if state == 1 then
        time = finishTime - GetGameTimer()
    end
    if time <= 0 then
        time = 0
        if state == 1 then
            setState(3)
        end
    end
    
    if time < 10000 and (not timeRemainingSoundCd or timeRemainingSoundCd - time > 100) and not HasSoundFinished(soundIds[2]) then
        timeRemainingSoundCd = time
        SetVariableOnSound(soundIds[2], 'TimeRemaining', math.floor(time / 1000))
    end
    
    SetTextFont(4)
    SetTextScale(0.85, 0.85)
    SetTextColour(255, (time <= 0 or state == 3) and 0 or 255, (time <= 0 or state == 3) and 0 or 255, (time <= 0 or state == 3) and ((1 - timeSteps[1]) * 100 + timeSteps[1]*255) or 255)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringTime(time, 519)
    EndTextCommandDisplayText(adjustToRatio(0.7675), 0.1)
end

local function drawHelperText(scaleform)
    DrawScaleformMovieFullscreen(scaleform, 255, 255, 255, 255, 0)
end

local function setupHelperText()
    local scaleform = RequestScaleformMovieInstance('GENERIC_INSTRUCTIONAL_BUTTONS')
    while not HasScaleformMovieLoaded(scaleform) do
        Wait(0)
    end
    
    BeginScaleformMovieMethod(scaleform, 'CLEAR_ALL')
    EndScaleformMovieMethod()
    
    BeginScaleformMovieMethod(scaleform, 'SET_CLEAR_SPACE')
    ScaleformMovieMethodAddParamInt(10)
    EndScaleformMovieMethod()
    
    
    BeginScaleformMovieMethod(scaleform, 'SET_DATA_SLOT')
    ScaleformMovieMethodAddParamInt(0)
    ScaleformMovieMethodAddParamPlayerNameString(GetControlInstructionalButton(2, 173, true))
    ScaleformMovieMethodAddParamPlayerNameString(GetControlInstructionalButton(2, 172, true))
    BeginTextCommandScaleformString('CBH_MV_UD')
    EndTextCommandScaleformString()
    EndScaleformMovieMethod()
    
    BeginScaleformMovieMethod(scaleform, 'SET_DATA_SLOT')
    ScaleformMovieMethodAddParamInt(1)
    ScaleformMovieMethodAddParamPlayerNameString(GetControlInstructionalButton(2, 175, true))
    ScaleformMovieMethodAddParamPlayerNameString(GetControlInstructionalButton(2, 174, true))
    BeginTextCommandScaleformString('CBH_MV_LR')
    EndTextCommandScaleformString()
    EndScaleformMovieMethod()
    
    BeginScaleformMovieMethod(scaleform, 'SET_DATA_SLOT')
    ScaleformMovieMethodAddParamInt(2)
    ScaleformMovieMethodAddParamPlayerNameString(GetControlInstructionalButton(2, 202, true))
    BeginTextCommandScaleformString('CBH_QUIT')
    EndTextCommandScaleformString()
    EndScaleformMovieMethod()
    
    BeginScaleformMovieMethod(scaleform, 'SET_DATA_SLOT')
    ScaleformMovieMethodAddParamInt(3)
    ScaleformMovieMethodAddParamPlayerNameString(GetControlInstructionalButton(2, 201, true))
    BeginTextCommandScaleformString('CBH_CONFI')
    EndTextCommandScaleformString()
    EndScaleformMovieMethod()
    
    BeginScaleformMovieMethod(scaleform, 'DRAW_INSTRUCTIONAL_BUTTONS')
    EndScaleformMovieMethod()
    
    BeginScaleformMovieMethod(scaleform, 'SET_BACKGROUND_COLOUR')
    ScaleformMovieMethodAddParamInt(0)
    ScaleformMovieMethodAddParamInt(0)
    ScaleformMovieMethodAddParamInt(0)
    ScaleformMovieMethodAddParamInt(80)
    EndScaleformMovieMethod()
    
    return scaleform
end



local function drawResultText(command, color)
    SetTextFont(0)
    SetTextScale(1.6, 1.6)
    SetTextColour(color[1], color[2], color[3], 255)
    SetTextDropShadow(5, 0, 0, 0, 175)
    SetTextJustification(0)
    BeginTextCommandDisplayText(command)
    EndTextCommandDisplayText(0.5, 0.41)
end

local function timeStepFunct()
    if timeSteps[2] then
        timeSteps[1] = timeSteps[1] + (3.0 * Timestep())
        if (timeSteps[1] >= 1.0) then
            timeSteps[1] = 1.0
            timeSteps[2] = false
        end
    else
        timeSteps[1] = timeSteps[1] - (3.0 * Timestep())
        if (timeSteps[1] <= 0.0) then
            timeSteps[1] = 0.0
            timeSteps[2] = true
        end
    end
end

local function getRandomSolderStart(uniqueRequest)
    local randomSolderTexture
    local solderIndex
    repeat
        local unique = true
        local random = math.random(1, 3)
        if random == 1 then
            randomSolderTexture = 'PCB_Hack_StartSolder_Top'
        elseif random == 2 then
            randomSolderTexture = 'PCB_Hack_StartSolder_Middle'
        elseif random == 3 then
            randomSolderTexture = 'PCB_Hack_StartSolder_Bottom'
        end
        if uniqueRequest then
            for i = 1, #startSolders do
                if startSolders[i].texture == randomSolderTexture then
                    unique = false
                end
            end
        end
    until unique
    repeat
        local unique = true
        solderIndex = math.random(1,7)
        for i = 1, #startSolders do
            if startSolders[i].position == solderIndex then
                unique = false
            end
        end
    until unique
    return solderIndex, randomSolderTexture
end

local function getRandomSolderEnd(uniqueRequest)
    local randomSolderTexture
    local solderIndex
    repeat
        local unique = true
        local random = math.random(1, 3)
        if random == 1 then
            randomSolderTexture = 'PCB_Hack_EndSolder_Top'
        elseif random == 2 then
            randomSolderTexture = 'PCB_Hack_EndSolder_Middle'
        elseif random == 3 then
            randomSolderTexture = 'PCB_Hack_EndSolder_Bottom'
        end
        if uniqueRequest then
            for i = 1, #endSolders do
                if endSolders[i].texture == randomSolderTexture then
                    unique = false
                end
            end
        end
    until unique
    repeat
        local unique = true
        solderIndex = math.random(1,7)
        for i = 1, #endSolders do
            if endSolders[i].position == solderIndex then
                unique = false
            end
        end
    until unique
    return solderIndex, randomSolderTexture
end

local function drawSolder(textureName, screenXParam, screenY)
    DrawSprite('PCB_Hack_Assets_Foreground', textureName, adjustToRatio(screenXParam), screenY, (0.046875 * 1.788) / aspectRatio, 0.054166667, 0.0, 255, 255, 255, 255, false, 0)
end

local function drawLight(screenXParam, screenY, colorIdx)
    local colorTexture
    if colorIdx == 2 then
        colorTexture = 'PCB_Hack_GreenLight'
    elseif colorIdx == 1 then
        colorTexture = 'PCB_Hack_RedLight'
    elseif colorIdx == 0 then
        colorTexture = 'PCB_Hack_OffLight'
    end
    DrawSprite('PCB_Hack_Assets_Foreground', colorTexture, adjustToRatio(screenXParam), screenY, (0.042968754 * 1.788) / aspectRatio, 0.07638889, 0, 255, 255, 255, 255, false, 0)
end

local function drawBlocks()
    local fVar0 = 0.5 - (funcVal77 * (8 - 1))
    local fVar1 = (0.5 - ((funcVal76 / 2) * (3 - 1))) + funcVal75
    local fVar2 = fVar0 - (funcVal77 * 1.1)
    local fVar3 = 0.25
    local fVar4 = 0.5 + (funcVal77 * (8 - 1)) + (funcVal77 * 1.1)
    local fVar5 = 0.25;
    local fVar6 = (0.5 - 0.62);
    local fVar7 = 0.235;
    local fVar8 = (0.5 + 0.62);
    local fVar9 = 0.235;

    for i = 1, 8 do
        local blockTextureName = getBlockName(randomLevel, i)
        local currentPosition = currentBlockPos[i]
        DrawSprite(blockDict, blockTextureName, adjustToRatio(fVar0 + (funcVal77 * 2.0 * (i - 1))),
            (fVar1 + (funcVal76 * currentPosition)), funcVal64, funcVal63, 0.0, 255, 255, 255, 255, false, 1)
    end

    if currentSelected then
        DrawSprite('PCB_Hack_Assets_Foreground', 'PCB_Hack_Selection',
            adjustToRatio(fVar0 - 0.001 + (funcVal77 * 2.0 * (currentSelected - 1))),
            fVar1 - 0.002 + (funcVal76 * currentBlockPos[currentSelected]), funcVal60, funcVal59,
            0.0, 255, 255, 255, (1 - timeSteps[1]) * 100 + timeSteps[1] * 255, false, 0)
    end

    for k, v in pairs(startSolders) do
        drawSolder(v.texture, fVar2, fVar3 + (funcVal76 * v.position))
    end

    for k, v in pairs(endSolders) do
        drawSolder(v.texture, fVar4, fVar5 + (funcVal76 * v.position))
    end

    if state == 2 then
        if not resultCooldown then
            resultCooldown = GetGameTimer()
            for i = 1, #soundIds do
                StopSound(soundIds[i])
                ReleaseSoundId(soundIds[i])
            end
        elseif GetGameTimer() - resultCooldown < 1000 then
            drawLight(fVar6, fVar7, 2)
            drawLight(fVar8, fVar9, 2)
        else
            PlaySoundFrontend(-1, 'Success', 'DLC_24-2_Hack_Circuit_Board', true)
            setState(4)
        end
    elseif state == 3 then
        if not resultCooldown then
            resultCooldown = GetGameTimer()
            for i = 1, #soundIds do
                StopSound(soundIds[i])
                ReleaseSoundId(soundIds[i])
            end
            PlaySoundFrontend(-1, 'Error', 'DLC_24-2_Hack_Circuit_Board', true)
        elseif GetGameTimer() - resultCooldown < 2000 then
            drawLight(fVar6, fVar7, timeSteps[2] and 1 or 0)
            drawLight(fVar8, fVar9, timeSteps[2] and 1 or 0)
        else
            PlaySoundFrontend(-1, 'Fail', 'DLC_24-2_Hack_Circuit_Board', true)
            setState(5)
        end
    elseif state == 4 then
        if GetGameTimer() - resultCooldown < 4000 then
            drawResultText('HUD_SUCCESS', { 13, 118, 94 })
            DrawSprite('MPBeamHack', 'pass', 0.5, 0.5, ratioCalculate, 1.0, 0.0, 255, 255, 255, 255, false, 0)
        else
            setState(6)
        end
    elseif state == 5 then
        if GetGameTimer() - resultCooldown < 5000 then
            drawResultText(gameBuild >= 3095 and 'BEAM_F' or 'PCB_FAIL', { 237, 35, 54 })
            DrawSprite('MPBeamHack', 'fail', 0.5, 0.5, ratioCalculate, 1.0, 0.0, 255, 255, 255, 255, false, 0)
        else
            setState(7)
        end
    else
        if currentSelected and currentBlockPos[currentSelected] then
            if IsDisabledControlJustPressed(0, 173) and currentBlockPos[currentSelected] < 2 then
                PlaySoundFrontend(-1, 'Move_Circuit_Up', 'DLC_24-2_Hack_Circuit_Board', true)
                currentBlockPos[currentSelected] = currentBlockPos[currentSelected] + 1
            end
            if IsDisabledControlJustPressed(0, 172) and currentBlockPos[currentSelected] > 0 then
                PlaySoundFrontend(-1, 'Move_Circuit_Down', 'DLC_24-2_Hack_Circuit_Board', true)
                currentBlockPos[currentSelected] = currentBlockPos[currentSelected] - 1
            end
            if IsDisabledControlJustPressed(0, 175) and currentSelected < 8 then
                currentSelected = currentSelected + 1
                PlaySoundFrontend(-1, 'Nav', 'DLC_24-2_Hack_Circuit_Board', true)
            end
            if IsDisabledControlJustPressed(0, 174) and currentSelected > 1 then
                currentSelected = currentSelected - 1
                PlaySoundFrontend(-1, 'Nav', 'DLC_24-2_Hack_Circuit_Board', true)
            end
        end
        if IsDisabledControlJustPressed(0, 201) then
            PlaySoundFrontend(-1, 'Test', 'DLC_24-2_Hack_Circuit_Board', true)
            if checkAllBlocks() then
                setState(2)
            else
                PlaySoundFrontend(-1, 'Error', 'DLC_24-2_Hack_Circuit_Board', true)
                if cfg.failOnConfirm then
                    setState(3)
                end
            end
        end

        if IsDisabledControlJustPressed(0, 202) then
            setState(3)
        end

        drawLight(fVar6, fVar7, 2)
        if (checkAllBlocks()) then
            drawLight(fVar8, fVar9, timeSteps[2] and 2 or 0)
        else
            drawLight(fVar8, fVar9, 0)
        end
    end
end

function startMinigame(solderCount, seconds, cb)
    if minigameStatus then return cb(false) end
    
    minigameStatus = true
    aspectRatio = GetAspectRatio(false)
    ratioCalculate = 1.778 / aspectRatio

    randomLevel = math.random(0, 9)
    currentSelected = 1
    currentBlockPos = {}
    state = 0
    resultCooldown = nil
    startSolders = {}
    endSolders = {}
    finishTime = GetGameTimer() + (seconds or cfg.defaultSec) * 1000

    local _, endSolderTexture = getRandomSolderEnd()
    local _, startSolderTexture = getRandomSolderStart()
    startSolders[1] = {texture = startSolderTexture, position = positionsConfig[randomLevel+1].solder[1]}
    endSolders[1] = {texture = endSolderTexture, position = positionsConfig[randomLevel+1].solder[2]}

    if not solderCount or solderCount < 1 then
        solderCount = 1
    elseif solderCount > 7 then
        solderCount = 7
    end

    local unique = solderCount <= 3 and true or false

    for i = 1, solderCount-1 do
        local endSolderIndex, endSolderTexture = getRandomSolderEnd(unique)
        local startSolderIndex, startSolderTexture = getRandomSolderStart(unique)
        startSolders[#startSolders+1] = {texture = startSolderTexture, position = startSolderIndex}
        endSolders[#endSolders+1] = {texture = endSolderTexture, position = endSolderIndex}
    end

    CreateThread(function()
        local scaleform = setupHelperText()
        while true do
            Wait(0)

            if state == 0 then
                requestDicts()
            elseif state == 1 or state == 2 or state == 3 or state == 4 or state == 5 then
                drawBackground()
                timeStepFunct()
                drawBlocks()
                if state == 1 or state == 2 or state == 3 then
                    drawTimerText()
                    drawHelperText(scaleform)
                end
                disableControls()
            elseif state == 6 then
                freeDicts()
                minigameStatus = false
                cb(true)
                break
            elseif state == 7 then
                freeDicts()
                minigameStatus = false
                cb(false)
                break
            end
        end
    end)
end

function finishGame()
    minigameStatus = false
    setState(7)
    freeDicts()
end

function setState(stateVal)
    state = stateVal
end

function getBlockDict(index)
    local base = 'PCB_Hack_Assets_LevelBlocks'
    if index > 0 then
        base = base .. '_' .. index
    end
    return base
end

function getBlockName(index, block)
    local name
    if index == 0 then
        name = 'PCB_Hack_Block' .. block
    else
        name = 'PCB_Hack' .. index .. '_Block' .. block
    end
    return name
end

function checkAllBlocks()
    for i = 1, 8 do
        if currentBlockPos[i] ~= positionsConfig[randomLevel+1].block[i] then
            return false
        end
    end
    return true
end

function adjustToRatio(value)
    return (0.5 - ((0.5 - value) / aspectRatio))
end

exports('startMinigame', startMinigame)
exports('finishMinigame', finishGame)
