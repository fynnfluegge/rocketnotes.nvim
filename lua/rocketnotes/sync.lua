local utils = require("rocketnotes.utils")
local tokens = require("rocketnotes.tokens")
local http = require("rocketnotes.http")

---@class InstallModule
local M = {}

M.saveDocument = function(document, path, lastRemoteModifiedTable, lastSyncedTable, access_token, api_url, region)
	document = vim.fn.json_decode(document)
	local filePath = path .. "/" .. document.title .. ".md"
	local localFileExists = utils.file_exists(filePath)

	if not localFileExists then
		local document_file = utils.create_file(filePath)
		utils.write_file(document_file, document.content)
		return document.lastModified, utils.get_last_modified_date_of_file(document_file:gsub(" ", "\\ "))
	else
		local localFileLastModifiedDate = utils.get_last_modified_date_of_file(filePath:gsub(" ", "\\ "))
		local localModified = true
		local remoteModified = true
		if localFileLastModifiedDate == lastSyncedTable[document.id] then
			localModified = false
		end
		if document.lastModified == lastRemoteModifiedTable[document.id] then
			remoteModified = false
		end
		-- check if local file was modified and remote file was modified. If yes, save a second copy of the file
		if localModified and remoteModified then
			local document_file_remote = utils.create_file(path .. "/" .. document.title .. "_remote.md")
			utils.write_file(document_file_remote, document.content)
			return document.lastModified, localFileLastModifiedDate
		-- If only remote file was modified, update the local file
		elseif remoteModified then
			local document_file = utils.create_file(path .. "/" .. document.title .. ".md")
			utils.write_file(document_file, document.content)
			local lastModified = utils.get_last_modified_date_of_file(document_file:gsub(" ", "\\ "))
			return document.lastModified, lastModified
		-- If only local file was modified, do save document post request
		elseif localModified then
			document.content = utils.read_file(filePath)
			document.recreateIndex = false
			local body = {}
			body.document = document
			http.postDocument(access_token, api_url, region, body)
			return document.lastModified, localFileLastModifiedDate
		else
			return document.lastModified, localFileLastModifiedDate
		end
	end
end

M.create_document_space = function(
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
	return M.saveDocument(
		http.getDocument(access_token, documentId, apiUrl, region),
		path,
		lastRemoteModifiedTable,
		lastSyncedTable,
		access_token,
		apiUrl,
		region
	)
end

M.process_document = function(
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
	local id_token, access_token, refresh_token, clientId, api_url, domain, region = tokens.get_tokens()
	print("Installing RocketNotes...")

	local local_document_tree = utils.read_file(utils.get_tree_cache_file())
	local remote_document_tree = http.getTree(access_token, api_url, region)
	local lastRemoteModifiedTable = utils.loadRemoteLastModifiedTable()
	local lastSyncedTable = utils.loadLastSyncedTable()

	local start_index, end_index = string.find(remote_document_tree, "Unauthorized")
	if start_index then
		tokens.refresh_token()
		id_token, access_token = tokens.get_tokens()
		remote_document_tree = http.getTree(access_token, api_url, region)
	end

	local remote_document_tree_table = vim.fn.json_decode(remote_document_tree)
	if type(remote_document_tree_table.documents) == "table" then
		for _, document in ipairs(remote_document_tree_table.documents) do
			M.process_document(document, nil, access_token, api_url, region, lastRemoteModifiedTable, lastSyncedTable)
		end
	else
		print("data.documents is not a table")
	end

	---------------------------------------------
	-- TODO upload newly local created documents and update remote document tree
	if local_document_tree then
		local remote_documents = utils.createNodeMap(utils.flattenDocumentTree(remote_document_tree_table.documents))
		local local_document_paths = utils.getAllFiles(utils.get_workspace_path())
		-- This is needed to keep track of newly created documents in local workspace that have been uploaded already
		-- during iteration of local documents. Once a newly created document with a parent is found, the whole subtree is synced
		local created_documents = {}
		for _, document_path in ipairs(local_document_paths) do
			local parent_folder, file_name = utils.getFileNameAndParentDir(document_path)
			print(parent_folder, file_name)
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
				created_documents[file_name] = true
			end
		end
	end
	---------------------------------------------

	utils.saveFile(utils.get_tree_cache_file(), remote_document_tree)
	utils.saveRemoteLastModifiedTable(lastRemoteModifiedTable)
	utils.saveLastSyncedTable(lastSyncedTable)
end

return M
