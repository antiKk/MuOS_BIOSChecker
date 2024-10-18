-- resultScreen.lua

local resultScreen = {}

local resultImage
local saveResultImage
local exitResultImage
local resultSavedImage
local currentImage
local results = {}
local scrollOffset = 0
local scrollSpeed = 900  -- Control the scrolling speed
local savedFilename = ""

-- Scrolling cursor variables
local scrollCursorImage
local scrollCursorMinY = 80
local scrollCursorMaxY = 400

-- Font variable
local customFont
local boldFont

-- Flag to indicate if results have been saved
local resultsSaved = false
local resultsSavedTime = 0
local resultsSavedDuration = 50  -- Duration in seconds to display resultSavedImage
local resultBackImage = love.graphics.newImage("assets/Screen_Result_Back.png")
local currentImage = resultBackImage  -- Assuming this is the image currently displayed

-- muOS Variables
local appPath = "/mnt/mmc/MUOS/application/.bioschecker/"

-- Log file path
local logFilePath = appPath .. "program/debuglog.txt"

-- Function to log messages to the debug log
local function logDebug(message)
    local logFile = io.open(logFilePath, "a")  -- Open the log file in append mode
    if logFile then
        logFile:write(os.date("%Y-%m-%d %H:%M:%S") .. " - " .. message .. "\n")  -- Add timestamp
        logFile:close()
    else
        print("Failed to open log file for writing!")
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

-- Function to handle keypress events
function love.keypressed(key)
    if resultsSaved then
        if key == "x" then
            resultsSaved = false
            resultsSavedTime = 0
            currentImage = exitResultImage
        end
    else
        if key == "left" then
            currentImage = saveResultImage
        elseif key == "right" then
            currentImage = exitResultImage
        end

        if key == "x" then
            if currentImage == saveResultImage then
                saveResultsToFile()
                resultsSaved = true
                currentImage = resultImage
            elseif currentImage == exitResultImage then
                love.event.quit()
            end
        end
    end
end

