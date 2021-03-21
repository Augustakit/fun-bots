class('UI');

function UI:__init()
	Events:Subscribe('Extension:Loaded', self, self.__boot);
	Events:Subscribe('Extension:Unloading', self, self.__destroy);
end

function UI:__boot()
	WebUI:Init();
	WebUI:Show();
	
	Events:Subscribe('Client:UpdateInput', self, self.OnUpdateInput);
	Events:Subscribe('UI', self, self.__local);
	NetEvents:Subscribe('UI', self, self.__action);
end

function UI:__destroy()
	WebUI:ResetMouse();
	WebUI:ResetKeyboard();
	WebUI:Hide();
end

function UI:OnUpdateInput(data)
	if InputManager:WentKeyDown(InputDeviceKeys.IDK_F12) then
		NetEvents:Send('UI', 'VIEW', 'BotEditor', 'TOGGLE');
		NetEvents:Send('UI', 'VIEW', 'WaypointEditor', 'HIDE');
	end
end

function UI:__local(string)
	local data, error = json.decode(string);
	
	if (data == nil) then
		print('[UI] Bad JSON: ' .. tostring(error) .. ', ' .. tostring(string));
		return;
	end
	
	local type			= data[1];
	local destination	= data[2];
	local action		= data[3];
	local data			= data[4];
	
	print('[UI] Action { Type=' .. tostring(type) .. ', Destination=' .. tostring(destination) ..', Action=' .. tostring(action) .. ', Data=' .. json.encode(data) .. '}');
	NetEvents:Send('UI', type, destination, action, data);
end

function UI:__action(type, destination, action, data)
	print('[UI] Action { Type=' .. tostring(type) .. ', Destination=' .. tostring(destination) ..', Action=' .. tostring(action) .. ', Data=' .. json.encode(data) .. '}');
	
	if action == 'ACTIVATE' then
		WebUI:EnableMouse();
		WebUI:EnableKeyboard();
	elseif action == 'DEACTIVATE' then
		WebUI:ResetMouse();
		WebUI:ResetKeyboard();
	end
	
	WebUI:ExecuteJS('UI.Handle(' .. json.encode({
		Type		= type,
		Destination	= destination,
		Action		= action,
		Data		= data
	}) .. ');');
end

if (g_UI == nil) then
	g_UI = UI();
end

return g_UI;