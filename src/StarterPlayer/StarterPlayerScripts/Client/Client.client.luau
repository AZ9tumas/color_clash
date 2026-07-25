local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Services = Shared.Services
local UIControllers = Shared.UIControllers

local function bootstrap()
    for _, serviceFolder in Services:GetChildren() do
        if serviceFolder:IsA("Folder") then
            local moduleName = string.gsub(serviceFolder.Name, "Service$", "Client")
            local clientModule = serviceFolder:FindFirstChild(moduleName)
            if clientModule and clientModule:IsA("ModuleScript") then
                local service = require(clientModule)
                if type(service) == "table" and service.Init then
                    service.Init()
                end
            end
        end
    end
    
    if UIControllers then
        for _, controllerModule in UIControllers:GetChildren() do
            if controllerModule:IsA("ModuleScript") then
                local controller = require(controllerModule)
                if type(controller) == "table" and controller.Init then
                    controller.Init()
                end
            end
        end
    end

    for _, serviceFolder in Services:GetChildren() do
        if serviceFolder:IsA("Folder") then
            local moduleName = string.gsub(serviceFolder.Name, "Service$", "Client")
            local clientModule = serviceFolder:FindFirstChild(moduleName)
            if clientModule and clientModule:IsA("ModuleScript") then
                local service = require(clientModule)
                if type(service) == "table" and service.Start then
                    service.Start()
                end
            end
        end
    end
    
    if UIControllers then
        for _, controllerModule in UIControllers:GetChildren() do
            if controllerModule:IsA("ModuleScript") then
                local controller = require(controllerModule)
                if type(controller) == "table" and controller.Start then
                    controller.Start()
                end
            end
        end
    end
end

bootstrap()