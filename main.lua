-- Remote Renamer для SimpleSpy
-- Переименовывает RemoteEvent и RemoteFunction в их Calling Script

-- Добавляем кнопку в SimpleSpy
local function addRemoteRenamerButton()
    SimpleSpy:newButton(
        "Rename Remotes",
        function() return "Переименовать все RemoteEvent/RemoteFunction в их Calling Script" end,
        function()
            renameAllRemotesFromLogs()
        end
    )
end

-- Основная функция переименования на основе логов SimpleSpy
local function renameAllRemotesFromLogs()
    TextLabel.Text = "Начинаю переименование..."
    
    local renamedCount = 0
    local failedCount = 0
    
    -- Используем логи SimpleSpy для получения информации о calling script
    for _, log in pairs(logs) do
        if log and log.Remote and (log.Remote:IsA("RemoteEvent") or log.Remote:IsA("RemoteFunction")) then
            local remote = log.Remote
            local callingScript = log.Source
            
            if callingScript and typeof(callingScript) == "Instance" then
                -- Получаем имя скрипта
                local scriptName = callingScript.Name
                
                -- Создаем новое имя для remote
                local newName = scriptName .. "_" .. remote.ClassName
                
                -- Переименовываем remote
                pcall(function()
                    local oldName = remote.Name
                    remote.Name = newName
                    
                    print(string.format("[RemoteRenamer] ✓ %s.%s -> %s", 
                        remote.ClassName, oldName, newName))
                    
                    renamedCount = renamedCount + 1
                end)
            else
                failedCount = failedCount + 1
                print(string.format("[RemoteRenamer] ! Не удалось получить calling script для %s", 
                    remote:GetFullName()))
            end
        end
    end
    
    -- Также ищем ремоуты, которые не были в логах
    local function findAndRenameRemainingRemotes()
        local containers = {
            game:GetService("ReplicatedStorage"),
            game:GetService("ServerStorage"),
            game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"),
            game:GetService("StarterPlayer"):WaitForChild("StarterCharacterScripts"),
            Players.LocalPlayer:WaitForChild("PlayerScripts"),
            game:GetService("StarterGui"),
            game:GetService("Workspace")
        }
        
        for _, container in pairs(containers) do
            pcall(function()
                for _, remote in pairs(container:GetDescendants()) do
                    if (remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction")) then
                        local alreadyRenamed = false
                        
                        -- Проверяем, не переименовывали ли мы уже этот remote
                        for _, log in pairs(logs) do
                            if log and log.Remote == remote then
                                alreadyRenamed = true
                                break
                            end
                        end
                        
                        -- Если не нашли в логах, пытаемся найти связанный скрипт
                        if not alreadyRenamed then
                            local remotePath = remote:GetFullName()
                            
                            -- Попробуем найти скрипт по пути remote
                            local function findScriptByPath()
                                for _, script in pairs(game:GetDescendants()) do
                                    if script:IsA("LocalScript") or script:IsA("Script") or script:IsA("ModuleScript") then
                                        pcall(function()
                                            local source = ""
                                            if script:IsA("ModuleScript") then
                                                source = script.Source
                                            elseif script:IsA("LocalScript") or script:IsA("Script") then
                                                source = script:GetFullName()
                                            end
                                            
                                            -- Ищем упоминание remote в пути или исходном коде
                                            if string.find(source, remote.Name) then
                                                return script.Name
                                            end
                                        end)
                                    end
                                end
                                return nil
                            end
                            
                            local scriptName = findScriptByPath()
                            
                            if scriptName then
                                local newName = scriptName .. "_" .. remote.ClassName
                                pcall(function()
                                    local oldName = remote.Name
                                    remote.Name = newName
                                    
                                    print(string.format("[RemoteRenamer] ✓ (поиск) %s.%s -> %s", 
                                        remote.ClassName, oldName, newName))
                                    
                                    renamedCount = renamedCount + 1
                                end)
                            else
                                failedCount = failedCount + 1
                            end
                        end
                    end
                end
            end)
        end
    end
    
    -- Ищем оставшиеся ремоуты
    findAndRenameRemainingRemotes()
    
    -- Обновляем UI
    TextLabel.Text = string.format("Готово! Переименовано: %d, Не удалось: %d", renamedCount, failedCount)
    
    -- Обновляем кнопки в логах (если нужно)
    if selected then
        eventSelect(selected.Log)
    end
    
    return renamedCount
end

-- Функция для переименования конкретного remote
local function renameRemote(remote, callingScript)
    if not remote or not callingScript then
        return false
    end
    
    local success = pcall(function()
        local oldName = remote.Name
        local newName = callingScript.Name .. "_" .. remote.ClassName
        remote.Name = newName
        
        -- Обновляем логи SimpleSpy
        for _, log in pairs(logs) do
            if log and log.Remote == remote then
                log.Name = newName
                if log.Log and log.Log:FindFirstChild("Text") then
                    log.Log.Text.Text = newName
                end
            end
        end
        
        print(string.format("[RemoteRenamer] Переименован: %s -> %s", oldName, newName))
    end)
    
    return success
end

-- Кнопка для переименования выбранного remote
local function addSingleRemoteRenamerButton()
    SimpleSpy:newButton(
        "Rename This Remote",
        function() 
            if selected and selected.Remote and selected.Source then
                return "Переименовать выбранный Remote в: " .. selected.Source.Name
            else
                return "Выберите Remote для переименования"
            end
        end,
        function()
            if selected and selected.Remote and selected.Source then
                local success = renameRemote(selected.Remote, selected.Source)
                if success then
                    TextLabel.Text = "Remote переименован!"
                    -- Обновляем кнопку
                    eventSelect(selected.Log)
                else
                    TextLabel.Text = "Ошибка при переименовании"
                end
            else
                TextLabel.Text = "Выберите Remote для переименования"
            end
        end
    )
end

-- Автоматическое переименование при новом логе
local originalRemoteHandler = remoteHandler
function remoteHandler(data)
    -- Вызываем оригинальную функцию
    originalRemoteHandler(data)
    
    -- Автоматически переименовываем новый remote
    if data and data.remote and data.callingscript then
        renameRemote(data.remote, data.callingscript)
    end
end

-- GUI для ручного управления
local function createRemoteRenamerGUI()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "SimpleSpyRemoteRenamer"
    ScreenGui.Parent = SimpleSpy3
    
    local MainFrame = Instance.new("Frame")
    MainFrame.Size = UDim2.new(0, 250, 0, 150)
    MainFrame.Position = UDim2.new(0.5, -125, 0.5, -75)
    MainFrame.BackgroundColor3 = Color3.fromRGB(37, 36, 38)
    MainFrame.BorderSizePixel = 0
    MainFrame.Parent = ScreenGui
    
    local Title = Instance.new("TextLabel")
    Title.Text = "Remote Renamer"
    Title.Size = UDim2.new(1, 0, 0, 30)
    Title.BackgroundColor3 = Color3.fromRGB(53, 52, 55)
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.Font = Enum.Font.SourceSansBold
    Title.TextSize = 16
    Title.Parent = MainFrame
    
    local RenameAllButton = Instance.new("TextButton")
    RenameAllButton.Text = "Переименовать все"
    RenameAllButton.Size = UDim2.new(0.8, 0, 0, 30)
    RenameAllButton.Position = UDim2.new(0.1, 0, 0.3, 0)
    RenameAllButton.BackgroundColor3 = Color3.fromRGB(92, 126, 229)
    RenameAllButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    RenameAllButton.Parent = MainFrame
    
    local AutoRenameToggle = Instance.new("TextButton")
    AutoRenameToggle.Text = "Авто-переименование: ВКЛ"
    AutoRenameToggle.Size = UDim2.new(0.8, 0, 0, 30)
    AutoRenameToggle.Position = UDim2.new(0.1, 0, 0.6, 0)
    AutoRenameToggle.BackgroundColor3 = Color3.fromRGB(68, 206, 91)
    AutoRenameToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    AutoRenameToggle.Parent = MainFrame
    
    local StatusLabel = Instance.new("TextLabel")
    StatusLabel.Text = "Готов"
    StatusLabel.Size = UDim2.new(1, 0, 0, 20)
    StatusLabel.Position = UDim2.new(0, 0, 0.9, 0)
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    StatusLabel.TextSize = 12
    StatusLabel.Parent = MainFrame
    
    -- Обработчики событий
    local autoRenameEnabled = true
    
    RenameAllButton.MouseButton1Click:Connect(function()
        StatusLabel.Text = "Работаю..."
        local count = renameAllRemotesFromLogs()
        StatusLabel.Text = "Готово! " .. tostring(count) .. " переименовано"
    end)
    
    AutoRenameToggle.MouseButton1Click:Connect(function()
        autoRenameEnabled = not autoRenameEnabled
        if autoRenameEnabled then
            AutoRenameToggle.Text = "Авто-переименование: ВКЛ"
            AutoRenameToggle.BackgroundColor3 = Color3.fromRGB(68, 206, 91)
        else
            AutoRenameToggle.Text = "Авто-переименование: ВЫКЛ"
            AutoRenameToggle.BackgroundColor3 = Color3.fromRGB(206, 68, 68)
        end
    end)
    
    -- Делаем фрейм перетаскиваемым
    local dragging
    local dragInput
    local dragStart
    local startPos
    
    MainFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    MainFrame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(
                startPos.X.Scale, 
                startPos.X.Offset + delta.X,
                startPos.Y.Scale, 
                startPos.Y.Offset + delta.Y
            )
        end
    end)
    
    -- Кнопка закрытия
    local CloseButton = Instance.new("TextButton")
    CloseButton.Text = "X"
    CloseButton.Size = UDim2.new(0, 25, 0, 25)
    CloseButton.Position = UDim2.new(1, -25, 0, 0)
    CloseButton.BackgroundColor3 = Color3.fromRGB(206, 68, 68)
    CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseButton.Parent = MainFrame
    
    CloseButton.MouseButton1Click:Connect(function()
        ScreenGui:Destroy()
    end)
    
    return ScreenGui
end

-- Инициализация
local function initRemoteRenamer()
    -- Добавляем кнопки в SimpleSpy
    addRemoteRenamerButton()
    addSingleRemoteRenamerButton()
    
    -- Создаем GUI
    createRemoteRenamerGUI()
    
    print("[RemoteRenamer] Загружен и готов к работе!")
    print("[RemoteRenamer] Используйте кнопку 'Rename Remotes' в SimpleSpy")
end

-- Запускаем после загрузки SimpleSpy
if getgenv().SimpleSpyExecuted then
    spawn(function()
        wait(1) -- Даем SimpleSpy полностью загрузиться
        initRemoteRenamer()
    end)
else
    -- Ждем загрузки SimpleSpy
    local connection
    connection = game:GetService("RunService").Heartbeat:Connect(function()
        if getgenv().SimpleSpyExecuted then
            connection:Disconnect()
            wait(0.5)
            initRemoteRenamer()
        end
    end)
end

-- Экспортируем функции
getgenv().RemoteRenamer = {
    renameAll = renameAllRemotesFromLogs,
    renameRemote = renameRemote,
    showGUI = createRemoteRenamerGUI
}
