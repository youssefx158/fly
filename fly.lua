--[[
  Integrated script for Roblox games (e.g. Blox Fruits) that includes:
    - Flight mode with adjustable speed and phasing through walls.
    - WalkSpeed adjustment (Speed Boost).
    - Players tab: Draw circles around players, vanish option, teleport (sticky teleport), pull, and spectate.
    - Lighting tab: Adjust game brightness (increase, decrease, or set a specific value).

  Sticky Teleport: 
    Continuously checks if the selected player is valid. If available (has a Character with a Head),
    your character will be teleported to them. If the target dies or is temporarily unavailable,
    the script will wait until they respawn—unless you cancel sticky teleport.

  NOTE:
    - This version places the ScreenGui in CoreGui to ensure it stays above other interfaces.
    - The code has been improved with additional checks and error handling so that it works
      in any system/map without relying on a specific interface.
    
  Instructions:
    - Place this script in StarterPlayer > StarterPlayerScripts.
    - Use shortcuts (e.g. F for toggling flight, CTRL to toggle UI).
    - In the Players tab, use the "انتقال" button to toggle sticky teleportation.
    - In the Lighting tab, adjust game brightness as needed.
--]]

---------------------------------------------
-- Services and Variables
---------------------------------------------
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer

---------------------------------------------
-- Flight Variables
---------------------------------------------
local flying = false
local flightSpeed = 50             -- Current flight speed.
local flightSpeedIncrement = 10    -- Increment value.
local bodyGyro, bodyVelocity
local flightControl = { N = false, S = false, E = false, W = false, Up = false, Down = false }

---------------------------------------------
-- Speed (WalkSpeed) Variables
---------------------------------------------
local speedBoostActive = false
local boostedSpeed = 50            -- Current WalkSpeed.
local speedIncrement = 5           -- Increment value.
local originalWalkSpeed = 16       -- Default WalkSpeed.

---------------------------------------------
-- Auto-Increase Variables (for holding buttons)
---------------------------------------------
local autoIncreasingFlight = false
local autoIncreaseAccumulatorFlight = 0
local autoIncreasingSpeed = false
local autoIncreaseAccumulatorSpeed = 0
local autoIncreaseInterval = 0.1

---------------------------------------------
-- Players Tab Variables, Vanish, Teleport, etc.
---------------------------------------------
local playersCirclesEnabled = false
local playerCircles = {}         -- key: player, value: Drawing Circle object
local nameLabels = {}            -- key: player, value: BillboardGui
local vanishActive = false

-- For players list feature:
local selectedPlayer = nil       -- The selected target player.
local playerListFrame = nil      -- Frame that holds the players list.
local teleportSelectedButton = nil  -- Button to toggle sticky teleport.

-- Sticky Teleport, Pull and Spectate variables:
local stickyTeleportActive = false
local pullActive = false         -- Toggle for continuous pull
local spectateActive = false

---------------------------------------------
-- Lighting Variables
---------------------------------------------
local brightnessIncrement = 0.5    -- Increment value for brightness.

---------------------------------------------
-- Helper Functions
---------------------------------------------
local function createCircle()
  local circle = Drawing.new("Circle")
  circle.Visible = true
  circle.Transparency = 1
  circle.Color = Color3.new(0, 1, 0)      -- Green.
  circle.Thickness = 2
  circle.NumSides = 100
  circle.Radius = 50                     -- Adjust based on camera FOV.
  return circle
end

local function createNameLabel(targetPlayer)
  local billboard = Instance.new("BillboardGui")
  billboard.Name = "NameLabel"
  billboard.Adornee = targetPlayer.Character and targetPlayer.Character:FindFirstChild("Head")
  billboard.Size = UDim2.new(0,150,0,50)
  billboard.StudsOffset = Vector3.new(0,2.5,0)
  billboard.AlwaysOnTop = true

  local textLabel = Instance.new("TextLabel", billboard)
  textLabel.Size = UDim2.new(1,0,1,0)
  textLabel.BackgroundTransparency = 1
  textLabel.Text = targetPlayer.Name
  textLabel.TextColor3 = Color3.new(1,1,1)
  textLabel.TextStrokeTransparency = 0
  textLabel.TextScaled = true
  textLabel.Font = Enum.Font.SourceSansBold
  return billboard
end

local function getCharacter()
  return player.Character or player.CharacterAdded:Wait()
end

---------------------------------------------
-- Flight Functions (with Phasing)
---------------------------------------------
local function enableFlight(character)
  local humanoid = character:FindFirstChildOfClass("Humanoid")
  if humanoid then
    humanoid.PlatformStand = true
  end
  local root = character:WaitForChild("HumanoidRootPart")
  
  local gyro = Instance.new("BodyGyro", root)
  gyro.P = 90000
  gyro.MaxTorque = Vector3.new(90000,90000,90000)
  gyro.CFrame = root.CFrame
  
  local velocity = Instance.new("BodyVelocity", root)
  velocity.Velocity = Vector3.new(0,0,0)
  velocity.MaxForce = Vector3.new(90000,90000,90000)
  
  for _, part in ipairs(character:GetDescendants()) do
    if part:IsA("BasePart") then
      pcall(function() part.CanCollide = false end)
    end
  end
  
  return gyro, velocity
end

local function disableFlight(character, gyro, velocity)
  local humanoid = character:FindFirstChildOfClass("Humanoid")
  if humanoid then
    humanoid.PlatformStand = false
  end
  if gyro then gyro:Destroy() end
  if velocity then velocity:Destroy() end
  
  for _, part in ipairs(character:GetDescendants()) do
    if part:IsA("BasePart") then
      pcall(function() part.CanCollide = true end)
    end
  end
end

---------------------------------------------
-- WalkSpeed Functions
---------------------------------------------
local function enableSpeedBoost()
  local character = getCharacter()
  local humanoid = character:FindFirstChildOfClass("Humanoid")
  if humanoid then
    originalWalkSpeed = humanoid.WalkSpeed
    humanoid.WalkSpeed = boostedSpeed
  end
end

local function disableSpeedBoost()
  local character = getCharacter()
  local humanoid = character:FindFirstChildOfClass("Humanoid")
  if humanoid then
    humanoid.WalkSpeed = originalWalkSpeed
  end
