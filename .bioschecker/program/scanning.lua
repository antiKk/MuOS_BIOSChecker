-- scanning.lua

-- muOS Variables
local appPath = "/mnt/mmc/MUOS/application/.bioschecker/"

-- Add the libs directory to the package path
package.path = package.path .. ";" .. appPath .. "libs/?.lua"

local finishScanSound

local json = require("json")
local adler32 = require("adler32")

local scanning = {}

local biosDir = "/run/muos/storage/bios/"
local jsonPath = appPath .. "data/bios_files.json"
local results = {}
local progress = 0
local totalSystems = 0
local currentSystemIndex = 0
-- Font variable
local customFont
local boldFont

local scanningImage
local scanningComplete = false

-- Log file path
local logFilePath = appPath .. "program/debuglog.txt"

-- Function to write to the debug log
local function writeDebugLog(message)
    local logFile = io.open(logFilePath, "a")  -- Open log file in append mode
    if logFile then
        logFile:write(os.date("%Y-%m-%d %H:%M:%S") .. " - " .. message .. "\n")  -- Add timestamp
        logFile:close()
    else
        print("Failed to open log file for writing!")
    end
end


-- Load fonts and handle errors
local function loadFonts()
        writeDebugLog("Loading fonts...")
    customFont = love.graphics.newFont("assets/NotoSans_Condensed-SemiBold.ttf", 22)
    boldFont = love.graphics.newFont("assets/NotoSans_Condensed-SemiBold.ttf", 22)

    if not customFont then
        writeDebugLog("Error loading custom font: assets/NotoSans_Condensed-SemiBold.ttf")
    end

    if not boldFont then
        writeDebugLog("Error loading bold font: assets/NotoSans_Condensed-SemiBold.ttf")
    end
end


-- Function to check if a file exists
local function fileExists(filePath)
    local file = io.open(filePath, "r")
    if file then
        file:close()
        return true
    else
        return false
    end
end

-- Function to get the size of a file
local function getFileSize(filePath)
    local file = io.open(filePath, "rb")
    if file then
        local size = file:seek("end")
        file:close()
        return size
    else
        return nil
    end
end

-- Function to read a file's content
local function readFile(filePath)
    local file = io.open(filePath, "rb")
    if not file then
        return nil
    end
    local content = file:read("*all")
    file:close()
    return content
end

-- Example of initializing or computing Adler-32 checksum
local function calculateAdler32(filePath)
    -- Get file size
    local fileSize = getFileSize(filePath)
    if fileSize then
        -- Read the file content
        local content = readFile(filePath)
        if content then
            -- Calculate Adler-32 checksum
            local fileAdler32 = adler32.checksum(content)  -- Use the checksum method
            return fileAdler32
        else
            return nil
        end
    else
        return nil
    end
end

-- Function to check if a directory is empty
local function isDirEmpty(dirPath)
    local handle = io.popen("ls -A " .. dirPath)
    local result = handle:read("*a")
    handle:close()
    return result == ""
end

-- Function to check both directories and handle empty folder cases


-- Banana Release
 --local function checkBiosDir()
 --   writeDebugLog("Looking for BIOS: " .. biosDir)
 --   if not isDirEmpty("/run/muos/storage/bios") then
 --       -- biosDir = "/run/muos/storage/bios"
 --       writeDebugLog("BIOS found in: " .. biosDir)
 --   else
 --       writeDebugLog("No BIOS found.")
 --       return false -- No BIOS found
 --   end
 --   return true -- BIOS directory found
 --end

-- Function to check both directories and handle empty folder cases
local function checkBiosDir()
    if not isDirEmpty(biosDir) then
        writeDebugLog("BIOS found.")
        return true -- BIOS directory found
    else
        writeDebugLog("No BIOS found.")
        return false -- No BIOS found
    end
end

-- Function to load and parse JSON
local function loadJson(filePath)
    local content = readFile(filePath)
    if content then
        local status, jsonData = pcall(json.decode, content)
        if status then
            return jsonData
        else
            writeDebugLog("Error decoding JSON: " .. tostring(jsonData))
            return nil
        end
    else
        writeDebugLog("Error reading JSON file.")
        return nil
    end
end

-- Function to load the JSON configuration file and images
function scanning.load()
    loadFonts()  -- Load fonts here
    if not checkBiosDir() then
        love.window.showMessageBox("Error", "No BIOS found in both directories.", "info")
        return
    end

    local data = loadJson(jsonPath)
    
    if data then
        results = {}
        -- Iterate through the JSON data, skipping any non-system fields
        for system, info in pairs(data) do
            if system ~= "date" and system ~= "version" then  -- Skip the new top-level fields
                table.insert(results, {
                    system = system,
                    name = info.name,
                    folder = info.Folder,
                    files = info.biosFiles,
                    status = "Pending"
                })
            end
        end
        totalSystems = #results
    end

    font = love.graphics.newFont(30)  -- Create a font object for text
    scanningImage = love.graphics.newImage("assets/ScanningScreen.png")  -- Load the scanning image

    -- Load the finish scan sound
    finishScanSound = love.audio.newSource("assets/FinishScan.wav", "static")
