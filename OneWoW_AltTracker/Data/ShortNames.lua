local addonName, ns = ...

ns.ShortNames = {}

function ns.ShortNames:GetShortName(fullName, maxLength)
    maxLength = maxLength or 12

    if not fullName or fullName == "" then
        return ""
    end

    if string.len(fullName) <= maxLength then
        return fullName
    end

    return string.sub(fullName, 1, maxLength - 3) .. "..."
end