end

---------------------------------------------
-- Vanish Functions
---------------------------------------------
local function enableVanish()
  local character = getCharacter()
  for _, part in ipairs(character:GetDescendants()) do
    if part:IsA("BasePart") then
      pcall(function() part.Transparency = 1; part.Reflectance = 0 end)
    elseif part:IsA("Decal") then
      pcall(function() part.Transparency = 1 end)
    end
  end
  if character:FindFirstChild("Animate") then
    character.Animate.Disabled = true
  end
end

local function disableVanish()
  local character = getCharacter()
  for _, part in ipairs(character:GetDescendants()) do
    if part:IsA("BasePart") then
      pcall(function() part.Transparency = 0 end)
    elseif part:IsA("Decal") then
      pcall(function() part.Transparency = 0 end)
    end
  end
  if character:FindFirstChild("Animate") then
    character.Animate.Disabled = false
  end
end

---------------------------------------------
-- Lighting Functions
---------------------------------------------
local function increaseLighting()
  Lighting.Brightness = Lighting.Brightness + brightnessIncrement
end

local function decreaseLighting()
  if Lighting.Brightness - brightnessIncrement >= 0 then
    Lighting.Brightness = Lighting.Brightness - brightnessIncrement
  end
end

local function setLighting(value)
  local newVal = tonumber(value)
  if newVal then
    Lighting.Brightness = newVal
  end
end

