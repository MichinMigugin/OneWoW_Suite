local _, ns = ...

-- ============================================================================
-- ChunkedJob
-- ============================================================================
-- Time-budgeted cooperative work for large enumerations (catalog walks,
-- DevTool all-catalog filters, etc.). Keeps the main thread responsive by
-- running consumer work inside a coroutine and yielding when a per-slice
-- deadline (debugprofilestop) is reached, then resuming on the next frame.
--
-- Display virtualization (OneWoW_GUI:CreateVirtualizer) is a separate concern:
-- this service produces or filters data; the virtualizer paints the visible
-- window of whatever has arrived so far.
--
-- Usage:
--   local job = OneWoW.ChunkedJob.Start({
--       budgetMs = 8,  -- soft target ms per slice (default 8)
--       run = function(shouldYield)
--           for i = 1, n do
--               doWork(i)
--               OneWoW.ChunkedJob.YieldIfNeeded(shouldYield)
--           end
--       end,
--       onProgress = function() ... end,  -- after each yielded slice
--       onComplete = function() ... end,
--       onCancel = function() ... end,
--   })
--   job:Cancel()
--
-- shouldYield() is true when the current slice's time budget is exhausted.
-- Always call YieldIfNeeded (or coroutine.yield when shouldYield()) from
-- inside options.run — never from outside the job's coroutine.
-- ============================================================================

local ChunkedJob = {}
ns.ChunkedJob = ChunkedJob

local C_Timer = C_Timer
local coroutine_create = coroutine.create
local coroutine_resume = coroutine.resume
local coroutine_yield = coroutine.yield
local coroutine_status = coroutine.status
local debugprofilestop = debugprofilestop
local type = type
local error = error
local CallErrorHandler = CallErrorHandler
local xpcall = xpcall
local sort = sort
local min = math.min

local DEFAULT_BUDGET_MS = 8

--- Yield from inside options.run when the current slice is out of budget.
---@param shouldYield fun(): boolean
function ChunkedJob.YieldIfNeeded(shouldYield)
    if shouldYield and shouldYield() then
        coroutine_yield()
    end
end

--- Sort `array` in place. When `shouldYield` is set (inside a job), uses a
--- bottom-up merge sort that yields under budget so large n stays responsive.
--- When omitted, delegates to the fast global `sort`.
---@param array table
---@param comparator fun(a: any, b: any): boolean
---@param shouldYield fun(): boolean|nil
function ChunkedJob.Sort(array, comparator, shouldYield)
    if type(array) ~= "table" then
        error("ChunkedJob.Sort requires an array", 2)
    end
    if not shouldYield then
        sort(array, comparator)
        return
    end

    local n = #array
    if n < 2 then
        return
    end

    local YieldIfNeeded = ChunkedJob.YieldIfNeeded
    local tmp = {}
    local width = 1
    while width < n do
        local i = 1
        while i <= n do
            local left = i
            local mid = min(i + width - 1, n)
            local right = min(i + 2 * width - 1, n)

            local a, b, t = left, mid + 1, left
            while a <= mid and b <= right do
                if comparator(array[a], array[b]) then
                    tmp[t] = array[a]
                    a = a + 1
                else
                    tmp[t] = array[b]
                    b = b + 1
                end
                t = t + 1
                YieldIfNeeded(shouldYield)
            end
            while a <= mid do
                tmp[t] = array[a]
                a = a + 1
                t = t + 1
                YieldIfNeeded(shouldYield)
            end
            while b <= right do
                tmp[t] = array[b]
                b = b + 1
                t = t + 1
                YieldIfNeeded(shouldYield)
            end
            for k = left, right do
                array[k] = tmp[k]
            end
            YieldIfNeeded(shouldYield)

            i = i + 2 * width
        end
        width = width * 2
    end
end

--- Start a time-sliced job. Returns a handle with Cancel / IsActive.
---@param options table
---@return table handle
function ChunkedJob.Start(options)
    options = options or {}
    local run = options.run
    if type(run) ~= "function" then
        error("ChunkedJob.Start requires options.run(shouldYield)", 2)
    end

    local budgetMs = options.budgetMs or DEFAULT_BUDGET_MS
    if budgetMs < 1 then
        budgetMs = 1
    end

    local onProgress = options.onProgress
    local onComplete = options.onComplete
    local onCancel = options.onCancel

    local cancelled = false
    local active = true
    local deadline = 0

    local function shouldYield()
        return debugprofilestop() >= deadline
    end

    local co = coroutine_create(function()
        run(shouldYield)
    end)

    local handle = {}

    function handle:Cancel()
        if not active then
            return
        end
        cancelled = true
        active = false
        if onCancel then
            xpcall(onCancel, CallErrorHandler)
        end
    end

    function handle:IsActive()
        return active
    end

    local function slice()
        if cancelled then
            return
        end

        deadline = debugprofilestop() + budgetMs
        local ok, err = coroutine_resume(co)
        if cancelled then
            return
        end

        if not ok then
            active = false
            -- Surface into the global error handler without aborting the client.
            CallErrorHandler(err)
            return
        end

        if coroutine_status(co) == "dead" then
            active = false
            if onComplete then
                xpcall(onComplete, CallErrorHandler)
            end
            return
        end

        if onProgress then
            xpcall(onProgress, CallErrorHandler)
        end
        C_Timer.After(0, slice)
    end

    -- Defer the first slice so the caller can finish wiring before work starts.
    C_Timer.After(0, slice)

    return handle
end
