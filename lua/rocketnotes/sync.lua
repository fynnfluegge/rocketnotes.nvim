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

local function postDocument(access_token, apiUrl, region, document)
	local command = string.format(
		'curl -X POST "https://%s.execute-api.%s.amazonaws.com/saveDocument" -H "Authorization: Bearer %s" -H "Content-Type: application/json" -d \'%s\'',
		apiUrl,
		region,
		access_token,
		document
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

local function loadRemoteLastModifiedTable()
	local lastModifiedTableFile = utils.get_config_path() .. "/lastRemoteModified.json"
	if utils.file_exists(lastModifiedTableFile) then
		return vim.fn.json_decode(utils.read_file(lastModifiedTableFile))
	end
	return {}
end

local function loadLastSyncedTable()
	local lastModifiedTableFile = utils.get_config_path() .. "/lastSynced.json"
	if utils.file_exists(lastModifiedTableFile) then
		return vim.fn.json_decode(utils.read_file(lastModifiedTableFile))
	end
	return {}
end

local function saveRemoteLastModifiedTable(lastRemoteModifiedTable)
	local lastModifiedTableFile = utils.create_file(utils.get_config_path() .. "/lastRemoteModified.json")
	utils.write_file(lastModifiedTableFile, vim.fn.json_encode(lastRemoteModifiedTable))
end

local function saveLastSyncedTable(lastModifiedTable)
	local lastModifiedTableFile = utils.create_file(utils.get_config_path() .. "/lastSynced.json")
	utils.write_file(lastModifiedTableFile, vim.fn.json_encode(lastModifiedTable))
end

local function saveDocument(document, path, lastRemoteModifiedTable, lastSyncedTable, access_token, api_url, region)
	document = vim.fn.json_decode(document)
	local filePath = path .. "/" .. document.title .. ".md"
	local localFileExists = utils.file_exists(filePath)

	if not localFileExists then
		local document_file = utils.create_file(filePath)
		utils.write_file(document_file, document.content)
		return document.lastModified, get_last_modified_date(document_file:gsub(" ", "\\ "))
	else
		local localFileLastModifiedData = get_last_modified_date(filePath:gsub(" ", "\\ "))
		local localModified = true
		local remoteModified = true
		if localFileLastModifiedData == lastSyncedTable[document.id] then
			localModified = false
		end
		if document.lastModified == lastRemoteModifiedTable[document.id] then
			remoteModified = false
		end
		local document_file = utils.create_file(path .. "/" .. document.title .. ".md")
		local lastModified = get_last_modified_date(document_file:gsub(" ", "\\ "))
		-- check if local file was modified and remote file was modified. If yes, save a second copy of the file
		if localModified and remoteModified then
			local document_file_remote = utils.create_file(path .. "/" .. document.title .. "_remote.md")
			utils.write_file(document_file_remote, document.content)
			return document.lastModified, lastModified
		-- If only remote file was modified, update the local file
		elseif remoteModified then
			document_file = utils.create_file(path .. "/" .. document.title .. ".md")
			utils.write_file(document_file, document.content)
			lastModified = get_last_modified_date(document_file:gsub(" ", "\\ "))
			return document.lastModified, lastModified
		-- If only local file was modified, do save document post request
		elseif localModified then
			document.content = utils.read_file(document_file)
			document.recreateIndex = false
			local body = {}
			body.document = document
			postDocument(access_token, api_url, region, utils.table_to_json(body))
			return document.lastModified, lastModified
		else
			return document.lastModified, lastModified
		end
	end
end

local function create_document_space(
	documentId,
	documentPath,
	access_token,
	apiUrl,
	region,
	lastRemoteModifiedTable,
	lastSyncedTable
)
	local path = utils.get_workspace_path() .. "/" .. documentPath
	utils.create_directory_if_not_exists(path)
	return saveDocument(
		getDocument(access_token, documentId, apiUrl, region),
		path,
		lastRemoteModifiedTable,
		lastSyncedTable,
		access_token,
		apiUrl,
		region
	)
end

local function process_document(
	document,
	parent_name,
	access_token,
	api_url,
	region,
	lastRemoteModifiedTable,
	lastSyncedTable
)
	local document_name = parent_name and (parent_name .. "/" .. document.name) or document.name
	lastRemoteModifiedTable[document.id], lastSyncedTable[document.id] = create_document_space(
		document.id,
		document_name,
		access_token,
		api_url,
		region,
		lastRemoteModifiedTable,
		lastSyncedTable
	)

	if document.children and type(document.children) == "table" then
		for _, child_document in ipairs(document.children) do
			process_document(
				child_document,
				document_name,
				access_token,
				api_url,
				region,
				lastRemoteModifiedTable,
				lastSyncedTable
			)
		end
	end
end

M.sync = function()
	local id_token, access_token, refresh_token, clientId, api_url, domain, region = login.get_tokens()
	print("Installing RocketNotes...")

	local local_document_tree = utils.read_file(utils.get_tree_cache_file())
	local remote_document_tree = getTree(access_token, api_url, region)
	local lastRemoteModifiedTable = loadRemoteLastModifiedTable()
	local lastSyncedTable = loadLastSyncedTable()

	local start_index, end_index = string.find(remote_document_tree, "Unauthorized")
	if start_index then
		print("unauthorized")
		login.refresh_token()
		id_token, access_token = login.get_tokens()
		remote_document_tree = getTree(access_token, api_url, region)
	end

	local remote_document_tree_table = vim.fn.json_decode(remote_document_tree)
	if type(remote_document_tree_table.documents) == "table" then
		for _, document in ipairs(remote_document_tree_table.documents) do
			process_document(document, nil, access_token, api_url, region, lastRemoteModifiedTable, lastSyncedTable)
		end
	else
		print("data.documents is not a table")
	end

	---------------------------------------------
	-- TODO upload newly local created documents
	if local_document_tree then
		local local_document_tree_table = vim.fn.json_decode(local_document_tree)
		local local_documents = utils.createNodeMap(utils.flattenDocumentTree(local_document_tree_table.documents))
		local remote_documents = utils.createNodeMap(utils.flattenDocumentTree(remote_document_tree_table.documents))
		local local_document_paths = utils.getAllFiles(utils.get_workspace_path())
		-- This is needed to keep track of newly created documents in local workspace that have been uploaded already
		-- during iteration of local documents. Once a newly created document with a parent is found, the whole subtree is synced
		local created_documents = {}
		for _, document_path in ipairs(local_document_paths) do
			-- print(document_path)
			local parent_folder, file_name = utils.getFileNameAndParentDir(document_path)
			if
				not remote_documents[file_name]
				and (remote_documents[parent_folder] or parent_folder == "root")
				and not created_documents[file_name]
			then
				-- print("create document " .. file_name)
				utils.traverseDirectory(document_path, function(file)
					-- TODO update local tree and upload document
					-- print("TODO update local tree and upload document " .. file)
				end)
			end
		end
	end
	---------------------------------------------

	utils.saveFile(utils.get_tree_cache_file(), remote_document_tree)
	saveRemoteLastModifiedTable(lastRemoteModifiedTable)
	saveLastSyncedTable(lastSyncedTable)
end

return M