local function generateRandomString(length)
    local charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local result = ""
    for i = 1, length do
        local randomIndex = love.math.random(1, #charset)
        result = result .. charset:sub(randomIndex, randomIndex)
    end
    return result
end

function resultScreen.load(scanResults)
    math.randomseed(os.time())  -- Seed the random number generator

    results = scanResults
    resultImage = love.graphics.newImage("assets/Screen_Result_Back.png")
    saveResultImage = love.graphics.newImage("assets/Screen_Result_Save.png")
    exitResultImage = love.graphics.newImage("assets/Screen_Result_Back.png")
    resultSavedImage = love.graphics.newImage("assets/resultSaved.png")
    currentImage = saveResultImage
    scrollCursorImage = love.graphics.newImage("assets/ScroolResult.png")
    customFont = love.graphics.newFont("assets/NotoSans_Condensed-SemiBold.ttf", 22)
    boldFont = love.graphics.newFont("assets/NotoSans_Condensed-SemiBold.ttf", 22)

    local scrollCursorHeight = scrollCursorImage:getHeight()
    scrollCursorMaxY = 430 - scrollCursorHeight
end

function resultScreen.update(dt)
    if resultsSaved then
        resultsSavedTime = resultsSavedTime + dt
        if resultsSavedTime >= resultsSavedDuration then
            resultsSaved = false
            resultsSavedTime = 0
            if love.keyboard.isDown("left") then
                currentImage = saveResultImage
            elseif love.keyboard.isDown("right") then
                currentImage = exitResultImage
            end
        end
    end

    if love.keyboard.isDown("down") then
        local maxScroll = calculateMaxScroll()
        scrollOffset = math.min(maxScroll, scrollOffset + scrollSpeed * dt)
    end

    if love.keyboard.isDown("end") then
        local maxScroll = calculateMaxScroll()
        scrollOffset = math.min(maxScroll, scrollOffset + 80)  -- Add 80 pixels
    end

    if love.keyboard.isDown("up") then
        scrollOffset = math.max(0, scrollOffset - scrollSpeed * dt)
    end

    if love.keyboard.isDown("home") then
        scrollOffset = math.max(0, scrollOffset - 80)  -- Subtract 80 pixels
    end
end

function calculateMaxScroll()
    local contentHeight = 70  -- Initial Y position

    -- Iterate through results and calculate total content height
    for _, result in ipairs(results) do
        contentHeight = contentHeight + 25  -- Space for the system name

        -- Loop through file results and add the corresponding height
        for _, fileResult in ipairs(result.results) do
            if fileResult.status == "Wrong BIOS" or fileResult.status == "BIOS Not Found" then
                contentHeight = contentHeight + 50  -- Two lines (status + MD5) with extra padding
            else
                contentHeight = contentHeight + 30  -- Single line for other statuses
            end
        end

        -- If BIOS is missing, add space for each missing file
        if result.status == "BIOS Not Found" then
            contentHeight = contentHeight + 30  -- "Missing BIOS" label with extra padding
            contentHeight = contentHeight + (#result.missingFiles * 30)  -- Each missing file
        end

        contentHeight = contentHeight + 40  -- Add extra space between systems for clarity
    end

    -- Get the height of the visible area (403 - 52)
    local viewportHeight = 143 - 52

    -- Calculate the maximum scroll offset
    return math.max(0, contentHeight - viewportHeight)
end






function shortenUrl(url)
    -- Prepare the command for the curl request
    local command = string.format('curl -s "https://is.gd/create.php?format=simple&url=%s"', url)
    
    -- Execute the curl command and capture the output
    local handle = io.popen(command)
    local shortenedUrl = handle:read("*a")
    handle:close()
    
    -- Create the directory if it doesn't exist
    os.execute("mkdir -p " .. appPath .. "SaveResult")
    
    -- Specify the file path
    local filePath = appPath .. "SaveResult/shortenedUrl.txt"
    
    -- Delete the existing file if it exists
    os.remove(filePath)
    
    -- Open the file in write mode and save the shortened URL
    local file = io.open(filePath, "w")
    if file then
        file:write(shortenedUrl)
        file:close()
        print("Shortened URL saved to " .. filePath)
    else
        print("Error: Could not open file to save shortened URL.")
    end
    
    -- Return the shortened URL
    return shortenedUrl
end


-- Draws the result screen
function resultScreen.draw()
    love.graphics.setColor(1, 1, 1)
    if currentImage then
        love.graphics.draw(currentImage, 0, 0)
    else
        logDebug("Current image not loaded!")  -- Log the message
    end

    love.graphics.setFont(customFont)

    -- Define the area for scrolling
    love.graphics.setScissor(20, 52, 547, 351)
    local y = 70 - scrollOffset  -- Apply the scroll offset here

    for _, result in ipairs(results) do
        love.graphics.setColor(0, 0, 0)
        love.graphics.setFont(customFont)
        love.graphics.print(string.format("System: %s", result.name), 50, y)
        y = y + 25

        -- Loop through file results
        for _, fileResult in ipairs(result.results) do
            local fileStatusText
            if fileResult.status == "Wrong BIOS" then
                fileStatusText = string.format("   %s - %s", fileResult.file, fileResult.status)
                local md5Checksum = string.format("   MD5: %s", fileResult.md5Checksum or "Not Available")
                love.graphics.setColor(1, 0, 0)
                love.graphics.print(fileStatusText, 50, y)
                y = y + 20  -- Increment Y by 20

                love.graphics.print(md5Checksum, 50, y)
                y = y + 20  -- Increment again for the checksum line
            elseif fileResult.status == "BIOS Not Found" then
                fileStatusText = string.format("  - %s - %s", fileResult.file, fileResult.status)
                local md5Checksum = string.format("  - MD5: %s", fileResult.md5Checksum or "Not Available")
                love.graphics.setColor(1, 0, 0)
                love.graphics.print(fileStatusText, 50, y)
                y = y + 25  -- More space for this condition

                love.graphics.print(md5Checksum, 50, y)
                y = y + 20  -- Increment again for the checksum line
            else
                local fileStatusTextPart1 = string.format("   %s - ", fileResult.file)
                local fileStatusTextPart2 = fileResult.status

                love.graphics.setColor(0, 0, 0)
                love.graphics.print(fileStatusTextPart1, 50, y)

                love.graphics.setColor(0, 1, 0)
                love.graphics.print(fileStatusTextPart2, 50 + love.graphics.getFont():getWidth(fileStatusTextPart1), y)
            end
            y = y + 25  -- Ensure each item gets proper space after every file result
        end

        y = y + 30  -- Add some space between systems

        -- Check for missing BIOS
        if result.status == "BIOS Not Found" then
            love.graphics.setColor(0, 0, 0)
            love.graphics.print("   Missing BIOS:", 50, y)
            y = y + 20
            for _, missingFile in ipairs(result.missingFiles) do
                love.graphics.print(missingFile, 70, y)
                y = y + 20
            end
        end
    end
    love.graphics.setScissor()  -- Reset scissor after rendering


    local maxScroll = calculateMaxScroll()
    local scrollFraction = scrollOffset / maxScroll
    local scrollCursorY = scrollCursorMinY + (scrollCursorMaxY - scrollCursorMinY) * scrollFraction

    love.graphics.setColor(1, 1, 1)
    if scrollCursorImage then
        love.graphics.draw(scrollCursorImage, 586, scrollCursorY)
    else
        logDebug("Scroll cursor image not loaded!")  -- Log the message
    end



    -- Display the resultSavedImage if results have been saved
    if resultsSaved then
            if checkInternetConnection() then
                love.graphics.draw(resultSavedImage, 0, 0)
                -- Example URL
                local url = "http://uptothemoon.atwebpages.com/logs/" .. savedFilename            
                -- Shorten the URL using the function
                local shortUrl = shortenUrl(url)
                -- Print the shortened URL to the console
                logDebug("Shortened URL: " .. shortUrl)

                -- Set the font and color for the URL text
               love.graphics.setFont(customFont)
               love.graphics.setColor(0, 0, 0)  -- Set text color to black

                -- Get the width of the URL text for centering
                local textWidth = love.graphics.getFont():getWidth(url)
                
                -- Calculate the center position
                local centerX = (love.graphics.getWidth() - textWidth) / 2
                
                -- Draw the URL text below the resultSavedImage
                love.graphics.print(shortUrl, 200, 270)  -- Adjust the Y position as needed
            else


                local error = "No Internet Available to upload the result."
                love.graphics.draw(resultSavedImage, 0, 0)
                -- Set the font and color for the URL text
                love.graphics.setFont(customFont)
                love.graphics.setColor(1, 0, 0)  -- Set text color to black

                -- Get the width of the URL text for centering
                local textWidth = love.graphics.getFont():getWidth(error)
                
                -- Calculate the center position
                local centerX = (love.graphics.getWidth() - textWidth) / 2
                
                -- Draw the URL text below the resultSavedImage
                love.graphics.print(error, 100, 270)  -- Adjust the Y position as needed
            end
    end
end

function saveResultsToFile()
    -- Generate a random string for the filename
    local randomString = ""
    for _ = 1, 6 do
        local randomChar = string.char(math.random(48, 122))
        if (randomChar >= '0' and randomChar <= '9') or (randomChar >= 'A' and randomChar <= 'Z') or (randomChar >= 'a' and randomChar <= 'z') then
            randomString = randomString .. randomChar
        end
    end

    -- Set the savedFilename variable
    savedFilename = randomString .. ".txt"  -- Add .txt extension

    local directory = appPath .. "SaveResult"
    local filename = string.format("%s/%s", directory, savedFilename)

    os.execute(string.format("mkdir -p %s", directory))

    local file = io.open(filename, "w")

    if file then
        for _, result in ipairs(results) do
            file:write(string.format("System: %s\n", result.name))
            file:write("Status:\n")

            for _, fileInfo in ipairs(result.results) do
                if fileInfo.status == "Wrong BIOS" then
                    file:write(string.format(" - %s - Wrong BIOS\n", fileInfo.file))
                    file:write(string.format("   MD5: %s\n", fileInfo.md5Checksum))
                elseif fileInfo.status == "BIOS Not Found" then
                    file:write(string.format(" - %s - BIOS Not Found\n", fileInfo.file))
                    file:write(string.format("   MD5: %s\n", fileInfo.md5Checksum))
                else
                    local fileStatus = fileInfo.status or "Unknown"
                    file:write(string.format(" - %s - %s\n", fileInfo.file, fileStatus))
                end
            end

            if result.status == "BIOS Not Found" and result.missingFiles then
                file:write("   Missing BIOS:\n")
                for _, missingFile in ipairs(result.missingFiles) do
                    file:write(string.format("  %s\n", missingFile))
                end
            end

            if result.status == "Wrong BIOS" and result.missingFiles then
                file:write("   Files with Wrong BIOS:\n")
                for _, wrongFile in ipairs(result.missingFiles) do
                    file:write(string.format("  %s\n", wrongFile))
                end
            end

            file:write("\n")
        end

        file:close()
        logDebug("Results saved to " .. filename)  -- Log the save action
        
        -- Call the function to upload the file
        uploadFileToServer(filename)
    else
        logDebug("Failed to open file for writing!")  -- Log the failure
    end
end


function uploadFileToServer(filename)
    local uploadUrl = "http://uptothemoon.atwebpages.com/logs/upload.php"
    local uploadCommand = string.format("curl -X POST \"%s\" -F \"file=@%s\"", uploadUrl, filename)

    -- Execute the curl command to upload the file
    local success = os.execute(uploadCommand)

    if success then
        logDebug("File successfully uploaded to server!")  -- Log success
    else
        logDebug("Error uploading the file to the server.")  -- Log error
    end
end

return resultScreen
