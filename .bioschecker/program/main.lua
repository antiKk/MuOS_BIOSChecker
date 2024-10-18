-- main.lua

local mainScreen
local scanImage
local moreInfoImage
local exitImage
local resultSavedImage
local LastSavedResultOffline
local LastSavedResultOnline

--local instructionsImage  -- Variable for the instructions image
local currentImage
local resultScreenImage  -- New variable for the result screen image
local wifiWarningImage  -- Variable for the WiFi warning image

local scanningActive = false
local resultScreenActive = false
local resultScreen

local debounceTime = 0.2 -- Time debounce between key presses
local lastKeyPressTime = 0 -- Correct initialization

local keyPressed = false -- To avoid multiple firing of the "x" key

-- Font variable
local customFont
local boldFont

-- Variables for the submenu
local infoMenuImages = {}
local currentInfoImageIndex = 1
local isInfoMenuActive = false
local updateMessage = ""

local shortenedUrlPath
local logFilePath

local scanning = require("scanning")

-- muOS Variables
local appPath = "/mnt/mmc/MUOS/application/.bioschecker/"

-- Log file path
logFilePath = appPath .. "program/debuglog.txt"
shortenedUrlPath = appPath .. "SaveResult/shortenedUrl.txt"

-- Function to log messages to the debug file
local function logDebug(message)
    local logFile = io.open(logFilePath, "a") -- Open log file in append mode
    if logFile then
        logFile:write(os.date("%Y-%m-%d %H:%M:%S") .. " - " .. message .. "\n") -- Add timestamp
        logFile:close()
    else
        print("Failed to open log file for writing!")
    end
end

function love.load()
    -- Load images
    mainScreen = love.graphics.newImage("assets/Screen_Scan_Bios.png")
    scanImage = love.graphics.newImage("assets/Screen_Scan_Bios.png")
    moreInfoImage = love.graphics.newImage("assets/Screen_Settings.png")
    exitImage = love.graphics.newImage("assets/Screen_Exit.png")
    resultSavedImage = love.graphics.newImage("assets/resultSaved.png")

    -- Load instructions image
    Screen_Instructions_1_Image = love.graphics.newImage("assets/Screen_Instructions_1.png") -- Load the instructions image
    Screen_Instructions_2_Image = love.graphics.newImage("assets/Screen_Instructions_2.png") -- Load the instructions image
    -- resultScreenImage = love.graphics.newImage("assets/resultScreen.png") -- Load the result screen image
    wifiWarningImage = love.graphics.newImage("assets/Screen_WiFi_Warning.png") -- Load the WiFi warning image
    Screen_New_JSON = love.graphics.newImage("assets/Screen_New_JSON.png") -- Load the WiFi warning image
    Screen_No_New_JSON = love.graphics.newImage("assets/Screen_No_New_JSON.png") -- Load the WiFi warning image
    LastSavedResultOffline = love.graphics.newImage("assets/LastSavedResultOffline.png")
    LastSavedResultOnline = love.graphics.newImage("assets/LastSavedResultOnline.png")

    -- Load submenu images
    infoMenuImages = {
        love.graphics.newImage("assets/Screen_Information.png"),
        love.graphics.newImage("assets/Screen_Last_Save.png"),
        love.graphics.newImage("assets/Screen_Update.png"),
        love.graphics.newImage("assets/Screen_Return.png")
    }

    customFont = love.graphics.newFont("assets/NotoSans_Condensed-SemiBold.ttf", 22)
    boldFont = love.graphics.newFont("assets/NotoSans_Condensed-SemiBold.ttf", 22)

    -- Default image
    currentImage = scanImage

    -- Load scanning module
    scanning.load()

    -- Set window mode to fullscreen
    love.window.setMode(640, 480, {fullscreen = true, resizable = false, vsync = true})
    love.mouse.setVisible(false)
    font = love.graphics.newFont(12)
    love.graphics.setFont(font)

    -- Create debuglog.txt file if it doesn't exist
    if not love.filesystem.getInfo("debuglog.txt") then
        love.filesystem.write("debuglog.txt", "") -- Create an empty file
    end
end

local function checkInternetConnection()
    -- Ping Google's DNS server to check if there's an internet connection
    local command = "ping -c 1 8.8.8.8 > /dev/null 2>&1"
    local result = os.execute(command)

    -- Return true if the command succeeds (ping successful), false otherwise
    if result == 0 then
        return true
    else
        return false
    end
end

-- Function to check for updates
local updateMessage = "" -- Variable to store the message

