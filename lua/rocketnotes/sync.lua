local utils = require("rocketnotes.utils")
local tokens = require("rocketnotes.tokens")
local http = require("rocketnotes.http")

---@class InstallModule
local M = {}

M.save_document = function(
	document,
	document_path,
	last_remote_modified_table,
	last_synced_table,
	access_token,
	api_url,
	remote_document_tree_table
)
	local filePath = document_path .. "/" .. document.name .. ".md"
	local localFileExists = utils.file_exists(filePath)

	if not localFileExists then
		local document_file = utils.create_file(filePath)
		local remote_document = http.get_document(access_token, document.id, api_url)
		remote_document = vim.fn.json_decode(remote_document)
		utils.write_file(document_file, remote_document.content)
		return document.lastModified, utils.get_last_modified_date_of_file(document_file:gsub(" ", "\\ "))
	else
		local localFileLastModifiedDate = utils.get_last_modified_date_of_file(filePath:gsub(" ", "\\ "))
		local localModified = true
		local remoteModified = true
		if localFileLastModifiedDate == last_synced_table[document.id] then
			localModified = false
		end
		if document.lastModified == last_remote_modified_table[document.id] then
			remoteModified = false
		end
		-- check if local file was modified and remote file was modified. If yes, save a second copy of the file
		if localModified and remoteModified then
			local document_file_remote = utils.create_file(document_path .. "/" .. document.name .. "_remote.md")
			local remote_document = http.get_document(access_token, document.id, api_url)
			remote_document = vim.fn.json_decode(remote_document)
			utils.write_file(document_file_remote, remote_document.content)
			return document.lastModified, localFileLastModifiedDate
		-- If only remote file was modified, update the local file
		elseif remoteModified then
			local document_file = utils.create_file(document_path .. "/" .. document.name .. ".md")
			local remote_document = http.get_document(access_token, document.id, api_url)
			remote_document = vim.fn.json_decode(remote_document)
			utils.write_file(document_file, remote_document.content)
			local lastModified = utils.get_last_modified_date_of_file(document_file:gsub(" ", "\\ "))
			return document.lastModified, lastModified
		-- If only local file was modified, do save document post request
		elseif localModified then
			document.lastModified = localFileLastModifiedDate
			utils.save_remote_tree_cache(remote_document_tree_table)
			local new_document = {}
			local decoded_token = utils.decode_token(access_token)
			new_document.id = document.id
			new_document.userId = decoded_token.username
			new_document.title = document.name
			new_document.content = utils.read_file(filePath)
			new_document.lastModified = localFileLastModifiedDate
			new_document.recreateIndex = false
			local body = {
				document = new_document,
				documentTree = remote_document_tree_table,
			}
			http.post_document(access_token, api_url, body)
			return localFileLastModifiedDate, localFileLastModifiedDate
		else
			return document.lastModified, localFileLastModifiedDate
		end
	end
end

M.create_document_space = function(
	document,
	documentPath,
	access_token,
	apiUrl,
	lastRemoteModifiedTable,
	lastSyncedTable,
	remote_document_tree_table
)
	local document_path = utils.get_workspace_path() .. "/" .. documentPath
	utils.create_directory_if_not_exists(document_path)
	return M.save_document(
		document,
		document_path,
		lastRemoteModifiedTable,
		lastSyncedTable,
		access_token,
		apiUrl,
		remote_document_tree_table
	)
end

M.process_document = function(
	document,
	parent_name,
	access_token,
	api_url,
	lastRemoteModifiedTable,
	lastSyncedTable,
	remote_document_tree_table
)
	local document_path = parent_name and (parent_name .. "/" .. document.name) or document.name
	lastRemoteModifiedTable[document.id], lastSyncedTable[document.id] = M.create_document_space(
		document,
		document_path,
		access_token,
		api_url,
		lastRemoteModifiedTable,
		lastSyncedTable,
		remote_document_tree_table
	)

	if document.children and type(document.children) == "table" then
		for _, child_document in ipairs(document.children) do
			M.process_document(
				child_document,
				document_path,
				access_token,
				api_url,
				lastRemoteModifiedTable,
				lastSyncedTable,
				remote_document_tree_table
			)
		end
	end
end

M.sync = function()
	local id_token, access_token, refresh_token, clientId, api_url, domain, region = tokens.get_tokens()
	print("Sync RocketNotes...")

	local local_document_tree = utils.load_tree_cache()
	local lastRemoteModifiedTable = utils.load_remote_last_modified_table()
	local lastSyncedTable = utils.load_last_synced_table()
	local remote_document_tree = http.get_tree(access_token, api_url)

	local start_index, end_index = string.find(remote_document_tree, "Unauthorized")
	if start_index then
		tokens.refresh_token()
		id_token, access_token = tokens.get_tokens()
		remote_document_tree = http.get_tree(access_token, api_url)
	end

	utils.save_file(utils.get_tree_cache_file(), remote_document_tree)

	local remote_document_tree_table = vim.fn.json_decode(remote_document_tree)
	if type(remote_document_tree_table.documents) == "table" then
		for _, document in ipairs(remote_document_tree_table.documents) do
			M.process_document(
				document,
				nil,
				access_token,
				api_url,
				lastRemoteModifiedTable,
				lastSyncedTable,
				remote_document_tree_table
			)
		end
	else
		print("data.documents is not a table")
	end

	print("RocketNotes synced successfully")

	---------------------------------------------
	-- TODO upload newly local created documents and update remote document tree.
	-- For this use deopth first search and traverse the local document tree.
	-- If a document is not present in the lastRemoteModifiedTable, it was created locally
	--   because it was not synced yet. In this case, upload the document and update the local tree
	--   by attaching the document to the parent in the remote document tree.
	if local_document_tree then
		local remote_documents =
			utils.create_node_map(utils.flatten_document_tree(remote_document_tree_table.documents))
		local local_documents = utils.create_node_map(utils.flatten_document_tree(local_document_tree.documents))
		local local_document_paths = utils.get_all_files(utils.get_workspace_path())
	end
	---------------------------------------------
	utils.save_remote_last_modified_table(lastRemoteModifiedTable)
	utils.save_last_synced_table(lastSyncedTable)
end

return M
