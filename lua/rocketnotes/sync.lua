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

local function get_last_modified_date(file_path)
	local handle = io.popen("stat -f %m " .. file_path)
	local result = handle:read("*a")
	handle:close()
	return tonumber(result)
end

local function saveRemoteLastModifiedTable(lastRemoteModifiedTable)
	local lastModifiedTableFile = utils.create_file(utils.get_config_path() .. "/lastRemoteModified.json")
	utils.write_file(lastModifiedTableFile, vim.fn.json_encode(lastRemoteModifiedTable))
end

local function saveLastSyncedTable(lastModifiedTable)
	local lastModifiedTableFile = utils.create_file(utils.get_config_path() .. "/lastSynced.json")
	utils.write_file(lastModifiedTableFile, vim.fn.json_encode(lastModifiedTable))
end

local function saveDocument(document, path)
	document = vim.fn.json_decode(document)
	local document_file = utils.create_file(path .. "/" .. document.title .. ".md")
	utils.write_file(document_file, document.content)
	local lastModified = get_last_modified_date(document_file:gsub(" ", "\\ "))
	return document.lastModified, lastModified
end

local function create_document_space(documentId, documentPath, access_token, apiUrl, region)
	local path = utils.get_workspace_path() .. "/" .. documentPath
	utils.create_directory_if_not_exists(path)
	return saveDocument(getDocument(access_token, documentId, apiUrl, region), path)
end

---@return string
M.sync = function()
	local id_token, access_token, refresh_token, clientId, api_url, domain, region = login.get_tokens()
	print("Installing RocketNotes...")

	local result = getTree(access_token, api_url, region)
	local start_index, end_index = string.find(result, "Unauthorized")
	if start_index then
		print("unauthorized")
		login.refresh_token()
		id_token, access_token = login.get_tokens()
		result = getTree(access_token, api_url, region)
	end

	utils.saveFile(utils.get_tree_cache_file(), result)
	local data = vim.fn.json_decode(result)
	if type(data.documents) == "table" then
		local lastRemoteModifiedTable = {}
		local lastSyncedTable = {}
		for index, document in ipairs(data.documents) do
			-- Root documents
			lastRemoteModifiedTable[document.id], lastSyncedTable[document.id] =
				create_document_space(document.id, document.name, access_token, api_url, region)
			for key, value in pairs(document) do
				-- Instead recursion, let's just go 4 levels deep
				-- 1st Level
				if key == "children" and type(value) == "table" and next(value) ~= nil then
					for childIndex, childDocument in ipairs(value) do
						lastRemoteModifiedTable[childDocument.id], lastSyncedTable[childDocument.id] =
							create_document_space(
								childDocument.id,
								document.name .. "/" .. childDocument.name,
								access_token,
								api_url,
								region
							)
						for childKey, childValue in pairs(childDocument) do
							-- 2nd level
							if childKey == "children" and type(childValue) == "table" then
								for _childIndex, _childDocument in ipairs(childValue) do
									lastRemoteModifiedTable[_childDocument.id], lastSyncedTable[_childDocument.id] =
										create_document_space(
											_childDocument.id,
											document.name .. "/" .. childDocument.name .. "/" .. _childDocument.name,
											access_token,
											api_url,
											region
										)
									for _childKey, _childValue in pairs(_childDocument) do
										-- 3rd level
										if _childKey == "children" and type(_childValue) == "table" then
											for __childIndex, __childDocument in ipairs(_childValue) do
												lastRemoteModifiedTable[__childDocument.id], lastSyncedTable[__childDocument.id] =
													create_document_space(
														__childDocument.id,
														document.name
															.. "/"
															.. childDocument.name
															.. "/"
															.. _childDocument.name
															.. "/"
															.. __childDocument.name,
														access_token,
														api_url,
														region
													)
												for __childKey, __childValue in pairs(__childDocument) do
													-- 4th level
													if __childKey == "children" and type(__childValue) == "table" then
														for ___childIndex, ___childDocument in ipairs(__childValue) do
															lastRemoteModifiedTable[___childDocument.id], lastSyncedTable[___childDocument.id] =
																create_document_space(
																	___childDocument.id,
																	document.name
																		.. "/"
																		.. childDocument.name
																		.. "/"
																		.. _childDocument.name
																		.. "/"
																		.. __childDocument.name
																		.. "/"
																		.. ___childDocument.name,
																	access_token,
																	api_url,
																	region
																)
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
				end
			end
		end
		saveRemoteLastModifiedTable(lastRemoteModifiedTable)
		saveLastSyncedTable(lastSyncedTable)
	else
		print("data.documents is not a table")
	end
end

return M
