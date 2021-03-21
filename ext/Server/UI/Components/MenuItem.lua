class('MenuItem');

function MenuItem:__init(title, name, callback, shortcut)
	self.title		= title or nil;
	self.name		= name or nil;
	self.callback	= callback or nil;
	self.shortcut	= shortcut or nil;
	self.icon		= nil;
	self.items		= {};
	self.inputs		= {};
end

function MenuItem:__class()
	return 'MenuItem';
end

function MenuItem:AddItem(item)
	if (item == nil or item['__class'] == nil) then
		-- Bad Item
		return self;
	end
	
	if (item:__class() ~= 'MenuItem' and item:__class() ~= 'MenuSeparator') then
		-- Exception: Only Menu, MenuSeparator or MenuItem
		return self;
	end
	
	table.insert(self.items, item);
	
	return self;
end

function MenuItem:SetIcon(file)
	self.icon = file;
	
	return self;
end

function MenuItem:GetItems()
	return self.items;
end

function MenuItem:HasItems()
	return #self.items >= 1;
end

function MenuItem:GetInputs()
	return self.inputs;
end

function MenuItem:HasInputs()
	return #self.inputs >= 1;
end

-- Title
function MenuItem:GetTitle()
	return self.title;
end

function MenuItem:SetTitle(title)
	self.title = title;
	
	return self;
end

-- Name
function MenuItem:GetName()
	return self.name;
end

function MenuItem:SetName(name)
	self.name = name;
	
	return self;
end

-- Callback
function MenuItem:GetCallback()
	return self.callback;
end

function MenuItem:SetCallback(callback)
	self.callback = callback;
	
	return self;
end

function MenuItem:FireCallback()
	if (self.callback == nil) then
		print('MenuItem ' .. self.name .. ' has no Callback.');
		return;
	end
	
	if (type(self.callback) == 'string') then
		print('MenuItem ' .. self.name .. ' has an reference Callback.');
		return;
	end;
	
	self.callback();
	
	return self;
end

-- Shortcut
function MenuItem:GetShortcut()
	return self.shortcut;
end

function MenuItem:SetShortcut(shortcut)
	self.shortcut = shortcut;
	
	return self;
end

function MenuItem:HasShortcut()
	return (self.shortcut ~= nil);
end

-- Input
function MenuItem:AddInput(position, input)
	if (input == nil or input['__class'] == nil) then
		-- Bad Item
		return self;
	end
	
	if (input:__class() ~= 'Input') then
		-- Exception: Only Menu, Separator (-) or MenuItem
		return self;
	end
	
	table.insert(self.inputs, {
		Position	= position,
		Input		= input
	});
	
	return self;
end

function MenuItem:Serialize()
	local items		= {};
	local inputs	= {};
	local callback	= nil;
	
	if (type(self.callback) == 'function') then
		callback	= 'MenuItem$' .. self.name;
	else
		callback	= self.callback;
	end
	
	for _, item in pairs(self.items) do
		table.insert(items, {
			Type = item:__class(),
			Data = item:Serialize()
		});
	end
	
	for _, data in pairs(self.inputs) do
		table.insert(inputs, {
			Type		= data.Input:__class(),
			Data		= data.Input:Serialize(),
			Position	= data.Position
		});
	end
	
	if (#items >= 1) then
		return {
			Title		= self.title,
			Name		= self.name,
			Icon		= self.icon,
			Items		= items
		};
	end
	
	return {
		Title		= self.title,
		Name		= self.name,
		Icon		= self.icon,
		Callback	= callback,
		Shortcut	= self.shortcut,
		Inputs		= inputs
	};
end

return MenuItem;