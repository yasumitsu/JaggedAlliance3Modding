_G.controller_host = "localhost"
_G.controller_port = 8171

if not rawget(_G, "outputSocket") then
	outputSocket = LuaSocket:new()
	outputThread = false
	outputBuffer = false
end

---
--- Clears the graphics output and optionally stops the update.
---
--- @param stop_update boolean Whether to stop the update.
function dbgOutputClear(stop_update)
    outputSocket:send(TableToLuaCode {target="graphicsOutput", type="new_screen", stop_update=stop_update})
end

---
--- Resumes the graphics output update.
---
--- @param stop_update boolean Whether to stop the update.
function dbgResumeUpdate(stop_update)
    outputSocket:send(TableToLuaCode {target="graphicsOutput", type="resume_update"})
end

---
--- Draws a circle on the graphics output.
---
--- @param pt Vector2 The center point of the circle.
--- @param radius number The radius of the circle.
--- @param color table An RGB color table, e.g. {255, 255, 255}.
--- @param filter string An optional filter to apply to the circle.
function dbgDrawCircle(pt, radius, color, filter)
    outputSocket:send(TableToLuaCode {target="graphicsOutput", type="circle", filter=filter, x=pt:x(), y=pt:y(),
        r=radius or 0, c=color or RGB(255, 255, 255)})
end

---
--- Draws a square on the graphics output.
---
--- @param pt Vector2 The center point of the square.
--- @param radius number The radius of the square.
--- @param color table An RGB color table, e.g. {255, 255, 255}.
--- @param filter string An optional filter to apply to the square.
function dbgDrawSquare(pt, radius, color, filter)
    outputSocket:send(TableToLuaCode {target="graphicsOutput", type="rect", filter=filter, x1=pt:x() - radius / 2,
        x2=pt:x() + radius / 2, y1=pt:y() - radius / 2, y2=pt:y() + radius / 2, c=color or RGB(255, 255, 255)})
end

---
--- Draws a rectangle on the graphics output.
---
--- @param pt Vector2 The top-left corner of the rectangle.
--- @param pt2 Vector2 The bottom-right corner of the rectangle.
--- @param color table An RGB color table, e.g. {255, 255, 255}.
--- @param filter string An optional filter to apply to the rectangle.
function dbgDrawRect(pt, pt2, color, filter)
    outputSocket:send(TableToLuaCode {target="graphicsOutput", type="rect", filter=filter, x=pt:x(), y=pt:y(),
        x1=pt2:x(), y1=pt2:y(), c=color or RGB(255, 255, 255)})
end

---
--- Draws an arrow on the graphics output.
---
--- @param pt1 Vector2 The start point of the arrow.
--- @param pt2 Vector2 The end point of the arrow.
--- @param color table An RGB color table, e.g. {255, 255, 255}.
--- @param filter string An optional filter to apply to the arrow.
function dbgDrawArrow(pt1, pt2, color, filter)
    outputSocket:send(TableToLuaCode {target="graphicsOutput", type="arrow", filter=filter, x1=pt1:x(), y1=pt1:y(),
        x2=pt2:x(), y2=pt2:y(), c=color or RGB(255, 255, 255)})
end

---
--- Draws an informational point on the graphics output.
---
--- @param pt Vector2 The center point of the informational point.
--- @param color table An RGB color table, e.g. {255, 255, 255}.
--- @param filter string An optional filter to apply to the informational point.
--- @param text string The text to display at the informational point.
--- @param ... any Additional arguments to format the text with.
function dbgInfo(pt, color, filter, text, ...)
    outputSocket:send(TableToLuaCode {target="graphicsOutput", type="infopt", filter=filter, x=pt:x(), y=pt:y(),
        text=string.format(text, ...), c=color or RGB(255, 255, 255)})
end

---
--- Draws a weight indicator on the graphics output.
---
--- @param pt Vector2 The center point of the weight indicator.
--- @param weight number The weight value to display.
--- @param filter string An optional filter to apply to the weight indicator.
--- @param name string An optional name to display with the weight indicator.
function dbgWeight(pt, weight, filter, name)
    outputSocket:send(TableToLuaCode {target="graphicsOutput", type="weight", filter=filter, name=name or "", x=pt:x(),
        y=pt:y(), w=weight})
end

---
--- Initializes the Lua debugger output system.
---
--- This function is called when the game starts and sets up the connection to the Lua debugger controller.
--- It creates a real-time thread that continuously checks the connection status and sends output to the controller.
--- The connection is retried if it is lost, and the output is buffered and flushed to the controller.
---
--- @
function OnMsg.Start()
    local connected
    local retry = true
    local dir, filename, ext = SplitPath(GetExecName())
    local project_name = filename or "unknown"
    outputThread = CreateRealTimeThread(function()
        while true do
            controller_host = not Platform.pc and config.Haerald and config.Haerald.ip or "localhost"
            if outputSocket:isdisconnected() then -- no connection initialized
                outputSocket:connect(controller_host, controller_port + 1)
                outputSocket:send(TableToLuaCode {target="output", text="Connected to " .. project_name .. "\n"})
                for i = 1, 20 do
                    if outputSocket:isconnecting() then
                        outputSocket:update()
                    end
                    if outputSocket:isconnected() then
                        connected = true
                        break
                    end
                    Sleep(50)
                end
            end
            if connected and not outputSocket:isconnected() then
                connected = false
                print("[Debugger] Connection lost, restart it with F11 (or all triggers on the gamepad)")
            end
            while not outputSocket:isdisconnected() do
                outputSocket:update()
                if outputBuffer then
                    local text = table.concat(outputBuffer)
                    if #text > 0 and not text:find_lower("[Debugger]") then
                        outputSocket:send(TableToLuaCode {target="output", text=text})
                        if rawget(_G, "g_LuaDebugger") then
                            g_LuaDebugger:WriteOutput(text)
                        end
                    end
                    outputBuffer = false
                end
                WaitWakeup(100)
            end
            outputSocket:close()
            Sleep(1000)
            -- do not retry on xbox, will not work
            if Platform.console and not Platform.switch then
                break
            end
        end
    end)
end

---
--- Handles writing console output to the debugger output socket.
---
--- If the output socket is connected, this function will append the given text to the output buffer.
--- If the text ends with a newline character, an additional newline will be added to the buffer.
--- The output thread will be woken up to send the buffered output to the debugger.
---
--- @param text string The text to be written to the debugger output.
--- @param bNewLine boolean If true, an additional newline will be added to the output buffer.
---
function OnMsg.ConsoleLine(text, bNewLine)
    if #text == 0 or not outputSocket or not outputThread then
        return
    end
    outputBuffer = outputBuffer or {}
    if bNewLine then
        outputBuffer[#outputBuffer + 1] = " \n"
    end
    outputBuffer[#outputBuffer + 1] = text
    Wakeup(outputThread)
end

---
--- Called when the debugger breaks execution.
---
--- This function is responsible for connecting the output socket to the debugger, if it is not already connected. It then wakes up the output thread and flushes the output socket to ensure any buffered output is sent to the debugger.
---
--- @function OnMsg.DebuggerBreak
--- @return nil
function OnMsg.DebuggerBreak()
    if not outputSocket then
        return
    end
    if not outputSocket:isconnected() then
        outputSocket:connect(controller_host, controller_port + 1)
    end
    Wakeup(outputThread)
    outputSocket:flush()
end
