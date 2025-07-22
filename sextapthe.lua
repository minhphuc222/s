-- Enhanced HTTP Tracker với PC API Connection
local httpTracker = {}

-- Cấu hình server PC (thay đổi IP này thành IP máy tính của bạn)
httpTracker.serverConfig = {
    host = "localhost", -- Thay đổi thành IP máy tính của bạn
    port = 8888,
    enabled = true
}

-- Khởi tạo
httpTracker.startTime = os.time()
httpTracker.requests = {}
httpTracker.serverLogs = {}

-- Hàm gửi log lên server PC
httpTracker.sendToServer = function(logType, message, details)
    if not httpTracker.serverConfig.enabled then
        return
    end
    
    local success, result = pcall(function()
        local serverUrl = string.format("http://%s:%d/log", 
            httpTracker.serverConfig.host, 
            httpTracker.serverConfig.port)
        
        local logData = {
            type = logType,
            message = message,
            source = "ROBLOX_TRACKER",
            details = details or {},
            timestamp = os.date("%H:%M:%S", os.time())
        }
        
        local jsonData = game:GetService("HttpService"):JSONEncode(logData)
        
        if request then
            local response = request({
                Url = serverUrl,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = jsonData
            })
            return response.Success
        end
        
        return false
    end)
    
    if not success then
        -- Fallback: lưu log locally nếu không gửi được
        table.insert(httpTracker.serverLogs, {
            type = logType,
            message = message,
            time = os.time(),
            details = details
        })
    end
end

-- Hàm log cải tiến
httpTracker.log = function(message, logType)
    logType = logType or "INFO"
    local formattedMessage = "[HTTP TRACKER] " .. message
    
    -- In ra console Roblox
    if logType == "ERROR" then
        warn(formattedMessage)
    elseif logType == "WARNING" then
        warn(formattedMessage)
    else
        print(formattedMessage)
    end
    
    -- Gửi lên server PC
    httpTracker.sendToServer(logType, message)
end

-- Hàm báo lỗi chi tiết
httpTracker.logError = function(message, errorDetails)
    local errorMsg = "ERROR: " .. message
    warn("[HTTP TRACKER] " .. errorMsg)
    
    httpTracker.sendToServer("ERROR", message, {
        error_details = errorDetails,
        stack_trace = debug.traceback()
    })
end

-- Hàm báo cảnh báo
httpTracker.logWarning = function(message, details)
    local warningMsg = "WARNING: " .. message
    warn("[HTTP TRACKER] " .. warningMsg)
    
    httpTracker.sendToServer("WARNING", message, details)
end

-- Hàm báo thành công
httpTracker.logSuccess = function(message, details)
    httpTracker.log("SUCCESS: " .. message, "SUCCESS")
    httpTracker.sendToServer("SUCCESS", message, details)
end

-- Thông báo khởi động
httpTracker.logSuccess("Hệ thống theo dõi HTTP đã khởi động", {
    server_host = httpTracker.serverConfig.host,
    server_port = httpTracker.serverConfig.port,
    start_time = os.date("%d/%m/%Y %H:%M:%S", httpTracker.startTime)
})

-- Lưu các hàm HTTP gốc
if request then 
    httpTracker.originalRequest = request 
    httpTracker.log("Đã hook function 'request'")
end
if http and http.request then 
    httpTracker.originalHttpRequest = http.request 
    httpTracker.log("Đã hook function 'http.request'")
end
if syn and syn.request then 
    httpTracker.originalSynRequest = syn.request 
    httpTracker.log("Đã hook function 'syn.request'")
end
if http_request then 
    httpTracker.originalHttpRequestFunc = http_request 
    httpTracker.log("Đã hook function 'http_request'")
end

-- Enhanced request tracking function
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
    
    local logMsg = string.format("HTTP Request: %s %s từ %s", method, url, source)
    httpTracker.log(logMsg, "HTTP")
    
    httpTracker.sendToServer("HTTP", logMsg, {
        url = url,
        method = method,
        source = source,
        request_count = #httpTracker.requests,
        headers = options and options.Headers or {}
    })
end

-- Hook hàm request với error handling
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
            return nil
        end
        
        return result
    end
end

-- Hook http.request với error handling  
if http and http.request then
    http.request = function(options)
        local success, result = pcall(function()
            local url = "unknown"
            local method = "GET"
            
            if type(options) == "string" then
                url = options
            else
                url = options.url or options.Url or "unknown"
                method = options.method or options.Method or "GET"
            end
            
            httpTracker.trackRequest(url, method, "http.request()", options)
            
            return httpTracker.originalHttpRequest(options)
        end)
        
        if not success then
            httpTracker.logError("Lỗi trong http.request(): " .. tostring(result))
            return nil
        end
        
        return result
    end
end

-- Hook syn.request với error handling
if syn and syn.request then
    syn.request = function(options)
        local success, result = pcall(function()
            local url = options.Url or options.url or "unknown"
            local method = options.Method or options.method or "GET"
            
            httpTracker.trackRequest(url, method, "syn.request()", options)
            
            return httpTracker.originalSynRequest(options)
        end)
        
        if not success then
            httpTracker.logError("Lỗi trong syn.request(): " .. tostring(result))
            return nil
        end
        
        return result
    end
end

-- Hook http_request với error handling
if http_request then
    getgenv().http_request = function(options)
        local success, result = pcall(function()
            local url = options.Url or options.url or "unknown"
            local method = options.Method or options.method or "GET"
            
            httpTracker.trackRequest(url, method, "http_request()", options)
            
            return httpTracker.originalHttpRequestFunc(options)
        end)
        
        if not success then
            httpTracker.logError("Lỗi trong http_request(): " .. tostring(result))
            return nil
        end
        
        return result
    end
