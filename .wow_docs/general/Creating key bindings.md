# Creating key bindings

Key bindings allow addons to perform actions when a user presses a specific combination of modifier keys and keyboard or mouse buttons. If the addon always offers the same set of bindings, the `Bindings.xml` file can be used to declare these in advance, and FrameXML will include these in the built-in Key Bindings UI. Alternatively, addons may create bindings manually using the [SetBinding](https://warcraft.wiki.gg/wiki/API_SetBinding "API SetBinding") and [SetOverrideBinding](https://warcraft.wiki.gg/wiki/API_SetOverrideBinding "API SetOverrideBinding") families of API functions.

Addons can only change bindings in combat by using binding-related functions present on frame handles in a [restricted environment](https://warcraft.wiki.gg/wiki/RestrictedEnvironment#Frame_handle_methods "RestrictedEnvironment").

## Using Bindings.xml to create static bindings

If you know the exact list of actions you want to let users configure keybindings for, you can use the `Bindings.xml` file to specify static bindings. This method of creating bindings also allows you to rely on Blizzard's Key Bindings UI to allow users to customize your bindings, vastly reducing the amount of binding-handling code you'll need to write. Bindings.xml allows you to create bindings that perform one of these actions:

- Run any Lua code you specify, insecurely.
- Cast a spell
- Use an item
- Run a /macro-created macro
- Perform a :Click() on an existing Button widget, securely.

Note that you may not combine these actions in a single binding -- so only the macro or click options will let you both use an item and cast a spell using one button press.

To use `Bindings.xml` in your addon, you should create a `Bindings.xml` file in your addon directory (relative to the World of Warcraft directory: `Interface\AddOns\MyAddOn\Bindings.xml`). The WoW client will automatically load this file, so you **should not** list it in your .toc file. The file should contain an outer `<Bindings>` tag, which in turn should contain a `<Binding>` tag for each action you wish to use. For example:

```
<Bindings>
 <Binding name="SPELL Moonfire" header="WOWPEDIAUIDEMO" />
 <Binding name="SPELL Starfire" />
</Bindings>
```

would add bindings for casting Moonfire and Starfire to the default Key Bindings UI.

### Specifying bindings

Each binding you want to create should be specified using the `<Binding>` tag, which has the following three attributes:

**name**
> Required - Specifies a token for name of the action this keybinding performs; if the token is a valid [binding command](https://warcraft.wiki.gg/wiki/API_SetBinding#Arguments "API SetBinding") (like "SPELL Starfire"), the binding will always perform that command (and not run custom Lua code). When this binding is displayed to the user, FrameXML will use the text specified in the `_G["BINDING_NAME_" .. name]` global, falling back to the value of the name attribute if the global variable does not exist.

**header**
> Optional - Specifies a token for a header under which this binding will be displayed. If omitted, the binding will be displayed under the last header specified previously during the loading process. When the header is displayed to the user, FrameXML will use the text specified in the `_G["BINDING_HEADER_" .. header]` global, falling back to an empty string if the global variable does not exist.

**runOnUp**
> Optional - If explicitly set to "true", the binding will be triggered both when the button combination is pressed and when it is released. Otherwise, the binding will only be triggered when the binding is pressed.

**default**
> Optional - The default key binding for this action, e.g. "SHIFT-F".

If you want to run custom Lua code, it should be placed inside the `<Binding>` tag. From within this code snippet, you may access the binding state using the `keystate` variable, which will be "down" when the binding is pressed, and "up" when the binding is released (the latter is only observable for runOnUp="true" bindings).

**Warning**: Bindings.xml must be valid XML in order for your bindings to appear. If you need to include the `<` character in your custom Lua code within a `<Binding>` tag, you should to escape it as `&lt;`, or wrap the contents of the tag in `<![CDATA[` ... `]]>`.

### Example

Specify the bindings in `Bindings.xml`:

```
<Bindings>
 <Binding name="SPELL Moonfire" runOnUp="true" header="WOWPEDIAUIDEMO" default="SHIFT-F">
   print("Fooled! This print statement will never run.")
 </Binding>
 <Binding name="REVERSEFLOWPOLARITY">print("Neutron flow polarity reversed")</Binding>
 <Binding name="ACTIVATETRANSMOGRIFIER" runOnUp="true">
  if keystate == "down" then
   print("Transmogrifier activated. Release binding to deactivate")
  else
   print("Transmogrifier deactivated")
  end
 </Binding>
</Bindings>
```

Specify localized text in `BindingsDemo.lua`:

```
BINDING_HEADER_WOWPEDIAUIDEMO = "Custom Keybindings AddOn"
_G["BINDING_NAME_SPELL Moonfire"] = "Cast Moonfire"
BINDING_NAME_REVERSEFLOWPOLARITY = "Reverse neutron flow polarity"
BINDING_NAME_ACTIVATETRANSMOGRIFIER = "Activate the ransmogrifier"
```

Create `BindingsDemo.toc`:

```
## Interface: 120005
## Title: Keybindings Demo
BindingsDemo.lua
```

To execute this example as an addon, create the `Interface\AddOns\BindingsDemo\` directory and place the three specified files within it.

## Creating dynamic keybindings in Lua

You may also set keybindings in Lua code, which allows you to create and modify key bindings dynamically -- for instance, in response to the player's class, level, location, or configuration of your addon. However, without Bindings.xml, your addon will be responsible for presenting its own bindings configuration UI to the user.

**Note:** Setting and clearing bindings is a protected action, and cannot be performed by insecure addon code while in combat lockdown.

For more permanent bindings, similar in scope to those created by `Bindings.xml`, you can use the [SetBinding](https://warcraft.wiki.gg/wiki/API_SetBinding "API SetBinding") family of API functions. The functions take a binding string, and arguments specifying the action to be performed. Notably, if you use this method to bind a key already bound to some action in the default Key Bindings UI, that binding will be unbound. The functions are:

- [SetBinding](https://warcraft.wiki.gg/wiki/API_SetBinding "API SetBinding") for binding a generic command, or unbinding a key.
- [SetBindingSpell](https://warcraft.wiki.gg/wiki/API_SetBindingSpell "API SetBindingSpell")
- [SetBindingItem](https://warcraft.wiki.gg/wiki/API_SetBindingItem "API SetBindingItem")
- [SetBindingMacro](https://warcraft.wiki.gg/wiki/API_SetBindingMacro "API SetBindingMacro")
- [SetBindingClick](https://warcraft.wiki.gg/wiki/API_SetBindingClick "API SetBindingClick") for clicking a Button widget.

There is no API function to create a binding to execute custom Lua code. If that behavior is desired, you can use [SetBindingClick](https://warcraft.wiki.gg/wiki/API_SetBindingClick "API SetBindingClick") in conjunction with an OnClick handler on your own Button widget:

```
local btn = CreateFrame("BUTTON", "MyBindingHandlingButton")
SetBindingClick("SHIFT-T", btn:GetName())
btn:SetScript("OnClick", function(self, button, down)
 -- As we have not specified the button argument to SetBindingClick,
 -- the binding will be mapped to a LeftButton click.
 print("You triggered the binding using", button)
end)
```

If you want to merely override, but not unbind, the bindings in the Key Bindings UI, you can use the [SetOverrideBinding](https://warcraft.wiki.gg/wiki/API_SetOverrideBinding "API SetOverrideBinding") family of API functions. The functions take an _owner_ frame handle, a flag indicating priority (priority override bindings take precedence over non-priority override bindings, which take precedence over normal bindings), a binding string, and argument specifying the action to be performed. All override bindings owned by a particular frame handle can be cleared using [ClearOverrideBindings](https://warcraft.wiki.gg/wiki/API_ClearOverrideBindings "API ClearOverrideBindings"). The functions are:

- [SetOverrideBinding](https://warcraft.wiki.gg/wiki/API_SetOverrideBinding "API SetOverrideBinding") for binding a generic command, or unbinding a key.
- [SetOverrideBindingSpell](https://warcraft.wiki.gg/wiki/API_SetOverrideBindingSpell "API SetOverrideBindingSpell")
- [SetOverrideBindingItem](https://warcraft.wiki.gg/wiki/API_SetOverrideBindingItem "API SetOverrideBindingItem")
- [SetOverrideBindingMacro](https://warcraft.wiki.gg/wiki/API_SetOverrideBindingMacro "API SetOverrideBindingMacro")
- [SetOverrideBindingClick](https://warcraft.wiki.gg/wiki/API_SetOverrideBindingClick "API SetOverrideBindingClick") for clicking a Button widget.

### Dynamic bindings in combat

The SetOverrideBindings family of functions is present in the [restricted environment](https://warcraft.wiki.gg/wiki/RestrictedEnvironment "RestrictedEnvironment"), as the frame:SetBinding() family of functions. Addons may take advantage of this to update override bindings in combat using [SecureHandlers](https://warcraft.wiki.gg/wiki/SecureHandlers "SecureHandlers"), but only in response to a very limited number of events, including:

- Direct user interaction, like the player pressing a button or using a binding.
- Indirect user interaction, like protected frames being hidden or shown, by wrapping OnHide/OnShow widget handlers.
- [Macro conditionals](https://warcraft.wiki.gg/wiki/Macro_conditional "Macro conditional") being updated -- i.e. the player targeting something, summoning a pet, etc.

For example, this can be used to create an addon binding that only exists while the player has a hostile unit targeted:

```
local frame = CreateFrame("Frame", nil, nil, "SecureHandlerStateTemplate")
frame:SetAttribute("_onstate-wpbinding", [[
 if newstate == "on" then
  self:SetBindingSpell(false, "SHIFT-T", "Moonfire")
 elseif newstate == "off" then
  self:ClearBindings()
 end
]])
RegisterStateDriver(frame, "wpbinding", "[@target,harm] on; off")
```
