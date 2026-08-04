local _, ns = ...

-- Mis-tagged items: Blizzard classID/subClassID wrong; PE reclassifies for
-- #recipe / BuildProps (and IdentityIsRecipeItem).
ns.ItemIDOverrides = {
    -- RECIPE: BLACKSMITHING
    [265530] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Blacksmithing },
    [259319] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Blacksmithing },
    [259317] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Blacksmithing },
    [259237] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Blacksmithing },
    [265536] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Blacksmithing },
    [259322] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Blacksmithing },
    [259318] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Blacksmithing },
    [265528] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Blacksmithing },
    [265534] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Blacksmithing },
    [259235] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Blacksmithing },
    [259233] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Blacksmithing },
    [265532] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Blacksmithing },
    [259231] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Blacksmithing },
    -- RECIPE: ENGINEERING
    [259180] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Engineering },
    [259174] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Engineering },
    [259178] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Engineering },
    [259184] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Engineering },
    [268480] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Engineering },
    [259176] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Engineering },
    [259172] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Engineering },
    [259182] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Engineering },
    -- RECIPE: INSCRIPTION
    [259206] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Inscription },
    [259210] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Inscription },
    [259208] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Inscription },
    [257028] = { classID = Enum.ItemClass.Recipe, subClassID = Enum.ItemRecipeSubclass.Inscription },
}
