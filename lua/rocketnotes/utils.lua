---@class UtilsModule
local M = {}

M.create_directory_if_not_exists = function(dir)
	-- Check if the directory exists using the test command
	local check_command = '[ -d "' .. dir .. '" ]'
	local result = os.execute(check_command)

	-- If the directory does not exist, create it
	if result ~= 0 then
		local create_command = 'mkdir -p "' .. dir .. '"'
		os.execute(create_command)
	end

	return dir
end

M.create_file = function(file)
	-- Check if the file exists using the test command
	local check_command = '[ -f "' .. file .. '" ]'
	local result = os.execute(check_command)

	-- If the file does not exist, create it
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

return M