---------------------------------------------
-- UI Creation Function: Main Tabs (Flight, Speed, Players, Lighting)
---------------------------------------------
local function createMainUI()
  -- إنشاء الواجهة داخل CoreGui لضمان ظهورها فوق كل شيء
  local screenGui = Instance.new("ScreenGui")
  screenGui.Name = "FlightSpeedUI"
  screenGui.ResetOnSpawn = false
  screenGui.IgnoreGuiInset = true
  screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
  screenGui.DisplayOrder = 999999
  screenGui.Parent = CoreGui
  
  local mainFrame = Instance.new("Frame")
  mainFrame.Name = "MainFrame"
  mainFrame.Size = UDim2.new(0,350,0,300)
  mainFrame.Position = UDim2.new(0.5,-175,0.5,-150)
  mainFrame.BackgroundColor3 = Color3.fromRGB(20,20,20)
  mainFrame.BackgroundTransparency = 0.2
  mainFrame.Active = true
  mainFrame.Draggable = true
  mainFrame.Parent = screenGui
  
  local closeButton = Instance.new("TextButton", mainFrame)
  closeButton.Name = "CloseButton"
  closeButton.Size = UDim2.new(0,30,0,30)
  closeButton.Position = UDim2.new(1,-35,0,5)
  closeButton.BackgroundColor3 = Color3.fromRGB(200,50,50)
  closeButton.Text = "X"
  closeButton.TextColor3 = Color3.new(1,1,1)
  closeButton.Font = Enum.Font.SourceSansBold
  closeButton.TextSize = 18
  
  local tabWidth = 85
  local tabFlight = Instance.new("TextButton", mainFrame)
  tabFlight.Name = "TabFlight"
  tabFlight.Size = UDim2.new(0,tabWidth,0,30)
  tabFlight.Position = UDim2.new(0,0,0,0)
  tabFlight.BackgroundColor3 = Color3.fromRGB(70,130,180)
  tabFlight.Text = "الطيران"
  tabFlight.TextColor3 = Color3.new(1,1,1)
  tabFlight.Font = Enum.Font.SourceSansBold
  tabFlight.TextSize = 18
  
  local tabSpeed = Instance.new("TextButton", mainFrame)
  tabSpeed.Name = "TabSpeed"
  tabSpeed.Size = UDim2.new(0,tabWidth,0,30)
  tabSpeed.Position = UDim2.new(0,tabWidth,0,0)
  tabSpeed.BackgroundColor3 = Color3.fromRGB(100,100,100)
  tabSpeed.Text = "السرعة"
  tabSpeed.TextColor3 = Color3.new(1,1,1)
  tabSpeed.Font = Enum.Font.SourceSansBold
  tabSpeed.TextSize = 18
  
  local tabPlayers = Instance.new("TextButton", mainFrame)
  tabPlayers.Name = "TabPlayers"
  tabPlayers.Size = UDim2.new(0,tabWidth,0,30)
  tabPlayers.Position = UDim2.new(0,tabWidth*2,0,0)
  tabPlayers.BackgroundColor3 = Color3.fromRGB(100,100,100)
  tabPlayers.Text = "اللاعبين"
  tabPlayers.TextColor3 = Color3.new(1,1,1)
  tabPlayers.Font = Enum.Font.SourceSansBold
  tabPlayers.TextSize = 18
  
  local tabLighting = Instance.new("TextButton", mainFrame)
  tabLighting.Name = "TabLighting"
  tabLighting.Size = UDim2.new(0,tabWidth,0,30)
  tabLighting.Position = UDim2.new(0,tabWidth*3,0,0)
  tabLighting.BackgroundColor3 = Color3.fromRGB(100,100,100)
  tabLighting.Text = "الإضاءة"
  tabLighting.TextColor3 = Color3.new(1,1,1)
  tabLighting.Font = Enum.Font.SourceSansBold
  tabLighting.TextSize = 18
  
  local flightPanel = Instance.new("Frame", mainFrame)
  flightPanel.Name = "FlightPanel"
  flightPanel.Size = UDim2.new(1,0,0,260)
  flightPanel.Position = UDim2.new(0,0,0,30)
  flightPanel.BackgroundTransparency = 1
  
  local flightToggle = Instance.new("TextButton", flightPanel)
  flightToggle.Name = "FlightToggle"
  flightToggle.Size = UDim2.new(0,300,0,40)
  flightToggle.Position = UDim2.new(0,10,0,10)
  flightToggle.BackgroundColor3 = Color3.fromRGB(70,130,180)
  flightToggle.Text = "تشغيل الطيران"
  flightToggle.TextColor3 = Color3.new(1,1,1)
  flightToggle.Font = Enum.Font.SourceSansBold
  flightToggle.TextSize = 20
  
  local flightIncrease = Instance.new("TextButton", flightPanel)
  flightIncrease.Name = "FlightIncrease"
  flightIncrease.Size = UDim2.new(0,130,0,40)
  flightIncrease.Position = UDim2.new(0,10,0,70)
  flightIncrease.BackgroundColor3 = Color3.fromRGB(34,139,34)
  flightIncrease.Text = "زيادة السرعة"
  flightIncrease.TextColor3 = Color3.new(1,1,1)
  flightIncrease.Font = Enum.Font.SourceSansBold
  flightIncrease.TextSize = 20
  
  local flightDecrease = Instance.new("TextButton", flightPanel)
  flightDecrease.Name = "FlightDecrease"
  flightDecrease.Size = UDim2.new(0,130,0,40)
  flightDecrease.Position = UDim2.new(0,160,0,70)
  flightDecrease.BackgroundColor3 = Color3.fromRGB(178,34,34)
  flightDecrease.Text = "تقليل السرعة"
  flightDecrease.TextColor3 = Color3.new(1,1,1)
  flightDecrease.Font = Enum.Font.SourceSansBold
  flightDecrease.TextSize = 20
  
  local flightSpeedLabel = Instance.new("TextLabel", flightPanel)
  flightSpeedLabel.Name = "FlightSpeedLabel"
  flightSpeedLabel.Size = UDim2.new(0,300,0,30)
  flightSpeedLabel.Position = UDim2.new(0,10,0,130)
  flightSpeedLabel.BackgroundTransparency = 1
  flightSpeedLabel.Text = "سرعة الطيران الحالية: " .. flightSpeed
  flightSpeedLabel.TextColor3 = Color3.new(1,1,1)
  flightSpeedLabel.Font = Enum.Font.SourceSansBold
  flightSpeedLabel.TextSize = 18
  
  local flightSpeedInput = Instance.new("TextBox", flightPanel)
  flightSpeedInput.Name = "FlightSpeedInput"
  flightSpeedInput.Size = UDim2.new(0,100,0,30)
  flightSpeedInput.Position = UDim2.new(0,10,0,165)
  flightSpeedInput.BackgroundColor3 = Color3.fromRGB(255,255,255)
  flightSpeedInput.Text = tostring(flightSpeed)
  flightSpeedInput.Font = Enum.Font.SourceSansBold
  flightSpeedInput.TextSize = 18
  flightSpeedInput.ClearTextOnFocus = false
  
  local flightSpeedSetButton = Instance.new("TextButton", flightPanel)
  flightSpeedSetButton.Name = "FlightSpeedSetButton"
  flightSpeedSetButton.Size = UDim2.new(0,150,0,30)
  flightSpeedSetButton.Position = UDim2.new(0,120,0,165)
  flightSpeedSetButton.BackgroundColor3 = Color3.fromRGB(70,130,180)
  flightSpeedSetButton.Text = "تحديث سرعة الطيران"
  flightSpeedSetButton.TextColor3 = Color3.new(1,1,1)
  flightSpeedSetButton.Font = Enum.Font.SourceSansBold
  flightSpeedSetButton.TextSize = 18
  
  local speedPanel = Instance.new("Frame", mainFrame)
  speedPanel.Name = "SpeedPanel"
  speedPanel.Size = UDim2.new(1,0,0,260)
  speedPanel.Position = UDim2.new(0,0,0,30)
  speedPanel.BackgroundTransparency = 1
  speedPanel.Visible = false
  
  local speedToggle = Instance.new("TextButton", speedPanel)
  speedToggle.Name = "SpeedToggle"
  speedToggle.Size = UDim2.new(0,300,0,40)
  speedToggle.Position = UDim2.new(0,10,0,10)
  speedToggle.BackgroundColor3 = Color3.fromRGB(70,130,180)
  speedToggle.Text = "تشغيل تعديل السرعة"
  speedToggle.TextColor3 = Color3.new(1,1,1)
  speedToggle.Font = Enum.Font.SourceSansBold
  speedToggle.TextSize = 20
  
  local speedIncrease = Instance.new("TextButton", speedPanel)
  speedIncrease.Name = "SpeedIncrease"
  speedIncrease.Size = UDim2.new(0,130,0,40)
  speedIncrease.Position = UDim2.new(0,10,0,70)
  speedIncrease.BackgroundColor3 = Color3.fromRGB(34,139,34)
  speedIncrease.Text = "زيادة السرعة"
  speedIncrease.TextColor3 = Color3.new(1,1,1)
  speedIncrease.Font = Enum.Font.SourceSansBold
  speedIncrease.TextSize = 20
  
  local speedDecrease = Instance.new("TextButton", speedPanel)
  speedDecrease.Name = "SpeedDecrease"
  speedDecrease.Size = UDim2.new(0,130,0,40)
  speedDecrease.Position = UDim2.new(0,160,0,70)
  speedDecrease.BackgroundColor3 = Color3.fromRGB(178,34,34)
  speedDecrease.Text = "تقليل السرعة"
  speedDecrease.TextColor3 = Color3.new(1,1,1)
  speedDecrease.Font = Enum.Font.SourceSansBold
  speedDecrease.TextSize = 20
  
  local speedLabel = Instance.new("TextLabel", speedPanel)
  speedLabel.Name = "SpeedLabel"
  speedLabel.Size = UDim2.new(0,300,0,30)
  speedLabel.Position = UDim2.new(0,10,0,170)
  speedLabel.BackgroundTransparency = 1
  speedLabel.Text = "السرعة الحالية: " .. boostedSpeed
  speedLabel.TextColor3 = Color3.new(1,1,1)
  speedLabel.Font = Enum.Font.SourceSansBold
  speedLabel.TextSize = 18
  
  local speedInput = Instance.new("TextBox", speedPanel)
  speedInput.Name = "SpeedInput"
  speedInput.Size = UDim2.new(0,100,0,30)
  speedInput.Position = UDim2.new(0,10,0,130)
  speedInput.BackgroundColor3 = Color3.fromRGB(255,255,255)
  speedInput.Text = tostring(boostedSpeed)
  speedInput.Font = Enum.Font.SourceSansBold
  speedInput.TextSize = 18
  speedInput.ClearTextOnFocus = false
  
  local speedSetButton = Instance.new("TextButton", speedPanel)
  speedSetButton.Name = "SpeedSetButton"
  speedSetButton.Size = UDim2.new(0,150,0,30)
  speedSetButton.Position = UDim2.new(0,120,0,130)
  speedSetButton.BackgroundColor3 = Color3.fromRGB(70,130,180)
  speedSetButton.Text = "تحديث السرعة"
  speedSetButton.TextColor3 = Color3.new(1,1,1)
  speedSetButton.Font = Enum.Font.SourceSansBold
  speedSetButton.TextSize = 18
  
  local playersPanel = Instance.new("Frame", mainFrame)
  playersPanel.Name = "PlayersPanel"
  playersPanel.Size = UDim2.new(1,0,0,260)
  playersPanel.Position = UDim2.new(0,0,0,30)
  playersPanel.BackgroundTransparency = 1
  playersPanel.Visible = false
  
  local playersToggle = Instance.new("TextButton", playersPanel)
  playersToggle.Name = "PlayersToggle"
  playersToggle.Size = UDim2.new(0,300,0,40)
  playersToggle.Position = UDim2.new(0,10,0,10)
  playersToggle.BackgroundColor3 = Color3.fromRGB(70,130,180)
  playersToggle.Text = "تفعيل الدوائر على اللاعبين"
  playersToggle.TextColor3 = Color3.new(1,1,1)
  playersToggle.Font = Enum.Font.SourceSansBold
  playersToggle.TextSize = 20
  
  local vanishToggle = Instance.new("TextButton", playersPanel)
  vanishToggle.Name = "VanishToggle"
  vanishToggle.Size = UDim2.new(0,300,0,40)
  vanishToggle.Position = UDim2.new(0,10,0,60)
  vanishToggle.BackgroundColor3 = Color3.fromRGB(100,149,237)
  vanishToggle.Text = "تفعيل الاختباء"
  vanishToggle.TextColor3 = Color3.new(1,1,1)
  vanishToggle.Font = Enum.Font.SourceSansBold
  vanishToggle.TextSize = 20
  
  playerListFrame = Instance.new("Frame", playersPanel)
  playerListFrame.Name = "PlayerListFrame"
  playerListFrame.Size = UDim2.new(0,300,0,100)
  playerListFrame.Position = UDim2.new(0,10,0,110)
  playerListFrame.BackgroundColor3 = Color3.fromRGB(50,50,50)
  playerListFrame.BorderSizePixel = 2
  playerListFrame.Draggable = true
  
  local framesLabel = Instance.new("TextLabel", playerListFrame)
  framesLabel.Name = "FramesLabel"
  framesLabel.Size = UDim2.new(1,0,0,20)
  framesLabel.BackgroundTransparency = 0.5
  framesLabel.Text = "الفريمات"
  framesLabel.TextColor3 = Color3.new(1,1,1)
  framesLabel.Font = Enum.Font.SourceSansBold
  framesLabel.TextSize = 16
  
  local listLayout = Instance.new("UIListLayout", playerListFrame)
  listLayout.FillDirection = Enum.FillDirection.Vertical
  listLayout.SortOrder = Enum.SortOrder.LayoutOrder
  listLayout.Padding = UDim.new(0,2)
  
  teleportSelectedButton = Instance.new("TextButton", playersPanel)
  teleportSelectedButton.Name = "TeleportSelectedButton"
  teleportSelectedButton.Size = UDim2.new(0,150,0,30)
  teleportSelectedButton.Position = UDim2.new(0,320,0,110)
  teleportSelectedButton.BackgroundColor3 = Color3.fromRGB(70,130,180)
  teleportSelectedButton.Text = "انتقال"
  teleportSelectedButton.TextColor3 = Color3.new(1,1,1)
  teleportSelectedButton.Font = Enum.Font.SourceSansBold
  teleportSelectedButton.TextSize = 18
  
  teleportSelectedButton.MouseButton1Click:Connect(function()
    if selectedPlayer and selectedPlayer.Character and selectedPlayer.Character:FindFirstChild("Head") then
      stickyTeleportActive = not stickyTeleportActive
      if stickyTeleportActive then
        teleportSelectedButton.Text = "إلغاء الانتقال"
      else
        teleportSelectedButton.Text = "انتقال"
      end
    end
  end)
  
  local pullButton = Instance.new("TextButton", playersPanel)
  pullButton.Name = "PullButton"
  pullButton.Size = UDim2.new(0,150,0,30)
  pullButton.Position = UDim2.new(0,320,0,150)
  pullButton.BackgroundColor3 = Color3.fromRGB(150,50,150)
  pullButton.Text = "سحب"
  pullButton.TextColor3 = Color3.new(1,1,1)
  pullButton.Font = Enum.Font.SourceSansBold
  pullButton.TextSize = 18
  pullButton.MouseButton1Click:Connect(function()
    if selectedPlayer and selectedPlayer.Character and selectedPlayer.Character:FindFirstChild("HumanoidRootPart") then
      pullActive = not pullActive
      if pullActive then
        pullButton.Text = "إلغاء السحب"
      else
        pullButton.Text = "سحب"
      end
    end
  end)
  
  local spectateButton = Instance.new("TextButton", playersPanel)
  spectateButton.Name = "SpectateButton"
  spectateButton.Size = UDim2.new(0,150,0,30)
  spectateButton.Position = UDim2.new(0,320,0,190)
  spectateButton.BackgroundColor3 = Color3.fromRGB(255,165,0)
  spectateButton.Text = "مراقبه"
  spectateButton.TextColor3 = Color3.new(1,1,1)
  spectateButton.Font = Enum.Font.SourceSansBold
  spectateButton.TextSize = 18
  
  spectateButton.MouseButton1Click:Connect(function()
    if selectedPlayer and selectedPlayer.Character and selectedPlayer.Character:FindFirstChild("Head") then
      if not spectateActive then
        Workspace.CurrentCamera.CameraSubject = selectedPlayer.Character.Head
        spectateActive = true
        spectateButton.Text = "إلغاء المراقبه"
      else
        local character = getCharacter()
        if character and character:FindFirstChild("Humanoid") then
          Workspace.CurrentCamera.CameraSubject = character.Humanoid
        end
        spectateActive = false
        spectateButton.Text = "مراقبه"
      end
    end
  end)
  
  local lightingPanel = Instance.new("Frame", mainFrame)
  lightingPanel.Name = "LightingPanel"
  lightingPanel.Size = UDim2.new(1,0,0,260)
  lightingPanel.Position = UDim2.new(0,0,0,30)
  lightingPanel.BackgroundTransparency = 1
  lightingPanel.Visible = false
  
  local lightLabel = Instance.new("TextLabel", lightingPanel)
  lightLabel.Name = "LightLabel"
  lightLabel.Size = UDim2.new(0,300,0,30)
  lightLabel.Position = UDim2.new(0,10,0,20)
  lightLabel.BackgroundTransparency = 1
  lightLabel.Text = "سطوع اللعبة الحالي: " .. Lighting.Brightness
  lightLabel.TextColor3 = Color3.new(1,1,1)
  lightLabel.Font = Enum.Font.SourceSansBold
  lightLabel.TextSize = 18
  
  local lightIncrease = Instance.new("TextButton", lightingPanel)
  lightIncrease.Name = "LightIncrease"
  lightIncrease.Size = UDim2.new(0,130,0,40)
  lightIncrease.Position = UDim2.new(0,10,0,70)
  lightIncrease.BackgroundColor3 = Color3.fromRGB(34,139,34)
  lightIncrease.Text = "زيادة الإضاءة"
  lightIncrease.TextColor3 = Color3.new(1,1,1)
  lightIncrease.Font = Enum.Font.SourceSansBold
  lightIncrease.TextSize = 20
  
  local lightDecrease = Instance.new("TextButton", lightingPanel)
  lightDecrease.Name = "LightDecrease"
  lightDecrease.Size = UDim2.new(0,130,0,40)
  lightDecrease.Position = UDim2.new(0,160,0,70)
  lightDecrease.BackgroundColor3 = Color3.fromRGB(178,34,34)
  lightDecrease.Text = "تقليل الإضاءة"
  lightDecrease.TextColor3 = Color3.new(1,1,1)
  lightDecrease.Font = Enum.Font.SourceSansBold
  lightDecrease.TextSize = 20
  
  local lightInput = Instance.new("TextBox", lightingPanel)
  lightInput.Name = "LightInput"
  lightInput.Size = UDim2.new(0,100,0,30)
  lightInput.Position = UDim2.new(0,10,0,130)
  lightInput.BackgroundColor3 = Color3.fromRGB(255,255,255)
  lightInput.Text = tostring(Lighting.Brightness)
  lightInput.Font = Enum.Font.SourceSansBold
  lightInput.TextSize = 18
  lightInput.ClearTextOnFocus = false
  
  local lightSetButton = Instance.new("TextButton", lightingPanel)
  lightSetButton.Name = "LightSetButton"
  lightSetButton.Size = UDim2.new(0,150,0,30)
  lightSetButton.Position = UDim2.new(0,120,0,130)
  lightSetButton.BackgroundColor3 = Color3.fromRGB(70,130,180)
  lightSetButton.Text = "تحديث الإضاءة"
  lightSetButton.TextColor3 = Color3.new(1,1,1)
  lightSetButton.Font = Enum.Font.SourceSansBold
  lightSetButton.TextSize = 18
  
  return {
    mainFrame = mainFrame,
    closeButton = closeButton,
    tabFlight = tabFlight,
    tabSpeed = tabSpeed,
    tabPlayers = tabPlayers,
    tabLighting = tabLighting,
    flightPanel = flightPanel,
    speedPanel = speedPanel,
    playersPanel = playersPanel,
    lightingPanel = lightingPanel,
    lightLabel = lightLabel,
    lightIncrease = lightIncrease,
    lightDecrease = lightDecrease,
    lightInput = lightInput,
    lightSetButton = lightSetButton,
    flightToggle = flightToggle,
    flightIncrease = flightIncrease,
    flightDecrease = flightDecrease,
    flightSpeedLabel = flightSpeedLabel,
    flightSpeedInput = flightSpeedInput,
    flightSpeedSetButton = flightSpeedSetButton,
    speedToggle = speedToggle,
    speedIncrease = speedIncrease,
    speedDecrease = speedDecrease,
    speedLabel = speedLabel,
    speedInput = speedInput,
    speedSetButton = speedSetButton,
    playersToggle = playersToggle,
    vanishToggle = vanishToggle,
    teleportSelectedButton = teleportSelectedButton,
    pullButton = pullButton
  }
