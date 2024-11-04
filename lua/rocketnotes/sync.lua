local utils = require("rocketnotes.utils")
local login = require("rocketnotes.login")

---@class InstallModule
local M = {}

local function getTree(access_token, apiUrl, region)
	local decoded_token = utils.decodeToken(access_token)
	local user_id = decoded_token.username

	local command = string.format(
		'curl -X GET "https://%s.execute-api.%s.amazonaws.com/documentTree/%s" -H "Authorization: Bearer %s"',
		apiUrl,
		region,
		user_id,
		access_token
	)

	-- Capture the output
	local handle = io.popen(command)
	local result = handle:read("*a") -- read all output
	handle:close()
	return result
end

local function getDocument(access_token, documentId, apiUrl, region)
	local command = string.format(
		'curl -X GET "https://%s.execute-api.%s.amazonaws.com/document/%s" -H "Authorization: Bearer %s"',
		apiUrl,
		region,
		documentId,
		access_token
	)

	-- Capture the output
	local handle = io.popen(command)
	local result = handle:read("*a") -- read all output
	handle:close()
	return result
end

local function saveDocument(document, path)
	document = vim.fn.json_decode(document)
	print(document.lastModified)
	local document_file = utils.create_file(path .. "/" .. document.title .. ".md")
	utils.write_file(document_file, document.content)
end

local function save_last_modified_map() end

---@return string
M.sync = function()
	local id_token, access_token = login.get_tokens()
	print("Installing RocketNotes...")

	local result = getTree(access_token)
	local start_index, end_index = string.find(result, "Unauthorized")
	if start_index then
		print("unauthorized")
		login.refresh_token()
		id_token, access_token = login.get_tokens()
		result = getTree(access_token)
	end

	utils.saveFile(utils.get_tree_cache_file(), result)
	local data = vim.fn.json_decode(result)
	-- Check if data.documents is a table
	if type(data.documents) == "table" then
		-- Iterate over the elements in data.documents
		for index, document in ipairs(data.documents) do
			-- Process each document
			-- Root documents
			-- print("Document: " .. document.id .. " " .. document.name)
			local path = utils.get_workspace_path() .. "/" .. document.name
			utils.create_directory_if_not_exists(path)
			saveDocument(getDocument(access_token, document.id), path)
			for key, value in pairs(document) do
				-- Instead recursion, let's just go 3 levels deep
				-- 1st Level
				if key == "children" and type(value) == "table" and next(value) ~= nil then
					for childIndex, childDocument in ipairs(value) do
						-- print("1st ChildDocument: " .. childDocument.id .. " " .. childDocument.name)
						path = utils.get_workspace_path() .. "/" .. document.name .. "/" .. childDocument.name
						utils.create_directory_if_not_exists(path)
						saveDocument(getDocument(access_token, childDocument.id), path)
						for childKey, childValue in pairs(childDocument) do
							-- 2nd level
							if childKey == "children" and type(childValue) == "table" then
								for _childIndex, _childDocument in ipairs(childValue) do
									-- print("2nd ChildDocument: " .. _childDocument.id .. " " .. _childDocument.name)
									path = utils.get_workspace_path()
										.. "/"
										.. document.name
										.. "/"
										.. childDocument.name
										.. "/"
										.. _childDocument.name
									utils.create_directory_if_not_exists(path)
									saveDocument(getDocument(access_token, _childDocument.id), path)
									for _childKey, _childValue in pairs(_childDocument) do
										-- 3rd level
										if _childKey == "children" and type(_childValue) == "table" then
											for __childIndex, __childDocument in ipairs(_childValue) do
												-- print(
												-- 	"3rd ChildDocument: "
												-- 		.. __childDocument.id
												-- 		.. " "
												-- 		.. __childDocument.name
												-- )
												path = utils.get_workspace_path()
													.. "/"
													.. document.name
													.. "/"
													.. childDocument.name
													.. "/"
													.. _childDocument.name
													.. "/"
													.. __childDocument.name
												utils.create_directory_if_not_exists(path)
												saveDocument(getDocument(access_token, __childDocument.id), path)
											end
										end
									end
								end
							end
						end
					end
				end
			end
		end
	else
		print("data.documents is not a table")
	end
end

return M
