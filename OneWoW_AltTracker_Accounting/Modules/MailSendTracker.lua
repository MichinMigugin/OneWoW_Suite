local addonName, ns = ...

ns.MailSendTracker = {}
local MailSendTracker = ns.MailSendTracker

function MailSendTracker:Initialize()
    self:HookMailSend()
end

function MailSendTracker:HookMailSend()
    hooksecurefunc("SendMail", function(recipient, subject, body)
        C_Timer.After(0.1, function()
            self:RecordMailSend(recipient)
        end)
    end)
end

function MailSendTracker:RecordMailSend(recipient)
    local money = GetSendMailMoney()
    local cod = GetSendMailCOD()

    if money and money > 0 then
        ns.Transactions:RecordExpense("mail_send", money, recipient, nil, "Gold via Mail", nil, "Sent to " .. recipient)
    end

    if cod and cod > 0 then
        for i = 1, ATTACHMENTS_MAX_SEND do
            local name, texture, count, quality = GetSendMailItem(i)
            if name then
                ns.Transactions:RecordIncome("mail_cod_send", cod, recipient, nil, name, count, "COD to " .. recipient)
                break
            end
        end
    end

    local postageCost = GetSendMailPrice()
    if postageCost and postageCost > 0 then
        ns.Transactions:RecordExpense("mail_postage", postageCost, "Postmaster", nil, "Postage Fee", nil, "Mail to " .. recipient)
    end
end
