local ServerScriptService = game:GetService("ServerScriptService")
local Server = ServerScriptService.Server
local Services = Server.Services

local function bootstrap()
    for _, serviceFolder in Services:GetChildren() do
        if serviceFolder:IsA("Folder") then
            local moduleName = string.gsub(serviceFolder.Name, "Service$", "Server")
            local serverModule = serviceFolder:FindFirstChild(moduleName)
            if serverModule and serverModule:IsA("ModuleScript") then
                local service = require(serverModule)
                if type(service) == "table" and service.Init then
                    service.Init()
                end
            end
        end
    end
    
    for _, serviceFolder in Services:GetChildren() do
        if serviceFolder:IsA("Folder") then
            local moduleName = string.gsub(serviceFolder.Name, "Service$", "Server")
            local serverModule = serviceFolder:FindFirstChild(moduleName)
            if serverModule and serverModule:IsA("ModuleScript") then
                local service = require(serverModule)
                if type(service) == "table" and service.Start then
                    service.Start()
                end
            end
        end
    end
end

bootstrap()