-- Remote Renamer для SimpleSpy
-- Переименовывает RemoteEvent и RemoteFunction в их Calling Script

-- Получаем необходимые сервисы
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Добавляем кнопку в SimpleSpy
local function addRemoteRenamerButton()
    if SimpleSpy and SimpleSpy.newButton then
        SimpleSpy:newButton(
            "Rename Remotes",
            function() return "Переименовать все RemoteEvent/RemoteFunction в их Calling Script" end,
            function()
                renameAllRemotesFromLogs()
            end
        )
    else
        warn("[RemoteRenamer] SimpleSpy не найден!")
    end
end

-- Основная функция переименования на основе логов SimpleSpy
local function renameAllRemotesFromLogs()
    if not TextLabel then
        warn("[RemoteRenamer] TextLabel не найден!")
        return 0
    end
    
    TextLabel.Text = "Начинаю переименование..."
    
    local renamedCount = 0
    local failedCount = 0
    
    -- Проверяем, что logs существует
    if not logs then
        TextLabel.Text = "Логи SimpleSpy не найдены!"
        return 0
    end
    
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
                    
                    -- Обновляем лог в SimpleSpy
                    if log.Log and log.Log:FindFirstChild("Text") then
                        log.Log.Text.Text = newName
                    end
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
                        if logs then
                            for _, log in pairs(logs) do
                                if log and log.Remote == remote then
                                    alreadyRenamed = true
                                    break
                                end
                            end
                        end
                        
                        -- Если не нашли в логах, пытаемся найти связанный скрипт
                        if not alreadyRenamed then
                            -- Попробуем найти скрипт по пути remote
                            local function findScriptByPath()
                                for _, script in pairs(game:GetDescendants()) do
                                    if script:IsA("LocalScript") or script:IsA("Script") or script:IsA("ModuleScript") then
                                        pcall(function()
                                            -- Ищем упоминание remote в имени скрипта
                                            if string.find(script.Name, remote.Name) or 
                                               string.find(remote.Name, script.Name) then
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
        if logs then
            for _, log in pairs(logs) do
                if log and log.Remote == remote then
                    log.Name = newName
                    if log.Log and log.Log:FindFirstChild("Text") then
                        log.Log.Text.Text = newName
                    end
                end
            end
        end
        
        print(string.format("[RemoteRenamer] Переименован: %s -> %s", oldName, newName))
    end)
    
    return success
end

-- Кнопка для переименования выбранного remote
local function addSingleRemoteRenamerButton()
    if SimpleSpy and SimpleSpy.newButton then
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
                if TextLabel then
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
            end
        )
    end
end

-- Упрощенное GUI (без перетаскивания, чтобы избежать ошибок)
local function createRemoteRenamerGUI()
    if not SimpleSpy3 then
        warn("[RemoteRenamer] SimpleSpy3 не найден!")
        return nil
    end
    
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "SimpleSpyRemoteRenamer"
    ScreenGui.Parent = SimpleSpy3
    ScreenGui.ResetOnSpawn = false
    
    local MainFrame = Instance.new("Frame")
    MainFrame.Size = UDim2.new(0, 250, 0, 150)
    MainFrame.Position = UDim2.new(0.5, -125, 0.3, -75)
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
    
    local CloseButton = Instance.new("TextButton")
    CloseButton.Text = "Закрыть"
    CloseButton.Size = UDim2.new(0.8, 0, 0, 30)
    CloseButton.Position = UDim2.new(0.1, 0, 0.6, 0)
    CloseButton.BackgroundColor3 = Color3.fromRGB(206, 68, 68)
    CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseButton.Parent = MainFrame
    
    local StatusLabel = Instance.new("TextLabel")
    StatusLabel.Text = "Готов к работе"
    StatusLabel.Size = UDim2.new(1, 0, 0, 20)
    StatusLabel.Position = UDim2.new(0, 0, 0.9, 0)
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    StatusLabel.TextSize = 12
    StatusLabel.Parent = MainFrame
    
    -- Обработчики событий
    RenameAllButton.MouseButton1Click:Connect(function()
        StatusLabel.Text = "Работаю..."
        local count = renameAllRemotesFromLogs()
        StatusLabel.Text = "Готово! " .. tostring(count) .. " переименовано"
    end)
    
    CloseButton.MouseButton1Click:Connect(function()
        ScreenGui:Destroy()
    end)
    
    -- Простая возможность перемещения (клик на заголовок)
    local dragging = false
    local dragStart = Vector2.new(0, 0)
    local frameStart = Vector2.new(0, 0)
    
    Title.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = Vector2.new(input.Position.X, input.Position.Y)
            frameStart = Vector2.new(MainFrame.Position.X.Offset, MainFrame.Position.Y.Offset)
        end
    end)
    
    Title.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local mousePos = UserInputService:GetMouseLocation()
            local delta = mousePos - dragStart
            MainFrame.Position = UDim2.new(
                0, frameStart.X + delta.X,
                0, frameStart.Y + delta.Y
            )
        end
    end)
    
    return ScreenGui