end


-- Function to update the scanning progress
function scanning.update(dt)
    if not scanningComplete then
        if currentSystemIndex < totalSystems then
            currentSystemIndex = currentSystemIndex + 1
            local systemInfo = results[currentSystemIndex]
            scanning.verifySystem(systemInfo)
            progress = (currentSystemIndex / totalSystems) * 100
        else
            scanningComplete = true

            -- Play the sound when the scanning is complete
            if finishScanSound then
                love.audio.play(finishScanSound)
            end
        end
    end
end

-- Function to draw the scanning progress on the screen
function scanning.draw()
    if scanningComplete then
        love.graphics.setColor(1, 1, 1)
        if scanningImage then
            love.graphics.draw(scanningImage, 0, 0)
        end
    else
        love.graphics.setColor(1, 1, 1)
        if scanningImage then
            love.graphics.draw(scanningImage, 0, 0)
        end

        love.graphics.setFont(customFont)
        love.graphics.setColor(0, 0, 0)  -- Set text color to black

        -- Texts to display
        -- System X of Y
        local systemText = string.format("System %d of %d", currentSystemIndex, totalSystems)

        local nameText = results[currentSystemIndex] and results[currentSystemIndex].name or "Loading..."
        local progressText = string.format("Progress: %.2f%%", progress)

        -- File being scanned
        local currentFile = results[currentSystemIndex] and results[currentSystemIndex].files[1] and results[currentSystemIndex].files[1].file or "Loading..."

        -- Calculate positions to center text and progress bar vertically
        local screenWidth = love.graphics.getWidth()
        local screenHeight = love.graphics.getHeight()

        local textY = screenHeight / 2 - 85  -- Center text vertically with additional 30 pixels down
        -- local progressY = textY + font:getHeight() * 2 + 10  -- Move progress bar down by 15 pixels plus some spacing
        local progressY = 200  -- Move progress bar down by 15 pixels plus some spacing
        local fileTextY = progressY + 50  -- Set the file name below the progress bar

        local textX = (screenWidth - font:getWidth(systemText)) / 2
        local nameX = (screenWidth - font:getWidth(nameText)) / 2
        -- local progressX = (screenWidth - 400) / 2  -- Center the progress bar
        local progressX = 170  -- Center the progress bar
        local fileTextX = (screenWidth - font:getWidth(currentFile)) / 2  -- Center the file name text

        -- Draw text above the progress bar
        -- -- System X of Y
        love.graphics.print(systemText, textX, textY)
        -- CORE NAME
        love.graphics.print(nameText, nameX, textY + 25)  -- Offset below system text
        -- Draw progress bar
        love.graphics.setColor(0.2, 0.2, 0.2)  -- Dark gray for background
        love.graphics.rectangle("fill", progressX, 210, 400, 30)
        love.graphics.setColor(0, 1, 0)  -- Green for progress
        love.graphics.rectangle("fill", progressX, 210, 400 * (progress / 100), 30)
        love.graphics.setColor(1, 1, 1)  -- White for text
        love.graphics.print(progressText, (screenWidth - font:getWidth(progressText)) / 2, progressY + (30 - font:getHeight()) / 2)
        -- Draw the file name below the progress bar
        love.graphics.setColor(0, 0, 0)  -- Black for file name text
        love.graphics.print(currentFile, fileTextX, fileTextY)
    end
end

-- Function to verify the BIOS files for a specific system
function scanning.verifySystem(systemInfo)
    -- Initialize the results table if it doesn't exist
    systemInfo.results = systemInfo.results or {}

    for _, fileInfo in ipairs(systemInfo.files) do
        local filePath = biosDir .. fileInfo.file
        if fileExists(filePath) then
            local fileAdler32 = calculateAdler32(filePath)
            if fileAdler32 == fileInfo.adler32Checksum then
                table.insert(systemInfo.results, {
                    file = fileInfo.file,
                    status = "BIOS OK"
                })
            else
                table.insert(systemInfo.results, {
                    file = fileInfo.file,
                    status = "Wrong BIOS",
                    computedChecksum = fileAdler32,
                    expectedChecksum = fileInfo.adler32Checksum,
                    md5Checksum = fileInfo.MD5  -- Store the MD5 checksum from the JSON
                })
            end
        else
            table.insert(systemInfo.results, {
                file = fileInfo.file,
                status = "BIOS Not Found",
                computedChecksum = fileAdler32,
                expectedChecksum = fileInfo.adler32Checksum,
                md5Checksum = fileInfo.MD5  -- Store the MD5 checksum from the JSON
            })

        end
    end

    -- Update the system status based on individual file results
    if not systemInfo.results or #systemInfo.results == 0 then
        systemInfo.status = "No Files Found"
    else
        for _, result in ipairs(systemInfo.results) do
            if result.status ~= "BIOS OK" then
                systemInfo.status = "Failed"
                return
            end
        end
        systemInfo.status = "Passed"
    end
end

-- Function to check if the scanning is complete
function scanning.isComplete()
    return scanningComplete
end

-- Function to get the results for the result screen
function scanning.getResults()
    return results
end

return scanning