-- Исправленный скрипт для переименования RemoteEvent и RemoteFunction в их Calling Script
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
    
    -- Получаем доступ к логам SimpleSpy V3
    local logs = {}
    
    -- Способ 1: Попробуем получить логи через локальную переменную SimpleSpy
    if getgenv().SimpleSpy and getgenv().SimpleSpy.logs then
        logs = getgenv().SimpleSpy.logs
        print("✅ Логи получены через getgenv().SimpleSpy.logs")
    -- Способ 2: Ищем в CoreGui
    elseif game:GetService("CoreGui"):FindFirstChild("SimpleSpy3") then
        local simpleSpyGui = game:GetService("CoreGui"):FindFirstChild("SimpleSpy3")
        -- В SimpleSpy V3 логи хранятся в переменной logs
        -- Попробуем получить доступ через shared
        if shared.SimpleSpy and shared.SimpleSpy.logs then
            logs = shared.SimpleSpy.logs
            print("✅ Логи получены через shared.SimpleSpy.logs")
        else
            -- Попробуем найти контейнер логов
            local logList = simpleSpyGui:FindFirstChild("Background", true)
            if logList then
                print("✅ Найден контейнер логов SimpleSpy")
            end
        end
    -- Способ 3: Прямой доступ к глобальным переменным SimpleSpy
    elseif getgenv().SimpleSpyLogs then
        logs = getgenv().SimpleSpyLogs
        print("✅ Логи получены через getgenv().SimpleSpyLogs")
    else
        -- Попробуем найти логи в реестре SimpleSpy
        for _, v in pairs(getreg() or {}) do
            if type(v) == "table" and rawget(v, "logs") then
                logs = v.logs
                print("✅ Логи найдены в реестре")
                break
            end
        end
    end
    
    if type(logs) ~= "table" or #logs == 0 then
        -- Попробуем получить логи из кеша SimpleSpy
        if remoteLogs and type(remoteLogs) == "table" then
            -- Преобразуем remoteLogs в формат logs
            logs = {}
            for i, v in ipairs(remoteLogs) do
                if type(v) == "table" and v[2] and v[2]:IsA("Frame") then
                    -- Найдем соответствующую запись лога
                    for _, log in pairs(getgenv().SimpleSpy and getgenv().SimpleSpy.logs_cache or {}) do
                        if log.Log == v[2] then
                            table.insert(logs, log)
                            break
                        end
                    end
                end
            end
            print("✅ Логи получены из remoteLogs")
        end
        
        if #logs == 0 then
            print("⚠️ Не удалось получить доступ к логам SimpleSpy")
            print("ℹ️ Сначала перехватите несколько ремоутов в SimpleSpy")
            return false, "Не удалось получить доступ к логам"
        end
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
        if log and type(log) == "table" then
            local remote = log.Remote
            
            if remote and (remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction") or remote:IsA("UnreliableRemoteEvent")) then
                -- Получаем Calling Script из лога
                local callingScript = log.Source or log.callingscript
                
                if callingScript and typeof(callingScript) == "Instance" then
                    -- Получаем имя скрипта
                    local scriptName = getScriptName(callingScript)
                    local remoteType = remote.ClassName
                    
                    -- Создаем новое имя
                    local newName = createSafeName(scriptName, remoteType)
                    local oldName = remote.Name
                    
                    -- Проверяем, отличается ли имя
                    if oldName ~= newName then
                        -- Пытаемся переименовать
                        local success, errorMsg = pcall(function()
                            remote.Name = newName
                        end)
                        
                        if success then
                            renamedCount = renamedCount + 1
                            print(string.format("✅ [%d] %s -> %s", i, oldName, newName))
                            if callingScript:IsDescendantOf(game) then
                                print(string.format("   📁 Calling Script: %s", callingScript:GetFullName()))
                            else
                                print(string.format("   📁 Calling Script: [Не в игре] %s", callingScript.ClassName))
                            end
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
                    local remoteName = remote.Name or "Без имени"
                    print(string.format("❌ [%d] Не найден Calling Script для: %s", 
                        i, remoteName))
                end
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

-- Основная функция для использования
local function main()
    print("\n" .. string.rep("=", 50))
    print("🚀 Remote Renamer for SimpleSpy V3")
    print("Автор: ChatGPT (на основе кода SimpleSpy V3)")
    print(string.rep("=", 50))
    
    -- Проверяем, запущен ли SimpleSpy
    if not getgenv().SimpleSpyExecuted then
        print("⚠️ SimpleSpy V3 не запущен!")
        print("Запустите SimpleSpy V3 сначала, затем запустите этот скрипт.")
        print("Или используйте режим переименования всех ремоутов в игре.")
        
        -- Предлагаем варианты
        print("\nВарианты действий:")
        print("1. Запустить RenameAllGameRemotes() - переименовать все ремоуты в игре")
        print("2. Сначала запустить SimpleSpy V3, затем этот скрипт")
        
        local choice = "2" -- По умолчанию ждем SimpleSpy
        
        -- Пытаемся переименовать все ремоуты в игре
        print("\nПытаюсь переименовать все ремоуты в игре...")
        local count = renameAllRemotesInGameByParent()
        
        if count > 0 then
            print("✅ Готово! Переименовано " .. count .. " ремоутов.")
        else
            print("ℹ️ Ремоуты не найдены или уже переименованы.")
        end
        
        return
    end
    
    print("✅ SimpleSpy V3 обнаружен!")
    print("\nДоступные команды:")
    print("1. renameRemotesToCallingScript() - переименовать по Calling Script")
    print("2. renameAllRemotesInGameByParent() - переименовать все ремоуты в игре")
    
    -- Автоматически запускаем переименование по Calling Script
    print("\nАвтоматически запускаю переименование по Calling Script...")
    local success, result = renameRemotesToCallingScript()
    
    if not success then
        print("⚠️ " .. result)
        print("\nПробую переименовать все ремоуты в игре...")
        local count = renameAllRemotesInGameByParent()
        
        if count > 0 then
            print("✅ Успешно переименовано " .. count .. " ремоутов в игре!")
        end
    end
    
    print("\n" .. string.rep("=", 50))
    print("✨ Remote Renamer завершил работу!")
    print("Для повторного запуска используйте команды:")
    print("  renameRemotesToCallingScript()")
    print("  renameAllGameRemotes()")
    print(string.rep("=", 50))
end

-- Экспортируем функции под разными именами для совместимости
getgenv().renameRemotesToCallingScript = renameRemotesToCallingScript
getgenv().renameAllGameRemotes = renameAllRemotesInGameByParent
getgenv().RenameRemotesToCallingScript = renameRemotesToCallingScript
getgenv().RenameAllGameRemotes = renameAllRemotesInGameByParent

-- Создаем простой интерфейс
local function createSimpleUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "RemoteRenamerSimpleUI"
    screenGui.Parent = game:GetService("CoreGui")
    
    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 250, 0, 150)
    mainFrame.Position = UDim2.new(0, 10, 0, 10)
    mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    
    local title = Instance.new("TextLabel")
    title.Text = "Remote Renamer"
    title.Size = UDim2.new(1, 0, 0, 30)
    title.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    title.TextColor3 = Color3.new(1, 1, 1)
    title.Font = Enum.Font.SourceSansBold
    title.TextSize = 14
    title.Parent = mainFrame
    
    local btn1 = Instance.new("TextButton")
    btn1.Text = "По Calling Script"
    btn1.Size = UDim2.new(0.9, 0, 0, 30)
    btn1.Position = UDim2.new(0.05, 0, 0.3, 0)
    btn1.BackgroundColor3 = Color3.fromRGB(60, 60, 180)
    btn1.TextColor3 = Color3.new(1, 1, 1)
    btn1.Parent = mainFrame
    
    local btn2 = Instance.new("TextButton")
    btn2.Text = "Все в игре"
    btn2.Size = UDim2.new(0.9, 0, 0, 30)
    btn2.Position = UDim2.new(0.05, 0, 0.6, 0)
    btn2.BackgroundColor3 = Color3.fromRGB(60, 180, 60)
    btn2.TextColor3 = Color3.new(1, 1, 1)
    btn2.Parent = mainFrame
    
    local closeBtn = Instance.new("TextButton")
    closeBtn.Text = "X"
    closeBtn.Size = UDim2.new(0, 20, 0, 20)
    closeBtn.Position = UDim2.new(1, -20, 0, 0)
    closeBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.Parent = mainFrame
    
    -- Обработчики событий
    btn1.MouseButton1Click:Connect(function()
        local success, result = renameRemotesToCallingScript()
        print(result)
    end)
    
    btn2.MouseButton1Click:Connect(function()
        local count = renameAllRemotesInGameByParent()
        print("Переименовано: " .. count .. " ремоутов")
    end)
    
    closeBtn.MouseButton1Click:Connect(function()
        screenGui:Destroy()
    end)
    
    return screenGui
end

-- Запускаем основную функцию с задержкой
delay(1, function()
    main()
    
    -- Создаем простой интерфейс
    createSimpleUI()
    
    print("\n📝 Создан простой интерфейс в верхнем левом углу экрана")
    print("Используйте кнопки для переименования ремоутов")
end)

print("✅ Remote Renamer загружен!")
print("Ожидайте запуска через 1 секунду...")