function Check_For_Updates()
    -- Download the remote file
    local command =
        "curl -o " .. appPath .. "data/temp_bios_files.json http://uptothemoon.atwebpages.com/json/bios_files.json"
    os.execute(command)

    -- Read the local JSON file
    local localJsonPath = appPath .. "data/bios_files.json"
    local localJson

    -- Check if the local file exists
    local file = io.open(localJsonPath, "r")
    if file then
        localJson = file:read("*a")
        file:close()
    else
        logDebug("Error reading the local JSON file: " .. localJsonPath)
        return
    end

    -- Load the JSON library
    local json = require("json")

    -- Decode the local JSON
    local localData, localError = json.decode(localJson)
    if not localData then
        logDebug("Error decoding the local JSON file: " .. localError)
        return
    end

    -- Read the remote JSON file
    local remoteJsonPath = appPath .. "data/temp_bios_files.json"
    local remoteJson

    file = io.open(remoteJsonPath, "r")
    if file then
        remoteJson = file:read("*a")
        file:close()
    else
        logDebug("Error reading the remote JSON file: " .. remoteJsonPath)
        return
    end

    -- Decode the remote JSON
    local remoteData, remoteError = json.decode(remoteJson)
    if not remoteData then
        logDebug("Error decoding the JSON file: " .. remoteError)
        return
    end

    -- Compare the versions
    local localVersion = localData.version
    local remoteVersion = remoteData.version

    logDebug("Local Version: " .. tostring(localVersion))
    logDebug("Remote Version: " .. tostring(remoteVersion))

    if localVersion == remoteVersion then
        logDebug("The JSON file is Up-to-date.")
        currentImage = Screen_No_New_JSON
    else
        logDebug("The JSON file is not Up-to-date.")
        -- Path to old and temporary files
        local oldFilePath = appPath .. "data/bios_files.json"
        local tempFilePath = appPath .. "data/temp_bios_files.json"

        -- Delete the old JSON file
        local deleteOldFileResult = os.remove(oldFilePath)
        if deleteOldFileResult then
            logDebug("Successfully deleted old JSON file: " .. oldFilePath)
        else
            logDebug("Failed to delete old JSON file: " .. oldFilePath)
        end

        -- Rename temp file to the original file name
        local renameResult = os.rename(tempFilePath, oldFilePath)
        if renameResult then
            logDebug("Successfully renamed temp file to: " .. oldFilePath)
            currentImage = Screen_New_JSON
        else
            logDebug("Failed to rename temp file: " .. tempFilePath)
        end
        logDebug("The JSON file is not Up-to-date END.")
    end
end

-- Function to update the screen based on WiFi connection status
local function UpdateJSON()
    if checkInternetConnection() then
        -- If connected, show the update result image
        logDebug("Internet connection detected.")
        -- Call the Check_For_Updates function
        Check_For_Updates()
    else
        -- If not connected, show the WiFi warning image
        currentImage = wifiWarningImage
        logDebug("No internet connection, showing WiFi warning screen.")
    end
    isInfoMenuActive = false -- Deactivate the submenu when showing the warning image
end

