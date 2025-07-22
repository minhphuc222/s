-- Enhanced HTTP Tracker với Connection Debug và Auto-recovery
local httpTracker = {}

-- Cấu hình server PC với debug mode
httpTracker.serverConfig = {
    hosts = {
        "192.168.0.197", -- IP từ server Python của bạn
        "127.0.0.1",
        "localhost"
    },
    port = 8888,
    enabled = true,
    activeHost = nil,
    connectionAttempts = 0,
    maxRetries = 3,
    debugMode = true -- Bật debug mode
}

-- Debug logging
httpTracker.debugLog = function(message)
    if httpTracker.serverConfig.debugMode then
        print("[DEBUG] " .. message)
    end
end

-- Kiểm tra HTTP service availability
httpTracker.checkHttpService = function()
    local HttpService = game:GetService("HttpService")
    if not HttpService then
        httpTracker.logError("HttpService không khả dụng!")
        return false
    end
    
    -- Kiểm tra HttpEnabled
    local success, enabled = pcall(function()
        return HttpService.HttpEnabled
    end)
    
    if not success or not enabled then
        httpTracker.logError("HTTP requests bị vô hiệu hóa! Cần bật HttpEnabled trong game settings")
        return false
    end
    
    httpTracker.debugLog("HttpService đã sẵn sàng")
    return true
end

-- Test connection với multiple endpoints
httpTracker.testConnection = function(host, port)
    httpTracker.debugLog(string.format("Testing connection to %s:%d", host, port))
    
    -- Test ping endpoint trước (nhanh hơn)
    local success, result = pcall(function()
        local pingUrl = string.format("http://%s:%d/ping", host, port)
        httpTracker.debugLog("Testing ping URL: " .. pingUrl)
        
        if not request then
            error("Function 'request' không khả dụng")
        end
        
        local response = request({
            Url = pingUrl,
            Method = "GET",
            Headers = {
                ["User-Agent"] = "RobloxTracker/2.0",
                ["Accept"] = "application/json"
            },
            Timeout = 3
        })
        
        httpTracker.debugLog(string.format("Ping Response - Success: %s, StatusCode: %s", 
            tostring(response.Success), tostring(response.StatusCode)))
        
        if response.Success and response.StatusCode == 200 then
            -- Test status endpoint để confirm
            local statusUrl = string.format("http://%s:%d/status", host, port)
            local statusResponse = request({
                Url = statusUrl,
                Method = "GET",
                Headers = {["User-Agent"] = "RobloxTracker/2.0"},
                Timeout = 3
            })
            
            if statusResponse.Success and statusResponse.StatusCode == 200 then
                httpTracker.debugLog("Status response: " .. tostring(statusResponse.Body))
                return true, "Full connection successful"
            else
                return true, "Ping successful, status partial"
            end
        else
            return false, "Ping failed: " .. tostring(response.StatusMessage or "No response")
        end
    end)
    
    if success then
        return result
    else
        httpTracker.debugLog("Connection test failed: " .. tostring(result))
        return false, tostring(result)
    end
end