end

local ui = createMainUI()

---------------------------------------------
-- Helper: Update Player List in the List Frame
---------------------------------------------
local function updatePlayerList()
  if not playerListFrame then return end
  for _, child in ipairs(playerListFrame:GetChildren()) do
    if child:IsA("TextButton") then
      child:Destroy()
    end
  end
  for _, p in ipairs(Players:GetPlayers()) do
    if p ~= player then
      local button = Instance.new("TextButton")
      button.Name = "PlayerButton_" .. p.Name
      button.Size = UDim2.new(1,0,0,25)
      button.BackgroundColor3 = Color3.fromRGB(100,100,100)
      if not p.Character or not p.Character:FindFirstChild("Head") then
        button.Text = p.Name .. " (لم تحمل)"
        p.CharacterAdded:Connect(function(character)
          wait(1)
          button.Text = p.Name
        end)
      else
        button.Text = p.Name
      end
      button.TextColor3 = Color3.new(1,1,1)
      button.Font = Enum.Font.SourceSansBold
      button.TextSize = 18
      button.Parent = playerListFrame
      
      button.MouseButton1Click:Connect(function()
        selectedPlayer = p
        for _, child in ipairs(playerListFrame:GetChildren()) do
          if child:IsA("TextButton") then
            child.BackgroundColor3 = Color3.fromRGB(100,100,100)
          end
        end
        button.BackgroundColor3 = Color3.fromRGB(0,200,0)
      end)
    end
  end