function love.update(dt)
    -- Update debounce timer
    lastKeyPressTime = lastKeyPressTime + dt

    if resultScreenActive then
        resultScreen.update(dt) -- Update result screen
    elseif scanningActive then
        scanning.update(dt)
        if scanning.isComplete() then
            resultScreenActive = true
            scanningActive = false
            resultScreen = require("resultScreen") -- Load result screen module
            resultScreen.load(scanning.getResults()) -- Pass results to result screen
        end
    else
        -- Only handle navigation if submenu is not active
        if not isInfoMenuActive then
            -- Allow image change only if debounce time has passed
            if lastKeyPressTime >= debounceTime then
                if love.keyboard.isDown("left") then
                    if currentImage == scanImage then
                        currentImage = exitImage -- Go to last image when going back
                    elseif currentImage == moreInfoImage then
                        currentImage = scanImage -- Go to previous image (left)
                    elseif currentImage == exitImage then
                        currentImage = moreInfoImage -- Go to middle image
                    elseif currentImage == Screen_Instructions_2_Image then
                        currentImage = Screen_Instructions_1_Image -- Go back to the instructions image
                        logDebug("Changed to instructions screen from result screen.") -- Log action
                    end
                    lastKeyPressTime = 0 -- Reset debounce timer
                elseif love.keyboard.isDown("right") then
                    if currentImage == scanImage then
                        currentImage = moreInfoImage -- Go to middle image
                    elseif currentImage == moreInfoImage then
                        currentImage = exitImage -- Go to last image
                    elseif currentImage == exitImage then
                        currentImage = scanImage -- Go back to first image
                    elseif currentImage == Screen_Instructions_1_Image then
                        currentImage = Screen_Instructions_2_Image -- Change to the result screen image
                        logDebug("Changed to result screen from instructions.") -- Log action
                    end
                    lastKeyPressTime = 0 -- Reset debounce timer
                end
            end
        end

        -- Check if 'x' key is pressed
        if love.keyboard.isDown("x") then
            if not keyPressed then
                keyPressed = true
                if currentImage == wifiWarningImage then
                    -- Return to the main menu
                    currentImage = scanImage -- Set to the first main image
                    scanningActive = false
                    resultScreenActive = false
                    isInfoMenuActive = false
                    logDebug("Returned to main menu from WiFi warning screen.") -- Log action
                elseif currentImage == Screen_New_JSON then
                    -- Return to the main menu
                    currentImage = Screen_Update -- Change to 'instructions' if moreInfoImage is selected
                    isInfoMenuActive = true -- Activate submenu
                    currentInfoImageIndex = 3 -- Reset submenu index
                    logDebug("Screen_New_JSON - Returned to main menu from WiFi warning screen.") -- Log action
                elseif currentImage == Screen_No_New_JSON then
                    -- Return to the main menu
                    currentImage = Screen_Update -- Change to 'instructions' if moreInfoImage is selected
                    isInfoMenuActive = true -- Activate submenu
                    currentInfoImageIndex = 3 -- Reset submenu index
                    logDebug("Screen_No_New_JSON - Returned to main menu from WiFi warning screen.") -- Log action
                elseif currentImage == scanImage then
                    scanningActive = true -- Start scanning only if scanImage is selected
                    logDebug("Starting scan.") -- Log action
                elseif currentImage == moreInfoImage then
                    currentImage = Screen_Information -- Change to 'instructions' if moreInfoImage is selected
                    isInfoMenuActive = true -- Activate submenu
                    currentInfoImageIndex = 1 -- Reset submenu index
                    logDebug("Opening information menu.") -- Log action
                elseif currentImage == exitImage then
                    love.event.quit() -- Exit program if 'exitImage' is selected
                    logDebug("Exiting program.") -- Log action
                elseif currentImage == Screen_Instructions_1_Image then
                    currentImage = Screen_Information -- Change to 'instructions' if moreInfoImage is selected
                    isInfoMenuActive = true -- Activate submenu when pressing "X" on instructions screen
                    currentInfoImageIndex = 1 -- Reset submenu index
                    logDebug("Returned to information menu from instructions. Image 1") -- Log action
                elseif currentImage == Screen_Instructions_2_Image then
                    currentImage = Screen_Information -- Change to 'instructions' if moreInfoImage is selected
                    isInfoMenuActive = true -- Activate submenu when pressing "X" on instructions screen
                    currentInfoImageIndex = 1 -- Reset submenu index
                    logDebug("Returned to information menu from instructions. Image 2") -- Log action
                elseif currentImage == LastSavedResultOnline then
                   -- Return to the main menu
                    currentImage = Screen_Last_Save -- Change to 'instructions' if moreInfoImage is selected
                    isInfoMenuActive = true -- Activate submenu when pressing "X" on instructions screen
                    currentInfoImageIndex = 2 -- Reset submenu index
                    logDebug("#2 - currentImage == LastSavedResultOnline") -- Log action
                elseif currentImage == LastSavedResultOffline then
                   -- Return to the main menu
                    currentImage = Screen_Last_Save -- Change to 'instructions' if moreInfoImage is selected
                    isInfoMenuActive = true -- Activate submenu when pressing "X" on instructions screen
                    currentInfoImageIndex = 2 -- Reset submenu index
                    logDebug("#3 - currentImage == LastSavedResultOffline") -- Log action
                elseif currentImage == infoMenuImages[3] then -- Check if update image is active
                    logDebug("Check for updates. Image 3") -- Log action
                    UpdateJSON() -- Call UpdateJSON to show the warning image
                elseif isInfoMenuActive then
                    logDebug("Info menu is active, checking for selection.")
                    -- Submenu actions
                    if currentInfoImageIndex == 1 then
                        currentImage = Screen_Instructions_1_Image -- Change to instructions image
                        isInfoMenuActive = false -- Deactivate submenu after opening instructions
                        logDebug("Opened Instructions screen") -- Log action

                    elseif currentInfoImageIndex == 2 then
                        logDebug("currentInfoImageIndex == 2") -- Log action

                        local file = io.open(shortenedUrlPath, "r")

                        if file then
                            -- Read the first line from the file
                            shortUrl = file:read("*l")
                            logDebug("First line of the file: "..shortUrl) -- Log action
                            -- Close the file after reading
                            file:close()
                            currentImage = LastSavedResultOnline -- Change to instructions image
                            isInfoMenuActive = false -- Deactivate submenu
                            logDebug("File Found.") -- Log action
                        else
                            -- File not found
                            currentImage = LastSavedResultOffline -- Change to instructions image
                            logDebug("File not found") -- Log action
                            isInfoMenuActive = false -- Deactivate submenu after opening instructions
                         end



                    elseif currentInfoImageIndex == 3 then
                        logDebug("#1 - Screen_Update selected, calling UpdateJSON()")
                        UpdateJSON() -- Call UpdateJSON to show the warning image
                        elseif currentInfoImageIndex == 4 then
                            currentImage = moreInfoImage  -- Go back to information image
                            isInfoMenuActive = false  -- Deactivate submenu
                        logDebug("Returning to main menu.") -- Log action
                    end
                end
            end
        else
            keyPressed = false -- Reset when 'x' is not pressed
        end

        -- Logic for submenu, if active
        if isInfoMenuActive then
            if lastKeyPressTime >= debounceTime then
                if love.keyboard.isDown("left") then
                    currentInfoImageIndex = currentInfoImageIndex - 1
                    if currentInfoImageIndex < 1 then
                        currentInfoImageIndex = #infoMenuImages -- Go back to last image
                    end
                    lastKeyPressTime = 0 -- Reset debounce timer
                    logDebug("Moving left in submenu, new index: " .. currentInfoImageIndex) -- Log action
                elseif love.keyboard.isDown("right") then
                    currentInfoImageIndex = currentInfoImageIndex + 1
                    if currentInfoImageIndex > #infoMenuImages then
                        currentInfoImageIndex = 1 -- Go back to first image
                    end
                    lastKeyPressTime = 0 -- Reset debounce timer
                    logDebug("Moving right in submenu, new index: " .. currentInfoImageIndex) -- Log action
                end
            end
        end

        -- New logic: Change to resultScreenImage when instructionsImage is active and right key is pressed
        if currentImage == Screen_Instructions_1_Image and love.keyboard.isDown("right") then
            currentImage = Screen_Instructions_2_Image -- Change to the result screen image
            logDebug("Changed to result screen from instructions.") -- Log action
        end
    end