end

-- Функция для добавления кнопки в интерфейс SimpleSpy
local function addButtonToSimpleSpyInterface()
    -- Создаем свою кнопку в интерфейсе SimpleSpy
    local function createSimpleSpyButton()
        local ButtonTemplate = Create("Frame",{
            Name = "RemoteRenamerButton",
            Parent = ScrollingFrame,
            BackgroundColor3 = Color3.new(1, 1, 1),
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 117, 0, 23)
        })
        
        local ColorBar = Create("Frame",{
            Name = "ColorBar",
            Parent = ButtonTemplate,
            BackgroundColor3 = Color3.new(0, 1, 0),
            BorderSizePixel = 0,
            Position = UDim2.new(0, 7, 0, 10),
            Size = UDim2.new(0, 7, 0, 18),
            ZIndex = 3
        })
        
        local Text = Create("TextLabel",{
            Text = "Remote Renamer",
            Name = "Text",
            Parent = ButtonTemplate,
            BackgroundColor3 = Color3.new(1, 1, 1),
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 19, 0, 10),
            Size = UDim2.new(0, 69, 0, 18),
            ZIndex = 2,
            Font = Enum.Font.SourceSans,
            TextColor3 = Color3.new(1, 1, 1),
            TextSize = 14,
            TextStrokeColor3 = Color3.fromRGB(37, 36, 38),
            TextXAlignment = Enum.TextXAlignment.Left
        })
        
        local Button = Create("TextButton",{
            Name = "Button",
            Parent = ButtonTemplate,
            BackgroundColor3 = Color3.new(0, 0, 0),
            BackgroundTransparency = 0.7,
            BorderColor3 = Color3.new(1, 1, 1),
            Position = UDim2.new(0, 7, 0, 10),
            Size = UDim2.new(0, 80, 0, 18),
            AutoButtonColor = false,
            Font = Enum.Font.SourceSans,
            Text = "",
            TextColor3 = Color3.new(0, 0, 0),
            TextSize = 14
        })
        
        Button.MouseEnter:Connect(function()
            makeToolTip(true, "Переименовать все RemoteEvent/RemoteFunction в их Calling Script")
        end)
        
        Button.MouseLeave:Connect(function()
            makeToolTip(false)
        end)
        
        ButtonTemplate.AncestryChanged:Connect(function()
            makeToolTip(false)
        end)
        
        Button.MouseButton1Click:Connect(function()
            renameAllRemotesFromLogs()
        end)
        
        updateFunctionCanvas()
    end
    
    -- Пробуем создать кнопку
    pcall(createSimpleSpyButton)
end

-- Инициализация
local function initRemoteRenamer()
    -- Ждем, пока SimpleSpy полностью загрузится
    wait(2)
    
    -- Пробуем разные способы добавления функционала
    if SimpleSpy and SimpleSpy.newButton then
        -- Способ 1: через API SimpleSpy
        addRemoteRenamerButton()
        addSingleRemoteRenamerButton()
        print("[RemoteRenamer] Кнопки добавлены через SimpleSpy API")
    elseif ScrollingFrame then
        -- Способ 2: напрямую в интерфейс
        addButtonToSimpleSpyInterface()
        print("[RemoteRenamer] Кнопка добавлена напрямую в интерфейс")
    else
        print("[RemoteRenamer] Не удалось найти интерфейс SimpleSpy")
    end
    
    -- Создаем GUI
    local gui = createRemoteRenamerGUI()
    if gui then
        print("[RemoteRenamer] GUI создан успешно")
    end
    
    print("[RemoteRenamer] Загружен и готов к работе!")
end

-- Автоматический запуск
spawn(function()
    -- Ждем загрузки SimpleSpy
    local maxWait = 30 -- максимум 30 секунд ожидания
    local waited = 0
    
    while waited < maxWait do
        if getgenv().SimpleSpyExecuted then
            wait(1) -- Даем SimpleSpy полностью инициализироваться
            initRemoteRenamer()
            break
        end
        wait(1)
        waited = waited + 1
    end
    
    if waited >= maxWait then
        warn("[RemoteRenamer] Timeout: SimpleSpy не загрузился за " .. maxWait .. " секунд")
    end
end)

-- Экспортируем функции
getgenv().RemoteRenamer = {
    renameAll = renameAllRemotesFromLogs,
    renameRemote = renameRemote,
    showGUI = createRemoteRenamerGUI
}
