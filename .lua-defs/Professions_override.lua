---@meta _

---@class TradeSkillRecipeInfo
---@field recipeID number
---@field name string?
---@field learned boolean?
---@field categoryID number?
---@field isRecraft boolean?

---@class ProfessionsRecipeTransaction
local ProfessionsRecipeTransaction = {}
---@return number recipeID
function ProfessionsRecipeTransaction:GetRecipeID() end
---@return string? itemGUID
function ProfessionsRecipeTransaction:GetAllocationItemGUID() end
function ProfessionsRecipeTransaction:CreateCraftingReagentInfoTbl() end
---@return boolean
function ProfessionsRecipeTransaction:IsRecraft() end

---@class ProfessionsRecipeSchematicForm : Frame
---@field transaction ProfessionsRecipeTransaction?
---@field currentRecipeInfo TradeSkillRecipeInfo?
local ProfessionsRecipeSchematicForm = {}
---@param recipeInfo TradeSkillRecipeInfo?
---@param isRecraftOverride boolean?
function ProfessionsRecipeSchematicForm:Init(recipeInfo, isRecraftOverride) end
function ProfessionsRecipeSchematicForm:Refresh() end
---@return TradeSkillRecipeInfo?
function ProfessionsRecipeSchematicForm:GetRecipeInfo() end
---@return ProfessionsRecipeTransaction?
function ProfessionsRecipeSchematicForm:GetTransaction() end
---@param recipeID number
---@return boolean
function ProfessionsRecipeSchematicForm:IsCurrentRecipe(recipeID) end

---@class ProfessionsCraftingPage : Frame
---@field SchematicForm ProfessionsRecipeSchematicForm

---@class ProfessionsOrderDetails : Frame
---@field SchematicForm ProfessionsRecipeSchematicForm
---@field orderID number?

---@class ProfessionsOrderView : Frame
---@field OrderDetails ProfessionsOrderDetails

---@class ProfessionsOrdersPage : Frame
---@field OrderView ProfessionsOrderView

---@class ProfessionsFrame : Frame
---@field CraftingPage ProfessionsCraftingPage
---@field OrdersPage ProfessionsOrdersPage

---@type ProfessionsFrame
ProfessionsFrame = {}
