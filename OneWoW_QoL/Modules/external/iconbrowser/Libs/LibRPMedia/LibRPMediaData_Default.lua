local LRPM12 = LibStub and LibStub:GetLibrary("LibRPMedia-1.2", true);

if not LRPM12 or LRPM12.db ~= nil then
    return;
end

LRPM12.db = {
    icons = {
        size = 0,
        id   = {},
        name = {},
        tags = {},
        categories = {WeaponTypeMace=26,Haranir=101,WeaponTypeWarglaive=31,Mount=6,VoidMagic=67,InventorySlotShirt=50,Troll=96,InventorySlotRing=58,ShadowMagic=66,Housing=2,OtherFactions=70,Shaman=16,Food=5,WeaponTypeBow=33,Mage=17,Achievement=0,Warlock=18,Potion=8,Engineering=77,Human=87,Orcish=93,WeaponTypeFists=30,InventorySlotWaist=53,InventorySlotNeck=57,Jewelcrafting=81,InventorySlotFeet=47,MailArmor=42,WeaponTypeCrossbow=34,Hunter=12,Pandaren=99,Blacksmithing=74,WeaponTypeAmmo=32,WeaponTypeSword=29,Evoker=22,TradeGoods=9,Tauren=95,Vulpera=98,Goblin=97,DeathKnight=15,Dracthyr=100,Undead=94,Worgen=92,Rogue=13,ArcaneMagic=60,InventorySlotBack=45,ClothArmor=40,Draenei=91,Elven=89,Item=3,Gnomish=90,Dwarven=88,InventorySlotTrinket=59,Fishing=86,WeaponTypeAxe=24,FrostMagic=63,Tailoring=85,Drink=4,Skinning=84,InventorySlotHands=48,PlateArmor=43,FelMagic=61,LeatherArmor=41,Leatherworking=82,Inscription=80,Archaeology=73,Professions=71,WeaponTypeWand=37,InventorySlotTabard=52,Enchanting=76,Weapon=23,WeaponTypeStaff=28,NatureMagic=65,HolyMagic=64,Alchemy=72,Herbalism=79,Horde=69,WeaponTypeGun=35,Alliance=68,Cooking=75,FireMagic=62,InventorySlotShield=56,InventorySlotOffHand=55,Armor=38,WeaponTypeDagger=25,Jewelry=39,InventorySlotWrists=54,Warrior=10,Paladin=11,FirstAid=78,InventorySlotHead=44,Ability=1,Mining=83,Pet=7,DemonHunter=21,InventorySlotChest=46,Druid=20,WeaponTypeThrown=36,InventorySlotShoulders=51,InventorySlotLegs=49,WeaponTypePolearm=27,Monk=19,Priest=14},
    },
    music = {
        size = 0,
        file = {},
        name = {},
        nkey = {},
        time = {},
    },
};
