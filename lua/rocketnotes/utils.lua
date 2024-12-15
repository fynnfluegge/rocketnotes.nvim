---@class UtilsModule
local M = {}

M.create_directory_if_not_exists = function(dir)
	local check_command = '[ -d "' .. dir .. '" ]'
	local result = os.execute(check_command)

	if result ~= 0 then
		local create_command = 'mkdir -p "' .. dir .. '"'
		os.execute(create_command)
	end

	return dir
end

M.create_file = function(file)
	local check_command = '[ -f "' .. file .. '" ]'
	local result = os.execute(check_command)

	if result ~= 0 then
		local create_command = 'touch "' .. file .. '"'
		os.execute(create_command)
	end

	return file
end

M.write_file = function(file, content)
	local file = io.open(file, "w")
	if file then
		file:write(content)
		file:close()
	else
		print("Failed to open file for writing.")
	end
end

M.file_exists = function(file)
	local check_command = '[ -f "' .. file .. '" ]'
	local result = os.execute(check_command)

	return result == 0
end

M.read_file = function(file)
	local file = io.open(file, "r")
	if file then
		local content = file:read("*a")
		file:close()
		return content
	else
		print("Failed to open file for reading.")
	end
end

M.get_config_path = function()
	local home = os.getenv("HOME") or os.getenv("USERPROFILE")

	if package.config:sub(1, 1) == "\\" then
		-- Windows
		return M.create_directory_if_not_exists(home .. "\\AppData\\Local\\rocketnotes")
	else
		-- macOS and Linux
		return M.create_directory_if_not_exists(home .. "/Library/Application Support/rocketnotes")
	end
end

M.get_documents_cache_path = function()
	return M.get_config_path() .. "/documents"
end

M.get_tree_cache_file = function()
	return M.get_config_path() .. "/tree.json"
end

M.get_workspace_path = function()
	local home = os.getenv("HOME") or os.getenv("USERPROFILE")

	if package.config:sub(1, 1) == "\\" then
		-- Windows
		return M.create_directory_if_not_exists(home .. "\\.rocketnotes")
	else
		-- macOS and Linux
		return M.create_directory_if_not_exists(home .. "/.rocketnotes")
	end
end

M.loadRemoteLastModifiedTable = function()
	local lastModifiedTableFile = M.get_config_path() .. "/lastRemoteModified.json"
	if M.file_exists(lastModifiedTableFile) then
		return vim.fn.json_decode(M.read_file(lastModifiedTableFile))
	end
	return {}
end

M.loadLastSyncedTable = function()
	local lastModifiedTableFile = M.get_config_path() .. "/lastSynced.json"
	if M.file_exists(lastModifiedTableFile) then
		return vim.fn.json_decode(M.read_file(lastModifiedTableFile))
	end
	return {}
end

M.saveRemoteLastModifiedTable = function(lastRemoteModifiedTable)
	local lastModifiedTableFile = M.create_file(M.get_config_path() .. "/lastRemoteModified.json")
	M.write_file(lastModifiedTableFile, vim.fn.json_encode(lastRemoteModifiedTable))
end

M.saveLastSyncedTable = function(lastModifiedTable)
	local lastModifiedTableFile = M.create_file(M.get_config_path() .. "/lastSynced.json")
	M.write_file(lastModifiedTableFile, vim.fn.json_encode(lastModifiedTable))
end

M.decodeToken = function(token)
	local jq_command =
		string.format("echo '%s' | jq -R 'split(\".\") | select(length > 0) | .[1] | @base64d | fromjson'", token)

	-- Execute the command and capture the output
	local handle = io.popen(jq_command) -- Open a pipe to the command
	local result = handle:read("*a") -- Read the output
	if string.sub(result, -1) == "\n" then
		result = string.sub(result, 1, -2) -- Remove the last character if it's a line break
	end
	local decoded_token = vim.fn.json_decode(result)
	handle:close() -- Close the pipe
	return decoded_token
end

M.saveFile = function(file, content)
	local file = io.open(file, "w")
	if file then
		file:write(content)
		file:close()
	else
		print("Failed to open file for writing.")
	end
end

M.flattenDocumentTree = function(t)
	local flat_list = {}

	local function flatten(node)
		table.insert(flat_list, {
			id = node.id,
			name = node.name,
			parent = node.parent,
			pinned = node.pinned,
		})
		if type(node.children) == "table" then
			for _, child in ipairs(node.children) do
				flatten(child)
			end
		end
	end

	for _, node in ipairs(t) do
		flatten(node)
	end

	return flat_list
end

M.createNodeMap = function(flat_list)
	local node_map = {}

	for _, node in ipairs(flat_list) do
		node_map[node.name] = node
	end

	return node_map
end

M.get_full_document_path = function(parent, name, tree)
	local path = name
	while parent do
		local parent_node = tree[parent]
		path = parent_node.name .. "/" .. path
		parent = parent_node.parent
	end
	return path
end

M.traverseDocumentTree = function(t, callback)
	local function traverse(node)
		callback(node)
		if node.children then
			for _, child in ipairs(node.children) do
				traverse(child)
			end
		end
	end

	for _, node in ipairs(t) do
		traverse(node)
	end
end

M.get_last_modified_date_of_file = function(file_path)
	local handle = io.popen("stat -f %m " .. file_path)
	local result = handle:read("*a")
	handle:close()
	return tonumber(result)
end

M.traverseDirectory = function(dir, callback)
	local p = io.popen('find "' .. dir .. '" -type d')
	for directory in p:lines() do
		callback(directory)
	end
	p:close()
end

M.getAllFiles = function(dir)
	local files = {}
	local p = io.popen('find "' .. dir .. '" -type f')
	for file in p:lines() do
		table.insert(files, file)
	end
	p:close()
	return files
end

M.getFileNameAndParentDir = function(filePath)
	local parentDir, fileName = filePath:match("(.*/)([^/]+)$")
	local fileNameWithoutExtension = fileName:gsub("%.[^%.]+$", "")
	parentDir = parentDir:gsub("^/", ""):gsub("/$", "")
	return parentDir, fileNameWithoutExtension
end

M.map = function(tbl)
	local t = {}
	for k, v in pairs(tbl) do
		t[k] = v
	end
	return t
end

-- Function to escape special characters in strings
local function escape_str(s)
	return s:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t")
end

M.trim = function(s)
	return (s:gsub("^%s*(.-)%s*$", "%1"))
end

-- Function to convert a Lua table to JSON
M.table_to_json = function(tbl)
	local result = {}
	local function serialize(tbl)
		local is_array = (#tbl > 0)
		table.insert(result, is_array and "[" or "{")
		local first = true
		for k, v in pairs(tbl) do
			if not first then
				table.insert(result, ",")
			end
			first = false
			if not is_array then
				table.insert(result, '"' .. escape_str(tostring(k)) .. '":')
			end
			if type(v) == "table" then
				serialize(v)
			elseif type(v) == "string" then
				table.insert(result, '"' .. escape_str(v) .. '"')
			elseif type(v) == "number" or type(v) == "boolean" then
				table.insert(result, tostring(v))
			else
				error("Unsupported data type: " .. type(v))
			end
		end
		table.insert(result, is_array and "]" or "}")
	end
	serialize(tbl)
	return table.concat(result)
end

M.decode_base64 = function(input)
	local handle = io.popen('echo "' .. input .. '" | base64 --decode')
	local result = handle:read("*a")
	handle:close()
	return result
end

return M