end

function love.draw()
    --logDebug("Current image before draw: " .. tostring(currentImage))
    love.graphics.setColor(1, 1, 1) -- Set color to white
    if resultScreenActive then
        resultScreen.draw() -- Draw result screen
    elseif scanningActive then
        scanning.draw() -- Draw scanning screen
    else
        if currentImage == wifiWarningImage then
            logDebug("currentImage == wifiWarningImage") -- Log action
            love.graphics.draw(currentImage, 0, 0) -- Draw warning image
        elseif isInfoMenuActive then
            love.graphics.draw(infoMenuImages[currentInfoImageIndex], 0, 0) -- Draw submenu based on index
        elseif currentImage == LastSavedResultOnline then
            love.graphics.draw(infoMenuImages[2], 0, 0)
            love.graphics.draw(LastSavedResultOnline, 0, 0)
            love.graphics.setFont(customFont)
            love.graphics.setColor(0, 0, 0)
            local textWidth = love.graphics.getFont():getWidth(shortUrl)
            local centerX = (love.graphics.getWidth() - textWidth) / 2
            love.graphics.print(shortUrl, 200, 270) -- Adjust the Y position as needed
        elseif currentImage == LastSavedResultOffline then
            love.graphics.draw(infoMenuImages[2], 0, 0)
            love.graphics.draw(LastSavedResultOffline, 0, 0)
            logDebug("55") -- Log action
        -- elseif currentInfoImageIndex == 4 then
        --    currentImage = moreInfoImage -- Go back to information image
        --    isInfoMenuActive = false -- Deactivate submenu
        elseif isInfoMenuActive then
            love.graphics.draw(infoMenuImages[currentInfoImageIndex], 0, 0) -- Draw submenu based on index
        else
            love.graphics.draw(currentImage, 0, 0) -- Draw current image
        end
    end
end
