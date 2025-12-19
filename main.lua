-- Автономный скрипт для переименования ремоутов
local function renameRemotesToCallingScript()
    -- Проверяем наличие SimpleSpy
    if not getgenv().SimpleSpy or not getgenv().logs then
        warn("SimpleSpy не найден! Запустите SimpleSpy сначала.")
        return
    end
    
    local logs = getgenv().logs
    local renamedCount = 0
    
    -- Функция для получения имени Calling Script
    local function getCallingScriptName(callingScript)
        if not callingScript then return "Unknown" end
        
        -- Пытаемся получить полный путь
        local fullName = ""
        local current = callingScript
        
        while current and current ~= game do
            if current.Name and current.Name ~= "" then
                if fullName == "" then
                    fullName = current.Name
                else
                    fullName = current.Name .. "_" .. fullName
                end
            end
            current = current.Parent
        end
        
        return fullName ~= "" and fullName or "Unknown"
    end
    
    -- Проходим по всем логам
    for _, log in ipairs(logs) do
        if log.Remote and (log.Remote:IsA("RemoteEvent") or log.Remote:IsA("RemoteFunction")) then
            local remote = log.Remote
            local callingScript = log.Source
            
            if callingScript then
                local newName = getCallingScriptName(callingScript)
                
                -- Добавляем тип для ясности
                if remote:IsA("RemoteEvent") then
                    newName = newName .. "_Event"
                elseif remote:IsA("RemoteFunction") then
                    newName = newName .. "_Function"
                end
                
                -- Ограничиваем длину имени
                if #newName > 100 then
                    newName = newName:sub(1, 100)
                end
                
                -- Пытаемся переименовать
                local success = pcall(function()
                    remote.Name = newName
                    renamedCount = renamedCount + 1
                    
                    -- Обновляем отображение в SimpleSpy
                    if log.Log and log.Log:FindFirstChild("Text") then
                        log.Log.Text.Text = newName
                    end
                end)
                
                if not success then
                    warn("Не удалось переименовать ремоут: " .. tostring(remote))
                end
            end
        end
    end
    
    -- Показываем результат
    if renamedCount > 0 then
        print("✅ Успешно переименовано " .. renamedCount .. " ремоутов!")
        
        -- Если есть TextLabel SimpleSpy, показываем там тоже
        if getgenv().TextLabel then
            getgenv().TextLabel.Text = "Переименовано " .. renamedCount .. " ремоутов!"
        end
    else
        print("⚠️ Не удалось переименовать ремоуты")
    end
    
    return renamedCount
end

-- Запускаем функцию
renameRemotesToCallingScript()

-- Создаем кнопку в SimpleSpy если он доступен
if getgenv().SimpleSpy and type(getgenv().SimpleSpy.newButton) == "function" then
    getgenv().SimpleSpy:newButton(
        "Rename All Remotes",
        function() 
            return "Переименовать все найденные ремоуты в их Calling Script"
        end,
        function()
            renameRemotesToCallingScript()
        end
    )
end
