local _, ns = ...
local FastForwardModule = ns.ModuleRegistry:Current()
if not FastForwardModule then return end

local function ShouldSkip()
    if IsModifierKeyDown() then return false end
    if ns.ModuleRegistry:GetToggleValue("fastforward", "instance_only") then
        if not IsInInstance() then return false end
    end
    return true
end

local function StopGameMovieSafe()
    local mf = MovieFrame
    if not mf then return end
    if type(mf.StopMovie) == "function" then
        pcall(mf.StopMovie, mf)
    end
    if mf:IsShown() then
        pcall(mf.Hide, mf)
    end
    if type(CinematicFinished) == "function" then
        pcall(CinematicFinished, Enum.CinematicType.GameMovie)
    end

    pcall(EventRegistry.TriggerEvent, EventRegistry, "Subtitles.OnMovieCinematicStop")
end

local function CancelCinematicSafe()
    if type(CinematicFrame_CancelCinematic) == "function" then
        pcall(CinematicFrame_CancelCinematic)
        return
    end
    local used = false
    if type(StopCinematic) == "function" then
        used = pcall(StopCinematic)
    end
    if not used and type(CanCancelScene) == "function" and CanCancelScene() and type(CancelScene) == "function" then
        used = pcall(CancelScene)
    end
    if not used and type(CanExitVehicle) == "function" and CanExitVehicle() and type(VehicleExit) == "function" then
        used = pcall(VehicleExit)
    end
end

function FastForwardModule:OnEnable()
    if not self._frame then
        self._frame = CreateFrame("Frame", "OneWoW_QoL_FastForward")
        self._frame:SetScript("OnEvent", function(_, event, ...)
            if event == "PLAY_MOVIE" then
                self:PLAY_MOVIE(...)
            elseif event == "CINEMATIC_START" then
                self:CINEMATIC_START(...)
            end
        end)
    end
    self._frame:RegisterEvent("PLAY_MOVIE")
    self._frame:RegisterEvent("CINEMATIC_START")
end

function FastForwardModule:OnDisable()
    if self._frame then
        self._frame:UnregisterAllEvents()
    end
end

function FastForwardModule:PLAY_MOVIE(movieID)
    if not movieID then return end
    if not ns.ModuleRegistry:GetToggleValue("fastforward", "skip_movies") then return end
    if not ShouldSkip() then return end
    StopGameMovieSafe()
end

function FastForwardModule:CINEMATIC_START(canBeCancelled)
    if not ns.ModuleRegistry:GetToggleValue("fastforward", "skip_cinematics") then return end
    if not ShouldSkip() then return end
    if ns.ModuleRegistry:GetToggleValue("fastforward", "respect_uncancellable") and canBeCancelled == false then
        return
    end
    C_Timer.After(0.01, CancelCinematicSafe)
end