-- Enhanced server finding với detailed logging
httpTracker.findWorkingHost = function()
    httpTracker.log("🔍 Đang tìm kiếm server PC...")
    
    -- Kiểm tra HTTP service trước
    if not httpTracker.checkHttpService() then
        return false
    end
    
    for i, host in ipairs(httpTracker.serverConfig.hosts) do
        httpTracker.debugLog(string.format("Thử kết nối %d/%d: %s", i, #httpTracker.serverConfig.hosts, host))
        httpTracker.serverConfig.connectionAttempts = httpTracker.serverConfig.connectionAttempts + 1
        
        local success, message = httpTracker.testConnection(host, httpTracker.serverConfig.port)
        
        if success then
            httpTracker.serverConfig.activeHost = host
            httpTracker.logSuccess("✅ Kết nối thành công với server: " .. host)
            return true
        else
            httpTracker.logWarning(string.format("❌ Không kết nối được %s: %s", host, message))
            wait(1) -- Delay giữa các lần thử
        end
    end
    
    httpTracker.logError("🚫 Không tìm thấy server PC nào!")
    httpTracker.serverConfig.enabled = false
    httpTracker.printConnectionTroubleshoot()
    return false
end

-- Troubleshooting guide
httpTracker.printConnectionTroubleshoot = function()
    httpTracker.log("📋 HƯỚNG DẪN KHẮC PHỤC:")
    httpTracker.log("1. Kiểm tra server Python có đang chạy không?")
    httpTracker.log("2. Kiểm tra IP address trong danh sách hosts:")
    for _, host in ipairs(httpTracker.serverConfig.hosts) do
        httpTracker.log("   - " .. host)
    end
    httpTracker.log("3. Kiểm tra port 8888 có bị firewall chặn không")
    httpTracker.log("4. Thử chạy lệnh: python -m http.server 8888")
    httpTracker.log("5. Kiểm tra HttpEnabled trong Roblox Studio")
end

-- Khởi tạo
httpTracker.startTime = os.time()
httpTracker.requests = {}
httpTracker.serverLogs = {}

-- Enhanced server communication với test endpoint
httpTracker.sendToServer = function(logType, message, details)
    if not httpTracker.serverConfig.enabled or not httpTracker.serverConfig.activeHost then
        httpTracker.debugLog("Server không khả dụng, bỏ qua gửi log")
        return false
    end
    
    local success, result = pcall(function()
        local serverUrl = string.format("http://%s:%d/log", 
            httpTracker.serverConfig.activeHost, 
            httpTracker.serverConfig.port)
        
        local logData = {
            type = logType,
            message = message,
            source = "ROBLOX_TRACKER",
            details = details or {},
            timestamp = os.date("%H:%M:%S", os.time()),
            game_id = tostring(game.GameId),
            place_id = tostring(game.PlaceId),
            player_count = #game:GetService("Players"):GetPlayers()
        }
        
        local HttpService = game:GetService("HttpService")
        local jsonData = HttpService:JSONEncode(logData)
        
        httpTracker.debugLog("Sending to server: " .. serverUrl)
        httpTracker.debugLog("Data length: " .. #jsonData .. " bytes")
        
        local response = request({
            Url = serverUrl,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json",
                ["User-Agent"] = "RobloxTracker/2.0",
                ["Accept"] = "application/json"
            },
            Body = jsonData,
            Timeout = 8
        })
        
        if response.Success and response.StatusCode == 200 then
            httpTracker.debugLog("Server log sent successfully")
            return true
        else
            httpTracker.debugLog(string.format("Server log failed: %d - %s", 
                response.StatusCode or 0, 
                response.StatusMessage or "Unknown error"))
            return false
        end
    end)
    
    if not success then
        httpTracker.debugLog("Error sending to server: " .. tostring(result))
        -- Connection lost, try to reconnect
        httpTracker.serverConfig.activeHost = nil
        spawn(function()
            wait(2)
            httpTracker.findWorkingHost()
        end)
        return false
    end
    
    return result
end

-- Enhanced logging functions
httpTracker.log = function(message, logType)
    logType = logType or "INFO"
    local timestamp = os.date("%H:%M:%S")
    local formattedMessage = string.format("[%s][TRACKER] %s", timestamp, message)
    
    -- Console output với màu
    if logType == "ERROR" then
        warn("🔴 " .. formattedMessage)
    elseif logType == "WARNING" then
        warn("🟡 " .. formattedMessage)
    elseif logType == "SUCCESS" then
        print("🟢 " .. formattedMessage)
    else
        print("ℹ️ " .. formattedMessage)
    end
    
    -- Gửi lên server (non-blocking)
    spawn(function()
        httpTracker.sendToServer(logType, message)
    end)
end

httpTracker.logError = function(message, errorDetails)
    httpTracker.log("ERROR: " .. message, "ERROR")
    httpTracker.sendToServer("ERROR", message, {
        error_details = errorDetails,
        stack_trace = debug.traceback(),
        connection_attempts = httpTracker.serverConfig.connectionAttempts
    })
end

httpTracker.logWarning = function(message, details)
    httpTracker.log("WARNING: " .. message, "WARNING")
    httpTracker.sendToServer("WARNING", message, details)
end

httpTracker.logSuccess = function(message, details)
    httpTracker.log("SUCCESS: " .. message, "SUCCESS")
    httpTracker.sendToServer("SUCCESS", message, details)
end

-- Connection status check
httpTracker.checkConnection = function()
    if not httpTracker.serverConfig.activeHost then
        httpTracker.log("⚠️ Server chưa kết nối, đang thử kết nối lại...")
        return httpTracker.findWorkingHost()
    end
    
    local success, message = httpTracker.testConnection(
        httpTracker.serverConfig.activeHost, 
        httpTracker.serverConfig.port
    )
    
    if not success then
        httpTracker.logWarning("Mất kết nối server: " .. message)
        httpTracker.serverConfig.activeHost = nil
        return httpTracker.findWorkingHost()
    end
    
    return true
end

-- Periodic connection check
spawn(function()
    while wait(30) do -- Kiểm tra mỗi 30 giây
        if httpTracker.serverConfig.enabled then
            httpTracker.checkConnection()
        end
    end
end)

-- Initialize và start tracking
httpTracker.log("🚀 Đang khởi động HTTP Tracking System...")
httpTracker.log("📊 Debug mode: " .. (httpTracker.serverConfig.debugMode and "Enabled" or "Disabled"))

-- Tìm server
if httpTracker.findWorkingHost() then
    httpTracker.logSuccess("🎉 Hệ thống đã sẵn sàng!")
else
    httpTracker.logError("💥 Không thể kết nối server - chạy ở chế độ offline")
end

-- Original function preservation
if request then 
    httpTracker.originalRequest = request 
    httpTracker.log("✅ Đã hook function 'request'")
end
if http and http.request then 
    httpTracker.originalHttpRequest = http.request 
    httpTracker.log("✅ Đã hook function 'http.request'")
end
if syn and syn.request then 
    httpTracker.originalSynRequest = syn.request 
    httpTracker.log("✅ Đã hook function 'syn.request'")
end
if http_request then 
    httpTracker.originalHttpRequestFunc = http_request 
    httpTracker.log("✅ Đã hook function 'http_request'")
end

-- Enhanced request tracking
httpTracker.trackRequest = function(url, method, source, options)
    local requestInfo = {
        time = os.time(),
        url = url,
        method = method,
        source = source,
        user_agent = options and options.Headers and options.Headers["User-Agent"] or "unknown",
        content_type = options and options.Headers and options.Headers["Content-Type"] or "unknown"
    }
    
    table.insert(httpTracker.requests, requestInfo)
    
    local logMsg = string.format("🌐 HTTP %s: %s [%s]", method, url, source)
    httpTracker.log(logMsg, "HTTP")
    
    -- Gửi log chi tiết
    spawn(function()
        httpTracker.sendToServer("HTTP", logMsg, {
            url = url,
            method = method,
            source = source,
            request_count = #httpTracker.requests,
            headers = options and options.Headers or {}
        })
    end)
end

-- Hook functions với error handling
if request then
    getgenv().request = function(options)
        local success, result = pcall(function()
            local url = options.Url or options.url or "unknown"
            local method = options.Method or options.method or "GET"
            
            httpTracker.trackRequest(url, method, "request()", options)
            return httpTracker.originalRequest(options)
        end)
        
        if not success then
            httpTracker.logError("Lỗi trong request(): " .. tostring(result))
            return {Success = false, StatusCode = 500, Body = ""}
        end
        
        return result
    end
end

-- Status reporting function
httpTracker.getStatus = function()
    return {
        connected = httpTracker.serverConfig.activeHost ~= nil,
        activeHost = httpTracker.serverConfig.activeHost,
        totalRequests = #httpTracker.requests,
        connectionAttempts = httpTracker.serverConfig.connectionAttempts,
        uptime = os.time() - httpTracker.startTime
    }
end

-- Manual connection test với server info
httpTracker.testNow = function()
    httpTracker.log("🔧 Thực hiện test kết nối thủ công...")
    
    -- Test tất cả hosts
    for i, host in ipairs(httpTracker.serverConfig.hosts) do
        httpTracker.log(string.format("Testing %d/%d: %s:%d", 
            i, #httpTracker.serverConfig.hosts, host, httpTracker.serverConfig.port))
        
        local success, message = httpTracker.testConnection(host, httpTracker.serverConfig.port)
        
        if success then
            httpTracker.logSuccess(string.format("✅ %s - %s", host, message))
            
            -- Test gửi log thử nghiệm
            httpTracker.serverConfig.activeHost = host
            local testResult = httpTracker.sendToServer("TEST", "Manual connection test", {
                test_time = os.date("%d/%m/%Y %H:%M:%S"),
                client_version = "2.0"
            })
            
            if testResult then
                httpTracker.logSuccess("📤 Test log gửi thành công!")
                return true
            else
                httpTracker.logWarning("📤 Test log thất bại nhưng ping OK")
            end
        else
            httpTracker.logWarning(string.format("❌ %s - %s", host, message))
        end
    end
    
    return httpTracker.findWorkingHost()
end

-- Export functions for manual control
_G.httpTracker = {
    status = httpTracker.getStatus,
    test = httpTracker.testNow,
    debug = function(enabled) 
        httpTracker.serverConfig.debugMode = enabled
        httpTracker.log("Debug mode: " .. (enabled and "Enabled" or "Disabled"))
    end
}

httpTracker.log("✨ HTTP Tracker loaded! Use _G.httpTracker.status() to check status")
