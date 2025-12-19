-- Скрипт для переименования RemoteEvent и RemoteFunction в их Calling Script
local renameRemotesScript = [[
-- Внимание: Этот скрипт работает только с SimpleSpy V3
-- Он переименовывает RemoteEvent и RemoteFunction в их Calling Script

local function renameRemoteToCallingScript()
    if not getgenv().SimpleSpy or not getgenv().SimpleSpyExecuted then
        warn("SimpleSpy не запущен!")
        return false
    end
    
    -- Получаем таблицу логов из SimpleSpy
    local logs = getgenv().SimpleSpy.logs or {}
    local renamedCount = 0
    
    for _, log in pairs(logs) do
        if log.Remote and (log.Remote:IsA("RemoteEvent") or log.Remote:IsA("RemoteFunction") or log.Remote:IsA("UnreliableRemoteEvent")) then
            -- Получаем Calling Script из лога
            local callingScript = log.Source
            
            if callingScript and typeof(callingScript) == "Instance" then
                -- Формируем новое имя на основе Calling Script
                local newName
                
                -- Получаем полный путь к скрипту
                local scriptPath = callingScript:GetFullName()
                
                -- Извлекаем только имя скрипта (последнюю часть пути)
                local scriptName = callingScript.Name
                
                -- Добавляем тип удаленного объекта
                local remoteType = log.Remote.ClassName
                
                -- Формируем уникальное имя: ИмяСкрипта_ТипРемоута
                newName = scriptName .. "_" .. remoteType
                
                -- Проверяем, нужно ли переименовать
                if log.Remote.Name ~= newName then
                    -- Пытаемся переименовать
                    local success, errorMsg = pcall(function()
                        log.Remote.Name = newName
                    end)
                    
                    if success then
                        renamedCount = renamedCount + 1
                        print(string.format("✓ Переименован: %s -> %s (Calling Script: %s)", 
                            log.Name, newName, scriptPath))
                    else
                        warn(string.format("✗ Ошибка переименования %s: %s", log.Name, errorMsg))
                    end
                end
            end
        end
    end
    
    if renamedCount > 0 then
        print(string.format("\n✅ Успешно переименовано %d ремоутов!", renamedCount))
        return true
    else
        print("ℹ️ Не найдено ремоутов для переименования или все уже имеют правильные имена")
        return false
    end
end

-- Функция для переименования всех ремоутов в игре
local function renameAllRemotesInGame()
    print("🔍 Поиск всех RemoteEvent и RemoteFunction в игре...")
    
    local renamedCount = 0
    
    -- Рекурсивная функция для поиска ремоутов
    local function searchAndRename(object)
        if object:IsA("RemoteEvent") or object:IsA("RemoteFunction") or object:IsA("UnreliableRemoteEvent") then
            -- Генерируем уникальное имя на основе родителя
            local parentName = object.Parent and object.Parent.Name or "Unknown"
            local newName = parentName .. "_" .. object.ClassName
            
            -- Проверяем, нужно ли переименовать
            if object.Name ~= newName then
                local oldName = object.Name
                object.Name = newName
                renamedCount = renamedCount + 1
                print(string.format("✓ %s переименован в %s (Путь: %s)", 
                    oldName, newName, object:GetFullName()))
            end
        end
        
        -- Рекурсивно обходим дочерние объекты
        for _, child in pairs(object:GetChildren()) do
            searchAndRename(child)
        end
    end
    
    -- Начинаем поиск с корня игры
    searchAndRename(game)
    
    if renamedCount > 0 then
        print(string.format("\n✅ Успешно переименовано %d ремоутов в игре!", renamedCount))
    else
        print("ℹ️ Не найдено ремоутов для переименования")
    end
    
    return renamedCount
end

-- Функция для создания визуальной кнопки в SimpleSpy
local function addRenameButtonToSimpleSpy()
    if not getgenv().SimpleSpy then
        warn("SimpleSpy не найден!")
        return
    end
    
    -- Проверяем, не добавлена ли кнопка уже
    if getgenv().SimpleSpyRenameButtonAdded then
        print("Кнопка уже добавлена!")
        return
    end
    
    -- Добавляем кнопку через SimpleSpy API
    getgenv().SimpleSpy:newButton(
        "Rename Remotes",
        function() 
            return "Переименовать ремоуты в их Calling Script\nНажмите, чтобы переименовать все найденные ремоуты"
        end,
        function()
            local success = renameRemoteToCallingScript()
            if success then
                getgenv().SimpleSpy.TextLabel.Text = "✅ Ремоуты успешно переименованы!"
            else
                getgenv().SimpleSpy.TextLabel.Text = "⚠️ Не удалось переименовать ремоуты"
            end
        end
    )
    
    -- Добавляем вторую кнопку для переименования всех ремоутов в игре
    getgenv().SimpleSpy:newButton(
        "Rename All Game Remotes",
        function() 
            return "Переименовать ВСЕ RemoteEvent/Function в игре\nБудет переименовано на основе родительских объектов"
        end,
        function()
            local count = renameAllRemotesInGame()
            if count > 0 then
                getgenv().SimpleSpy.TextLabel.Text = string.format("✅ Переименовано %d ремоутов в игре!", count)
            else
                getgenv().SimpleSpy.TextLabel.Text = "ℹ️ Ремоуты не найдены или уже переименованы"
            end
        end
    )
    
    getgenv().SimpleSpyRenameButtonAdded = true
    print("✅ Кнопка переименования добавлена в SimpleSpy!")
end

-- Автоматически добавляем кнопку при запуске
if getgenv().SimpleSpyExecuted then
    delay(2, function()
        addRenameButtonToSimpleSpy()
    end)
else
    print("⏳ Ожидание загрузки SimpleSpy...")
    local connection
    connection = game:GetService("RunService").Heartbeat:Connect(function()
        if getgenv().SimpleSpyExecuted then
            connection:Disconnect()
            delay(1, function()
                addRenameButtonToSimpleSpy()
            end)
        end
    end)
end

-- Экспортируем функции в глобальную область видимости
getgenv().RenameRemotesToCallingScript = renameRemoteToCallingScript
getgenv().RenameAllGameRemotes = renameAllRemotesInGame
getgenv().AddRenameButtonToSimpleSpy = addRenameButtonToSimpleSpy

print("📝 Скрипт переименования ремоутов загружен!")
print("Доступные команды:")
print("  RenameRemotesToCallingScript() - переименовать ремоуты из логов SimpleSpy")
print("  RenameAllGameRemotes() - переименовать ВСЕ ремоуты в игре")
print("  AddRenameButtonToSimpleSpy() - добавить кнопку в интерфейс SimpleSpy")
]]

-- Запускаем скрипт
local success, errorMsg = pcall(function()
    loadstring(renameRemotesScript)()
end)

if not success then
    warn("Ошибка при запуске скрипта переименования:", errorMsg)
end
