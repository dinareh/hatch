-- Скрипт для переименования RemoteEvent и RemoteFunction в их Calling Script
-- Совместим с SimpleSpy V3

local function renameRemotesToCallingScript()
    -- Проверяем, запущен ли SimpleSpy
    if not getgenv().SimpleSpyExecuted then
        warn("❌ SimpleSpy V3 не запущен!")
        return false, "SimpleSpy V3 не запущен"
    end
    
    print("🔍 Начинаю переименование ремоутов в Calling Script...")
    
    local renamedCount = 0
    local skippedCount = 0
    
    -- Используем глобальные переменные SimpleSpy
    local logs = getgenv().SimpleSpy and getgenv().SimpleSpy.logs
    
    if not logs or type(logs) ~= "table" then
        -- Попробуем получить логи из локальной переменной SimpleSpy
        local success, result = pcall(function()
            return require(game:GetService("CoreGui"):WaitForChild("SimpleSpy3"):WaitForChild("SimpleSpy")).logs
        end)
        
        if not success then
            print("⚠️ Не удалось получить доступ к логам SimpleSpy")
            print("Попытка найти логи другим способом...")
            
            -- Ищем SimpleSpy3 в CoreGui
            local simpleSpyGui = game:GetService("CoreGui"):FindFirstChild("SimpleSpy3")
            if simpleSpyGui then
                print("✅ Найден SimpleSpy3 в CoreGui")
                -- Здесь можно добавить дополнительную логику для доступа к логам
            end
            return false, "Не удалось получить доступ к логам SimpleSpy"
        end
        logs = result
    end
    
    if not logs or #logs == 0 then
        print("ℹ️ Логи SimpleSpy пусты. Сначала перехватите несколько ремоутов.")
        return false, "Логи пусты"
    end
    
    print("📊 Найдено записей в логах: " .. #logs)
    
    -- Функция для безопасного получения имени из скрипта
    local function getScriptName(scriptInstance)
        if not scriptInstance or typeof(scriptInstance) ~= "Instance" then
            return "UnknownScript"
        end
        
        -- Пытаемся получить понятное имя
        local name = scriptInstance.Name
        if name and name ~= "" then
            return name
        end
        
        -- Если имя пустое, используем имя класса
        return scriptInstance.ClassName
    end
    
    -- Функция для создания безопасного имени
    local function createSafeName(baseName, remoteType)
        -- Убираем недопустимые символы
        local safeName = baseName:gsub("[^%w_]", "_")
        
        -- Убедимся, что имя не пустое
        if safeName == "" or safeName == "_" then
            safeName = "Script"
        end
        
        -- Добавляем тип ремоута
        safeName = safeName .. "_" .. remoteType
        
        -- Ограничиваем длину (максимум 50 символов)
        if #safeName > 50 then
            safeName = safeName:sub(1, 50)
        end
        
        return safeName
    end
    
    -- Обрабатываем каждый лог
    for i, log in ipairs(logs) do
        if log and log.Remote and (log.Remote:IsA("RemoteEvent") or log.Remote:IsA("RemoteFunction") or log.Remote:IsA("UnreliableRemoteEvent")) then
            
            -- Получаем Calling Script из лога
            local callingScript = log.Source
            
            if callingScript and typeof(callingScript) == "Instance" then
                -- Получаем имя скрипта
                local scriptName = getScriptName(callingScript)
                local remoteType = log.Remote.ClassName
                
                -- Создаем новое имя
                local newName = createSafeName(scriptName, remoteType)
                local oldName = log.Remote.Name
                
                -- Проверяем, отличается ли имя
                if oldName ~= newName then
                    -- Пытаемся переименовать
                    local success, errorMsg = pcall(function()
                        log.Remote.Name = newName
                    end)
                    
                    if success then
                        renamedCount = renamedCount + 1
                        print(string.format("✅ [%d] %s -> %s", i, oldName, newName))
                        print(string.format("   📁 Calling Script: %s (%s)", 
                            callingScript:GetFullName(), callingScript.ClassName))
                    else
                        skippedCount = skippedCount + 1
                        print(string.format("⚠️ [%d] Ошибка переименования %s: %s", 
                            i, oldName, errorMsg))
                    end
                else
                    skippedCount = skippedCount + 1
                    print(string.format("ℹ️ [%d] Пропущен: %s (уже имеет правильное имя)", i, oldName))
                end
            else
                skippedCount = skippedCount + 1
                print(string.format("❌ [%d] Не найден Calling Script для: %s", 
                    i, log.Remote.Name))
            end
        end
    end
    
    -- Итоговая статистика
    print("\n" .. string.rep("=", 50))
    print("📊 ИТОГ ПЕРЕИМЕНОВАНИЯ:")
    print("✅ Успешно переименовано: " .. renamedCount)
    print("⚠️ Пропущено/Ошибок: " .. skippedCount)
    print("📈 Всего обработано: " .. (renamedCount + skippedCount))
    print(string.rep("=", 50))
    
    if renamedCount > 0 then
        return true, "Успешно переименовано " .. renamedCount .. " ремоутов"
    else
        return false, "Не удалось переименовать ремоуты"
    end
end

-- Функция для переименования всех ремоутов в игре на основе их родительских скриптов
local function renameAllRemotesInGameByParent()
    print("🔍 Поиск всех ремоутов в игре для переименования...")
    
    local renamedCount = 0
    local skippedCount = 0
    
    -- Рекурсивная функция поиска ремоутов
    local function findAndRenameRemotes(object)
        if object:IsA("RemoteEvent") or object:IsA("RemoteFunction") or object:IsA("UnreliableRemoteEvent") then
            -- Ищем ближайший родительский скрипт
            local current = object.Parent
            local parentScript = nil
            
            while current and current ~= game do
                if current:IsA("Script") or current:IsA("LocalScript") or current:IsA("ModuleScript") then
                    parentScript = current
                    break
                end
                current = current.Parent
            end
            
            local oldName = object.Name
            local remoteType = object.ClassName
            
            if parentScript then
                -- Используем имя родительского скрипта
                local scriptName = parentScript.Name
                if scriptName == "" then
                    scriptName = parentScript.ClassName
                end
                
                local newName = scriptName .. "_" .. remoteType
                newName = newName:gsub("[^%w_]", "_")
                
                if oldName ~= newName then
                    local success, errorMsg = pcall(function()
                        object.Name = newName
                    end)
                    
                    if success then
                        renamedCount = renamedCount + 1
                        print(string.format("✅ %s -> %s", oldName, newName))
                        print(string.format("   📁 Родительский скрипт: %s", parentScript:GetFullName()))
                    else
                        skippedCount = skippedCount + 1
                        print(string.format("⚠️ Ошибка переименования %s: %s", oldName, errorMsg))
                    end
                else
                    skippedCount = skippedCount + 1
                end
            else
                skippedCount = skippedCount + 1
                print(string.format("ℹ️ Не найден родительский скрипт для: %s", object:GetFullName()))
            end
        end
        
        -- Рекурсивно обходим дочерние объекты
        for _, child in ipairs(object:GetChildren()) do
            findAndRenameRemotes(child)
        end
    end
    
    -- Начинаем поиск
    findAndRenameRemotes(game)
    
    print("\n" .. string.rep("=", 50))
    print("📊 ИТОГ ПЕРЕИМЕНОВАНИЯ В ИГРЕ:")
    print("✅ Успешно переименовано: " .. renamedCount)
    print("⚠️ Пропущено: " .. skippedCount)
    print("📈 Всего найдено ремоутов: " .. (renamedCount + skippedCount))
    print(string.rep("=", 50))
    
    return renamedCount
end

-- Функция для интеграции с SimpleSpy V3
local function integrateWithSimpleSpy()
    if not getgenv().SimpleSpyExecuted then
        print("⏳ Ожидание загрузки SimpleSpy...")
        return false
    end
    
    -- Проверяем, не добавлены ли кнопки уже
    if getgenv().SimpleSpyRenameButtonsAdded then
        print("ℹ️ Кнопки уже добавлены в SimpleSpy")
        return true
    end
    
    -- Ждем полной загрузки SimpleSpy
    local maxAttempts = 10
    local attempts = 0
    
    while attempts < maxAttempts do
        attempts = attempts + 1
        
        -- Пытаемся получить доступ к SimpleSpy
        local success, simpleSpy = pcall(function()
            return getgenv().SimpleSpy
        end)
        
        if success and simpleSpy and type(simpleSpy.newButton) == "function" then
            print("✅ Найден SimpleSpy API, добавляю кнопки...")
            
            -- Добавляем первую кнопку
            simpleSpy:newButton(
                "Rename to Calling Script",
                function()
                    return "Переименовать ремоуты в их Calling Script\nИспользует Calling Script из логов SimpleSpy"
                end,
                function(button)
                    local success, result = renameRemotesToCallingScript()
                    if success then
                        -- Обновляем текст в SimpleSpy
                        if getgenv().SimpleSpy and getgenv().SimpleSpy.TextLabel then
                            getgenv().SimpleSpy.TextLabel.Text = "✅ " .. result
                        end
                    else
                        if getgenv().SimpleSpy and getgenv().SimpleSpy.TextLabel then
                            getgenv().SimpleSpy.TextLabel.Text = "❌ " .. result
                        end
                    end
                end
            )
            
            -- Добавляем вторую кнопку
            simpleSpy:newButton(
                "Rename All Game Remotes",
                function()
                    return "Переименовать ВСЕ ремоуты в игре\nНа основе родительских скриптов"
                end,
                function(button)
                    local count = renameAllRemotesInGameByParent()
                    if count > 0 then
                        if getgenv().SimpleSpy and getgenv().SimpleSpy.TextLabel then
                            getgenv().SimpleSpy.TextLabel.Text = string.format("✅ Переименовано %d ремоутов в игре!", count)
                        end
                    else
                        if getgenv().SimpleSpy and getgenv().SimpleSpy.TextLabel then
                            getgenv().SimpleSpy.TextLabel.Text = "ℹ️ Ремоуты не найдены или уже переименованы"
                        end
                    end
                end
            )
            
            getgenv().SimpleSpyRenameButtonsAdded = true
            print("✅ Кнопки успешно добавлены в SimpleSpy!")
            return true
        end
        
        wait(0.5)
    end
    
    print("❌ Не удалось добавить кнопки в SimpleSpy")
    return false
end

-- Функция для создания отдельного интерфейса (если SimpleSpy не найден)
local function createStandaloneUI()
    print("🖥️ Создаю отдельный интерфейс...")
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "RemoteRenamerUI"
    screenGui.Parent = game:GetService("CoreGui")
    
    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 300, 0, 200)
    mainFrame.Position = UDim2.new(0.5, -150, 0.5, -100)
    mainFrame.BackgroundColor3 = Color3.fromRGB(37, 36, 38)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    
    local title = Instance.new("TextLabel")
    title.Text = "Remote Renamer"
    title.Size = UDim2.new(1, 0, 0, 30)
    title.BackgroundColor3 = Color3.fromRGB(53, 52, 55)
    title.TextColor3 = Color3.new(1, 1, 1)
    title.Font = Enum.Font.SourceSansBold
    title.TextSize = 16
    title.Parent = mainFrame
    
    local renameButton1 = Instance.new("TextButton")
    renameButton1.Text = "Переименовать по Calling Script"
    renameButton1.Size = UDim2.new(0.9, 0, 0, 40)
    renameButton1.Position = UDim2.new(0.05, 0, 0.2, 0)
    renameButton1.BackgroundColor3 = Color3.fromRGB(92, 126, 229)
    renameButton1.TextColor3 = Color3.new(1, 1, 1)
    renameButton1.Parent = mainFrame
    
    local renameButton2 = Instance.new("TextButton")
    renameButton2.Text = "Переименовать все в игре"
    renameButton2.Size = UDim2.new(0.9, 0, 0, 40)
    renameButton2.Position = UDim2.new(0.05, 0, 0.5, 0)
    renameButton2.BackgroundColor3 = Color3.fromRGB(92, 126, 229)
    renameButton2.TextColor3 = Color3.new(1, 1, 1)
    renameButton2.Parent = mainFrame
    
    local closeButton = Instance.new("TextButton")
    closeButton.Text = "Закрыть"
    closeButton.Size = UDim2.new(0.9, 0, 0, 30)
    closeButton.Position = UDim2.new(0.05, 0, 0.8, 0)
    closeButton.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
    closeButton.TextColor3 = Color3.new(1, 1, 1)
    closeButton.Parent = mainFrame
    
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Text = "Готов к работе"
    statusLabel.Size = UDim2.new(0.9, 0, 0, 20)
    statusLabel.Position = UDim2.new(0.05, 0, 0.9, 0)
    statusLabel.BackgroundTransparency = 1
    statusLabel.TextColor3 = Color3.new(1, 1, 1)
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.Parent = mainFrame
    
    -- Обработчики кнопок
    renameButton1.MouseButton1Click:Connect(function()
        statusLabel.Text = "Выполняется..."
        local success, result = renameRemotesToCallingScript()
        statusLabel.Text = result
    end)
    
    renameButton2.MouseButton1Click:Connect(function()
        statusLabel.Text = "Выполняется..."
        local count = renameAllRemotesInGameByParent()
        if count > 0 then
            statusLabel.Text = "✅ Переименовано " .. count .. " ремоутов!"
        else
            statusLabel.Text = "ℹ️ Ремоуты не найдены"
        end
    end)
    
    closeButton.MouseButton1Click:Connect(function()
        screenGui:Destroy()
    end)
    
    print("✅ Отдельный интерфейс создан!")
    return screenGui
end

-- Автоматическая интеграция при запуске
spawn(function()
    wait(2) -- Даем время SimpleSpy загрузиться
    
    if getgenv().SimpleSpyExecuted then
        local integrated = integrateWithSimpleSpy()
        if not integrated then
            print("⚠️ Не удалось интегрировать с SimpleSpy, создаю отдельный интерфейс...")
            createStandaloneUI()
        end
    else
        print("ℹ️ SimpleSpy не запущен, создаю отдельный интерфейс...")
        createStandaloneUI()
    end
end)

-- Экспортируем функции в глобальную область видимости
getgenv().RenameRemotesToCallingScript = renameRemotesToCallingScript
getgenv().RenameAllGameRemotes = renameAllRemotesInGameByParent
getgenv().IntegrateRemoteRenamer = integrateWithSimpleSpy

print("\n" .. string.rep("=", 50))
print("🚀 Remote Renamer успешно загружен!")
print("Доступные команды:")
print("  RenameRemotesToCallingScript() - переименовать по Calling Script")
print("  RenameAllGameRemotes() - переименовать все ремоуты в игре")
print("  IntegrateRemoteRenamer() - интегрировать с SimpleSpy")
print(string.rep("=", 50))
