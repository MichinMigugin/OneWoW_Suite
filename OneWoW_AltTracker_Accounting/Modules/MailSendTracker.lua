local addonName, ns = ...

ns.MailSendTracker = {}
local MailSendTracker = ns.MailSendTracker

function MailSendTracker:Initialize()
    self:HookMailSend()
end

function MailSendTracker:HookMailSend()
    hooksecurefunc("SendMail", function(recipient, subject, body)
        local money = GetSendMailMoney() or 0
        local cod = GetSendMailCOD() or 0
        local totalCost = GetSendMailPrice() or 0
        local postageCost = math.max(0, totalCost - money)

        local codItemName, codItemCount
        if cod > 0 then
            for i = 1, ATTACHMENTS_MAX_SEND do
                local name, texture, count, quality = GetSendMailItem(i)
                if name then
                    codItemName = name
                    codItemCount = count
                    break
                end
            end
        end

        C_Timer.After(0.1, function()
            self:RecordMailSend(recipient, money, postageCost, cod, codItemName, codItemCount)
        end)
    end)
end

function MailSendTracker:RecordMailSend(recipient, money, postageCost, cod, codItemName, codItemCount)
    if money and money > 0 then
        ns.Transactions:RecordExpense("mail_send", money, recipient, nil, "Gold via Mail", nil, "Sent to " .. recipient)
    end

    if cod and cod > 0 and codItemName then
        ns.Transactions:RecordIncome("mail_cod_send", cod, recipient, nil, codItemName, codItemCount, "COD to " .. recipient)
    end

    if postageCost and postageCost > 0 then
        ns.Transactions:RecordExpense("mail_postage", postageCost, "Postmaster", nil, "Postage Fee", nil, "Mail to " .. recipient)
    end
end
