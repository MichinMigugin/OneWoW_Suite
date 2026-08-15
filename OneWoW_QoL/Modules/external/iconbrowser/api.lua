local _, ns = ...
local M = ns.ModuleRegistry:Current()
if not M then return end

--- Create a standalone icon browser (hidden until :Show).
---@param parent Frame
---@param opts { onSelect: fun(fileID: number, info: table), width?: number, height?: number, stride?: number, selectedFile?: number }|nil
---@return Frame browser
function OneWoW_QoL_API.CreateIconBrowser(parent, opts)
    opts = opts or {}
    return M.Browser.Create(parent, {
        onSelect = opts.onSelect,
        width = opts.width,
        height = opts.height,
        stride = opts.stride,
        selectedFile = opts.selectedFile,
    })
end