end

---------------------------------------------
-- Tab Switching Functions
---------------------------------------------
local function showFlightPanel()
  ui.flightPanel.Visible = true
  ui.speedPanel.Visible = false
  ui.playersPanel.Visible = false
  ui.lightingPanel.Visible = false
  ui.tabFlight.BackgroundColor3 = Color3.fromRGB(70,130,180)
  ui.tabSpeed.BackgroundColor3 = Color3.fromRGB(100,100,100)
  ui.tabPlayers.BackgroundColor3 = Color3.fromRGB(100,100,100)
  ui.tabLighting.BackgroundColor3 = Color3.fromRGB(100,100,100)
end

local function showSpeedPanel()
  ui.flightPanel.Visible = false
  ui.speedPanel.Visible = true
  ui.playersPanel.Visible = false
  ui.lightingPanel.Visible = false
  ui.tabFlight.BackgroundColor3 = Color3.fromRGB(100,100,100)
  ui.tabSpeed.BackgroundColor3 = Color3.fromRGB(70,130,180)
  ui.tabPlayers.BackgroundColor3 = Color3.fromRGB(100,100,100)
  ui.tabLighting.BackgroundColor3 = Color3.fromRGB(100,100,100)
end

local function showPlayersPanel()
  ui.flightPanel.Visible = false
  ui.speedPanel.Visible = false
  ui.playersPanel.Visible = true
  ui.lightingPanel.Visible = false
  ui.tabFlight.BackgroundColor3 = Color3.fromRGB(100,100,100)
  ui.tabSpeed.BackgroundColor3 = Color3.fromRGB(100,100,100)
  ui.tabPlayers.BackgroundColor3 = Color3.fromRGB(70,130,180)
  ui.tabLighting.BackgroundColor3 = Color3.fromRGB(100,100,100)
  updatePlayerList()