end

-- Enhanced loadstring hook
if loadstring then
    httpTracker.originalLoadstring = loadstring
    
    getgenv().loadstring = function(code, chunkname)
        local chunkName = chunkname or "anonymous_chunk"
        httpTracker.log("Thực thi loadstring: " .. chunkName, "DEBUG")
        
        -- Tìm URLs trong code
        local foundUrls = {}
        if type(code) == "string" then
            for url in string.gmatch(code, "https?://[%w%.%-%+%_%~%:%/%%?&=#]+") do
                table.insert(foundUrls, url)
                httpTracker.log("Phát hiện URL trong code: " .. url, "DEBUG")
                
                table.insert(httpTracker.requests, {
                    time = os.time(),
                    url = url,
                    method = "FOUND_IN_CODE",
                    source = chunkName
                })
            end
        end
        
        -- Gửi thông tin lên server
        httpTracker.sendToServer("DEBUG", "Loadstring executed: " .. chunkName, {
            chunk_name = chunkName,
            code_length = type(code) == "string" and #code or 0,
            urls_found = foundUrls,
            urls_count = #foundUrls
        })
        
        local success, result = pcall(httpTracker.originalLoadstring, code, chunkname)
        
        if success then
            httpTracker.logSuccess("Loadstring hoàn thành: " .. chunkName, {
                total_requests = #httpTracker.requests
            })
        else
            httpTracker.logError("Loadstring thất bại: " .. chunkName, {
                error = tostring(result)
            })
        end
        
        return result
    end
end

-- Hàm kiểm tra kết nối server
httpTracker.testServerConnection = function()
    httpTracker.log("Đang kiểm tra kết nối server PC...")
    
    local success, result = pcall(function()
        local serverUrl = string.format("http://%s:%d/status", 
            httpTracker.serverConfig.host, 
            httpTracker.serverConfig.port)
        
        if request then
            local response = request({
                Url = serverUrl,
                Method = "GET",
                Timeout = 5
            })
            
            if response.Success and response.StatusCode == 200 then
                httpTracker.logSuccess("Kết nối server PC thành công!")
                return true
            end
        end
        
        return false
    end)
    
    if not success or not result then
        httpTracker.logWarning("Không thể kết nối server PC", {
            server_host = httpTracker.serverConfig.host,
            server_port = httpTracker.serverConfig.port,
            suggestion = "Kiểm tra IP và port server, đảm bảo server đang chạy"
        })
        httpTracker.serverConfig.enabled = false
    end
    
    return success and result
end

-- Hàm tổng kết chi tiết
httpTracker.printDetailedSummary = function()
    local summary = {
        start_time = os.date("%d/%m/%Y %H:%M:%S", httpTracker.startTime),
        end_time = os.date("%d/%m/%Y %H:%M:%S", os.time()),
        total_requests = #httpTracker.requests,
        server_connection = httpTracker.serverConfig.enabled,
        server_logs_pending = #httpTracker.serverLogs
    }
    
    httpTracker.log("=== BÁO CÁO TỔNG KẾT ===", "INFO")
    httpTracker.log("Thời gian bắt đầu: " .. summary.start_time)
    httpTracker.log("Thời gian kết thúc: " .. summary.end_time) 
    httpTracker.log("Tổng HTTP requests: " .. summary.total_requests)
    httpTracker.log("Kết nối server PC: " .. (summary.server_connection and "Có" or "Không"))
    
    -- Thống kê theo method
    local methodStats = {}
    for _, req in ipairs(httpTracker.requests) do
        local method = req.method
        methodStats[method] = (methodStats[method] or 0) + 1
    end
    
    httpTracker.log("Phân loại theo method:")
    for method, count in pairs(methodStats) do
        httpTracker.log(string.format("  - %s: %d requests", method, count))
    end
    
    -- Gửi báo cáo lên server
    httpTracker.sendToServer("INFO", "Báo cáo tổng kết HTTP Tracker", {
        summary = summary,
        method_stats = methodStats,
        all_requests = httpTracker.requests
    })
    
    httpTracker.log("========================")
end

-- Hàm chạy script an toàn với báo cáo chi tiết
httpTracker.runScript = function(url)
    httpTracker.log("Bắt đầu tải và chạy script từ: " .. url)
    
    local success, result = pcall(function()
        -- Test server connection trước
        httpTracker.testServerConnection()
        
        -- Tải script
        local scriptContent = ""
        local fetchSuccess = false
        
        if request then
            local response = request({Url = url, Method = "GET"})
            if response.Success then
                scriptContent = response.Body
                fetchSuccess = true
                httpTracker.logSuccess("Tải script thành công (" .. #scriptContent .. " bytes)")
            end
        end
        
        if not fetchSuccess then
            error("Không thể tải script từ URL: " .. url)
        end
        
        -- Thực thi script
        local scriptFunction = loadstring(scriptContent)
        if not scriptFunction then
            error("Không thể compile script")
        end
        
        local executeResult = scriptFunction()
        
        httpTracker.logSuccess("Script đã thực thi thành công")
        return executeResult
    end)
    
    if not success then
        httpTracker.logError("Lỗi khi chạy script", {
            url = url,
            error = tostring(result)
        })
    end
    
    -- Hiển thị báo cáo tổng kết
    httpTracker.printDetailedSummary()
    
    return success and result or nil
end

-- Khởi động hoàn tất
httpTracker.logSuccess("HTTP Tracking System đã sẵn sàng!")

-- Script URL để chạy
local scriptUrl = "https://pastefy.app/lcjeRtej/raw"

-- Chạy script với tracking đầy đủ
httpTracker.runScript(scriptUrl)