end

local function showLightingPanel()
  ui.flightPanel.Visible = false
  ui.speedPanel.Visible = false
  ui.playersPanel.Visible = false
  ui.lightingPanel.Visible = true
  ui.tabFlight.BackgroundColor3 = Color3.fromRGB(100,100,100)
  ui.tabSpeed.BackgroundColor3 = Color3.fromRGB(100,100,100)
  ui.tabPlayers.BackgroundColor3 = Color3.fromRGB(100,100,100)
  ui.tabLighting.BackgroundColor3 = Color3.fromRGB(70,130,180)
  ui.lightLabel.Text = "سطوع اللعبة الحالي: " .. Lighting.Brightness
  ui.lightInput.Text = tostring(Lighting.Brightness)
end

ui.tabFlight.MouseButton1Click:Connect(function() showFlightPanel() end)
ui.tabSpeed.MouseButton1Click:Connect(function() showSpeedPanel() end)
ui.tabPlayers.MouseButton1Click:Connect(function() showPlayersPanel() end)
ui.tabLighting.MouseButton1Click:Connect(function() showLightingPanel() end)

---------------------------------------------
-- Lighting Controls
---------------------------------------------
ui.lightIncrease.MouseButton1Click:Connect(function()
  increaseLighting()
  ui.lightLabel.Text = "سطوع اللعبة الحالي: " .. Lighting.Brightness
  ui.lightInput.Text = tostring(Lighting.Brightness)
end)

ui.lightDecrease.MouseButton1Click:Connect(function()
  decreaseLighting()
  ui.lightLabel.Text = "سطوع اللعبة الحالي: " .. Lighting.Brightness
  ui.lightInput.Text = tostring(Lighting.Brightness)
end)

ui.lightSetButton.MouseButton1Click:Connect(function()
  setLighting(ui.lightInput.Text)
  ui.lightLabel.Text = "سطوع اللعبة الحالي: " .. Lighting.Brightness
  ui.lightInput.Text = tostring(Lighting.Brightness)
end)

---------------------------------------------
-- Close UI Function
---------------------------------------------
local function closeUI()
  if flying then
    disableFlight(getCharacter(), bodyGyro, bodyVelocity)
    flying = false
  end
  if speedBoostActive then
    disableSpeedBoost()
    speedBoostActive = false
  end
  ui.mainFrame:Destroy()
end

ui.closeButton.MouseButton1Click:Connect(function() closeUI() end)

---------------------------------------------
-- Flight Functions
---------------------------------------------
local function toggleFlight()
  flying = not flying
  local character = getCharacter()
  if flying then
    bodyGyro, bodyVelocity = enableFlight(character)
  else
    disableFlight(character, bodyGyro, bodyVelocity)
  end
  ui.flightToggle.Text = flying and "إيقاف الطيران" or "تشغيل الطيران"
end

local function increaseFlightSpeed()
  flightSpeed = flightSpeed + flightSpeedIncrement
  ui.flightSpeedLabel.Text = "سرعة الطيران الحالية: " .. flightSpeed
  ui.flightSpeedInput.Text = tostring(flightSpeed)
end

local function decreaseFlightSpeed()
  if flightSpeed - flightSpeedIncrement >= 10 then
    flightSpeed = flightSpeed - flightSpeedIncrement
  end
  ui.flightSpeedLabel.Text = "سرعة الطيران الحالية: " .. flightSpeed
  ui.flightSpeedInput.Text = tostring(flightSpeed)
end

ui.flightToggle.MouseButton1Click:Connect(function() toggleFlight() end)
ui.flightIncrease.MouseButton1Down:Connect(function() autoIncreasingFlight = true end)
ui.flightIncrease.MouseButton1Up:Connect(function() autoIncreasingFlight = false; autoIncreaseAccumulatorFlight = 0 end)
ui.flightDecrease.MouseButton1Click:Connect(function() decreaseFlightSpeed() end)
ui.flightSpeedSetButton.MouseButton1Click:Connect(function()
  local inputVal = ui.flightSpeedInput.Text
  if inputVal:lower() == "inf" then
    flightSpeed = 1e9
    ui.flightSpeedLabel.Text = "سرعة الطيران الحالية: " .. flightSpeed
    ui.flightSpeedInput.Text = tostring(flightSpeed)
  else
    local inputSpeed = tonumber(inputVal)
    if inputSpeed and inputSpeed >= 10 then
      flightSpeed = inputSpeed
      ui.flightSpeedLabel.Text = "سرعة الطيران الحالية: " .. flightSpeed
    else
      ui.flightSpeedInput.Text = tostring(flightSpeed)
    end
  end
end)

---------------------------------------------
-- Speed Functions (WalkSpeed)
---------------------------------------------
local function toggleSpeedBoost()
  speedBoostActive = not speedBoostActive
  if speedBoostActive then
    enableSpeedBoost()
    ui.speedToggle.Text = "إيقاف تعديل السرعة"
  else
    disableSpeedBoost()
    ui.speedToggle.Text = "تشغيل تعديل السرعة"
  end
end

local function increasePlayerSpeed()
  boostedSpeed = boostedSpeed + speedIncrement
  if speedBoostActive then enableSpeedBoost() end
  ui.speedLabel.Text = "السرعة الحالية: " .. boostedSpeed
  ui.speedInput.Text = tostring(boostedSpeed)
end

local function decreasePlayerSpeed()
  if boostedSpeed - speedIncrement >= 10 then
    boostedSpeed = boostedSpeed - speedIncrement
  end
  if speedBoostActive then enableSpeedBoost() end
  ui.speedLabel.Text = "السرعة الحالية: " .. boostedSpeed
  ui.speedInput.Text = tostring(boostedSpeed)
end

ui.speedToggle.MouseButton1Click:Connect(function() toggleSpeedBoost() end)
ui.speedIncrease.MouseButton1Down:Connect(function() autoIncreasingSpeed = true end)
ui.speedIncrease.MouseButton1Up:Connect(function() autoIncreasingSpeed = false; autoIncreaseAccumulatorSpeed = 0 end)
ui.speedDecrease.MouseButton1Click:Connect(function() decreasePlayerSpeed() end)
ui.speedSetButton.MouseButton1Click:Connect(function()
  local inputSpeed = tonumber(ui.speedInput.Text)
  if inputSpeed and inputSpeed >= 10 then
    boostedSpeed = inputSpeed
    flightSpeed = inputSpeed
    if speedBoostActive then enableSpeedBoost() end
    ui.speedLabel.Text = "السرعة الحالية: " .. boostedSpeed
    ui.flightSpeedLabel.Text = "سرعة الطيران الحالية: " .. flightSpeed
    ui.flightSpeedInput.Text = tostring(flightSpeed)
  else
    ui.speedInput.Text = tostring(boostedSpeed)
  end
end)

---------------------------------------------
-- Players Tab Functions (Circles, Vanish, Teleport, etc.)
---------------------------------------------
local function updatePlayerCircles()
  local cam = Workspace.CurrentCamera
  local threshold = 150
  for _, currentPlayer in ipairs(Players:GetPlayers()) do
    if currentPlayer ~= player and currentPlayer.Character and currentPlayer.Character:FindFirstChild("Head") then
      local head = currentPlayer.Character.Head
      local pos, onScreen = cam:WorldToViewportPoint(head.Position)
      local distance = (cam.CFrame.Position - head.Position).Magnitude
      local circle = playerCircles[currentPlayer]
      if onScreen and distance <= threshold then
        if circle then
          circle.Visible = true
          circle.Position = Vector2.new(pos.X, pos.Y)
          circle.Radius = 50 / (cam.FieldOfView / 70)
        end
      else
        if circle then
          circle.Visible = false
        end
      end
    end
  end
end

local function updateNameLabels()
  for _, currentPlayer in ipairs(Players:GetPlayers()) do
    if currentPlayer ~= player and currentPlayer.Character and currentPlayer.Character:FindFirstChild("Head") then
      if not nameLabels[currentPlayer] then
        local billboard = createNameLabel(currentPlayer)
        billboard.Parent = currentPlayer.Character.Head
        nameLabels[currentPlayer] = billboard
      else
        nameLabels[currentPlayer].Adornee = currentPlayer.Character and currentPlayer.Character:FindFirstChild("Head")
      end
    end
  end
end

local function enablePlayerCircles()
  playersCirclesEnabled = true
  for _, currentPlayer in ipairs(Players:GetPlayers()) do
    if currentPlayer ~= player then
      if currentPlayer.Character and currentPlayer.Character:FindFirstChild("Head") then
        if not playerCircles[currentPlayer] then
          playerCircles[currentPlayer] = createCircle()
        end
      else
        currentPlayer.CharacterAdded:Connect(function(character)
          wait(1)
          if character:FindFirstChild("Head") and not playerCircles[currentPlayer] then
            playerCircles[currentPlayer] = createCircle()
          end
        end)
      end
    end
  end
  updateNameLabels()
end

local function disablePlayerCircles()
  playersCirclesEnabled = false
  for currentPlayer, circle in pairs(playerCircles) do
    if circle then
      circle.Visible = false
      circle:Remove()
    end
  end
  playerCircles = {}
  for currentPlayer, billboard in pairs(nameLabels) do
    if billboard and billboard.Parent then
      billboard:Destroy()
    end
  end
  nameLabels = {}
end

ui.playersToggle.MouseButton1Click:Connect(function()
  if playersCirclesEnabled then
    disablePlayerCircles()
    ui.playersToggle.Text = "تفعيل الدوائر على اللاعبين"
  else
    enablePlayerCircles()
    ui.playersToggle.Text = "إيقاف الدوائر على اللاعبين"
  end
end)

Players.PlayerAdded:Connect(function(newPlayer)
  newPlayer.CharacterAdded:Connect(function(character)
    if playersCirclesEnabled and newPlayer ~= player then
      wait(1)
      if not playerCircles[newPlayer] then
        playerCircles[newPlayer] = createCircle()
      end
      if not nameLabels[newPlayer] then
        local billboard = createNameLabel(newPlayer)
        billboard.Parent = character:WaitForChild("Head")
        nameLabels[newPlayer] = billboard
      end
      updatePlayerList()
    end
  end)
end)

Players.PlayerRemoving:Connect(function(leavingPlayer)
  if playerCircles[leavingPlayer] then
    playerCircles[leavingPlayer]:Remove()
    playerCircles[leavingPlayer] = nil
  end
  if nameLabels[leavingPlayer] then
    nameLabels[leavingPlayer]:Destroy()
    nameLabels[leavingPlayer] = nil
  end
  if selectedPlayer == leavingPlayer then
    selectedPlayer = nil
  end
  updatePlayerList()
end)

ui.playersPanel.VanishToggle.MouseButton1Click:Connect(function()
  vanishActive = not vanishActive
  if vanishActive then
    enableVanish()
    ui.playersPanel.VanishToggle.Text = "إيقاف الاختباء"
  else
    disableVanish()
    ui.playersPanel.VanishToggle.Text = "تفعيل الاختباء"
  end
end)

-- Teleport on Circle Click
UserInputService.InputBegan:Connect(function(input, gameProcessed)
  if input.UserInputType == Enum.UserInputType.MouseButton1 and not gameProcessed then
    local mousePos = UserInputService:GetMouseLocation()
    for p, circle in pairs(playerCircles) do
      if circle.Visible then
        if (Vector2.new(mousePos.X, mousePos.Y) - circle.Position).Magnitude <= circle.Radius then
          if p.Character and p.Character:FindFirstChild("Head") then
            local targetPos = p.Character.Head.Position + Vector3.new(0,5,0)
            local myCharacter = getCharacter()
            if myCharacter then
              myCharacter:MoveTo(targetPos)
            end
          end
          break
        end
      end
    end
  end
end)

-- UI Toggle using CTRL Key
UserInputService.InputBegan:Connect(function(input, gameProcessed)
  if gameProcessed then return end
  if input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.RightControl then
    ui.mainFrame.Visible = not ui.mainFrame.Visible
  end
end)

-- Support Key F to Toggle Flight
player:GetMouse().KeyDown:Connect(function(key)
  if key:lower() == "f" then
    toggleFlight()
  end
end)

-- Flight Movement Input Handling
UserInputService.InputBegan:Connect(function(input, gameProcessed)
  if gameProcessed then return end
  if input.KeyCode == Enum.KeyCode.W then
    flightControl.N = true
  elseif input.KeyCode == Enum.KeyCode.S then
    flightControl.S = true
  elseif input.KeyCode == Enum.KeyCode.A then
    flightControl.W = true
  elseif input.KeyCode == Enum.KeyCode.D then
    flightControl.E = true
  elseif input.KeyCode == Enum.KeyCode.Space then
    flightControl.Up = true
  elseif input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.C then
    flightControl.Down = true
  end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
  if gameProcessed then return end
  if input.KeyCode == Enum.KeyCode.W then
    flightControl.N = false
  elseif input.KeyCode == Enum.KeyCode.S then
    flightControl.S = false
  elseif input.KeyCode == Enum.KeyCode.A then
    flightControl.W = false
  elseif input.KeyCode == Enum.KeyCode.D then
    flightControl.E = false
  elseif input.KeyCode == Enum.KeyCode.Space then
    flightControl.Up = false
  elseif input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.C then
    flightControl.Down = false
  end
end)

---------------------------------------------
-- Main RenderStepped Loop
---------------------------------------------
RunService.RenderStepped:Connect(function(deltaTime)
  if flying then
    local character = getCharacter()
    if character and character:FindFirstChild("HumanoidRootPart") then
      local root = character.HumanoidRootPart
      local cam = Workspace.CurrentCamera
      local moveDirection = Vector3.new()
      if flightControl.N then moveDirection = moveDirection + cam.CFrame.LookVector end
      if flightControl.S then moveDirection = moveDirection - cam.CFrame.LookVector end
      if flightControl.E then moveDirection = moveDirection + cam.CFrame.RightVector end
      if flightControl.W then moveDirection = moveDirection - cam.CFrame.RightVector end
      if flightControl.Up then moveDirection = moveDirection + Vector3.new(0,1,0) end
      if flightControl.Down then moveDirection = moveDirection - Vector3.new(0,1,0) end
      if moveDirection.Magnitude > 0 then moveDirection = moveDirection.Unit end
      bodyVelocity.Velocity = moveDirection * flightSpeed
      bodyGyro.CFrame = cam.CFrame
    end
  end
  
  if autoIncreasingFlight then
    autoIncreaseAccumulatorFlight = autoIncreaseAccumulatorFlight + deltaTime
    while autoIncreaseAccumulatorFlight >= autoIncreaseInterval do
      increaseFlightSpeed()
      autoIncreaseAccumulatorFlight = autoIncreaseAccumulatorFlight - autoIncreaseInterval
    end
  end
  
  if autoIncreasingSpeed then
    autoIncreaseAccumulatorSpeed = autoIncreaseAccumulatorSpeed + deltaTime
    while autoIncreaseAccumulatorSpeed >= autoIncreaseInterval do
      increasePlayerSpeed()
      autoIncreaseAccumulatorSpeed = autoIncreaseAccumulatorSpeed - autoIncreaseInterval
    end
  end
  
  if playersCirclesEnabled then
    updatePlayerCircles()
  end
  
  -- Improved Sticky Teleport:
  if stickyTeleportActive then
    if selectedPlayer and selectedPlayer.Character and selectedPlayer.Character:FindFirstChild("Head") then
      local targetPos = selectedPlayer.Character.Head.Position + Vector3.new(0,5,0)
      local myCharacter = getCharacter()
      if myCharacter and myCharacter:FindFirstChild("HumanoidRootPart") then
        local currentPos = myCharacter.HumanoidRootPart.Position
        if (currentPos - targetPos).Magnitude > 5 then
          pcall(function()
            myCharacter:MoveTo(targetPos)
          end)
        end
      end
    end
  end
  
  -- Continuous Pull Functionality:
  if pullActive then
    if selectedPlayer and selectedPlayer.Character and selectedPlayer.Character:FindFirstChild("HumanoidRootPart") then
      local myCharacter = getCharacter()
      if myCharacter and myCharacter:FindFirstChild("HumanoidRootPart") then
        local pullPos = myCharacter.HumanoidRootPart.Position + Vector3.new(0,5,0)
        pcall(function()
          selectedPlayer.Character:MoveTo(pullPos)
        end)
      end
    end
  end
end)