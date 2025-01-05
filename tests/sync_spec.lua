local sync = require("rocketnotes.sync")
local utils = require("rocketnotes.utils")
local tokens = require("rocketnotes.tokens")
local http = require("rocketnotes.http")
local json = require("dkjson")
local mock = require("luassert.mock")
local assert = require("luassert")
local busted = require("busted")

describe("rocketnotes.sync", function()
	describe("save_document", function()
		local file_name = "Test Document.md"
		local lastRemoteModified = "2023-09-30T12:00:00Z"
		local documentTitle = "Test Document"
		local documentContent = "This is a test document."
		local document = {
			id = "doc1",
			name = documentTitle,
			content = documentContent,
			lastModified = lastRemoteModified,
		}
		local remote_document =
			'{"id": "doc1", "title": "Test Document", "content": "This is a test document.", "lastModified": "2023-09-30T12:00:00Z"}'
		local path = "/path/to/documents"
		local lastSynced = "2023-09-31T12:00:00Z"
		local lastRemoteModifiedTable = { doc1 = lastRemoteModified }
		local lastSyncedTable = { doc1 = lastSynced }
		local access_token = "dummy_access_token"
		local api_url = "https://api.example.com"
		local lastLocalModified = "2023-09-29T12:00:00Z"
		local dummy_remote_document_tree = {}
		local utils_mock
		local http_mock
		local utils_spy
		local http_spy

		before_each(function()
			utils_mock = mock(utils, true)
			utils_mock.create_file.returns(path .. "/Test Document.md")
			utils_mock.write_file.returns()
			utils_mock.read_file.returns("This is a test document.")
			utils_mock.get_last_modified_date_of_file.returns(lastLocalModified)
			utils_spy = busted.mock(utils)

			http_mock = mock(http, true)
			http_mock.post_document.returns()
			http_mock.get_document.returns(remote_document)

			http_spy = busted.spy.on(http, "post_document")

			_G.vim = {
				fn = {
					json_decode = function(content)
						local decoded, pos, err = json.decode(content)
						if err then
							error("Invalid JSON: " .. err)
						end
						return decoded
					end,
				},
			}
		end)

		after_each(function()
			_G.vim = nil
			utils_spy.create_file:clear()
			utils_spy.write_file:clear()
			utils_spy.read_file:clear()
			http_spy:revert()
		end)

		it("should create a new file if it does not exist", function()
			utils_mock.file_exists.returns(false)

			local date1, date2 = sync.save_document(
				document,
				path,
				lastRemoteModifiedTable,
				lastSyncedTable,
				access_token,
				api_url,
				dummy_remote_document_tree
			)

			busted.assert.spy(utils_spy.create_file).was.called_with(path .. "/" .. file_name)
			busted.assert.spy(utils_spy.write_file).was.called_with(path .. "/" .. file_name, documentContent)
			assert.are.equal(date1, lastRemoteModified)
			assert.are.equal(date2, lastLocalModified)
			busted.assert.spy(http_spy).was_not_called()
		end)

		it("should update the remote document if only local file was modified", function()
			utils_mock.file_exists.returns(true)

			local date1, date2 =
				sync.save_document(document, path, lastRemoteModifiedTable, lastSyncedTable, access_token, api_url)

			assert.are.equal(date1, lastRemoteModified)
			assert.are.equal(date2, lastLocalModified)
			busted.assert.spy(utils_spy.create_file).was.not_called()
			busted.assert.spy(utils_spy.write_file).was.not_called_with()
			busted.assert.spy(utils_spy.read_file).was.called_with(path .. "/" .. file_name)
			busted.assert.spy(http_spy).was_called_with(
				access_token,
				api_url,
				busted.match.is_same({
					document = {
						id = "doc1",
						title = "Test Document",
						content = "This is a test document.",
						lastModified = lastRemoteModified,
						recreateIndex = false,
					},
				})
			)
		end)

		it("should update the local file if only remote document was modified", function()
			utils_mock.file_exists.returns(true)
			utils_mock.get_last_modified_date_of_file.returns(lastSynced)

			local remoteModifiedDocument = "2023-09-31T12:00:00Z"

			local date1, date2 = sync.save_document(
				document,
				path,
				{ doc1 = remoteModifiedDocument },
				lastSyncedTable,
				access_token,
				api_url,
				dummy_remote_document_tree
			)

			assert.are.equal(date1, lastRemoteModified)
			assert.are.equal(date2, remoteModifiedDocument)
			busted.assert.spy(utils_spy.create_file).was.called_with(path .. "/" .. file_name)
			busted.assert.spy(utils_spy.write_file).was.called_with(path .. "/" .. file_name, documentContent)
			busted.assert.spy(http_spy).was_not_called()
		end)

		it(
			"should write remote document to a separate file if both local file and remote document were modified",
			function()
				utils_mock.file_exists.returns(true)

				local remoteModifiedDocument = "2023-09-31T12:00:00Z"

				local date1, date2 = sync.save_document(
					document,
					path,
					{ doc1 = remoteModifiedDocument },
					lastSyncedTable,
					access_token,
					api_url,
					dummy_remote_document_tree
				)

				assert.are.equal(date1, lastRemoteModified)
				assert.are.equal(date2, lastLocalModified)
				busted.assert.spy(utils_spy.create_file).was.called_with(path .. "/" .. documentTitle .. "_remote.md")
				busted.assert.spy(utils_spy.write_file).was.called_with(path .. "/" .. file_name, documentContent)
				busted.assert.spy(http_spy).was_not_called()
			end
		)

		it("should return last modified dates if neither local nor remote files were modified", function()
			utils_mock.file_exists.returns(true)
			utils_mock.get_last_modified_date_of_file.returns(lastSynced)

			local date1, date2 = sync.save_document(
				document,
				path,
				lastRemoteModifiedTable,
				lastSyncedTable,
				access_token,
				api_url,
				dummy_remote_document_tree
			)

			assert.are.equal(date1, lastRemoteModified)
			assert.are.equal(date2, lastSynced)
			busted.assert.spy(utils_spy.create_file).was.not_called()
			busted.assert.spy(utils_spy.write_file).was.not_called()
			busted.assert.spy(http_spy).was_not_called()
		end)
	end)

	describe("sync", function()
		local id_token = "dummy_id_token"
		local access_token = "dummy_access_token"
		local refresh_token = "dummy_refresh_token"
		local clientId = "dummy_clientId"
		local api_url = "https://api.example.com"
		local domain = "example.com"
		local region = "us-west-1"
		local local_document_tree =
			'{"documents": [ {"id": "doc1", "name": "doc1", "children": [ {"id": "doc2", "name": "doc2"} ]}, {"id": "doc3", "name": "doc3", "children": [ {"id": "doc4", "name": "doc4"} ]} ]}'
		local remote_document_tree =
			'{"documents": [ {"id": "doc1", "name": "doc1", "children": [ {"id": "doc2", "name": "doc2"} ]}, {"id": "doc3", "name": "doc3", "children": [ {"id": "doc4", "name": "doc4"} ]} ]}'
		local lastRemoteModifiedTable = {
			doc1 = "2023-09-30T12:00:00Z",
			doc2 = "2023-09-30T12:00:00Z",
		}
		local lastSyncedTable = {
			doc1 = "2023-09-30T12:00:00Z",
			doc2 = "2023-09-30T12:00:00Z",
		}

		local utils_mock
		local http_mock
		local tokens_mock
		local utils_spy
		local tokens_spy
		local process_document_spy
		local original_process_document

		before_each(function()
			utils_mock = mock(utils, true)
			http_mock = mock(http, true)
			tokens_mock = mock(tokens, true)

			utils_mock.get_workspace_path.returns("/path/to/workspace")
			utils_mock.get_tree_cache_file.returns("/path/to/cache/file")
			utils_mock.read_file.returns(local_document_tree)
			http_mock.get_tree.returns(remote_document_tree)
			utils_mock.load_remote_last_modified_table.returns(lastRemoteModifiedTable)
			utils_mock.load_last_synced_table.returns(lastSyncedTable)
			utils_mock.get_all_files.returns({})

			tokens_mock.refresh_token.returns()
			tokens_mock.get_tokens.returns(id_token, access_token, refresh_token, clientId, api_url, domain, region)

			utils_spy = busted.mock(utils)
			tokens_spy = busted.mock(tokens)

			original_process_document = sync.process_document
			sync.process_document = function() end
			process_document_spy = busted.spy.on(sync, "process_document")

			_G.vim = {
				fn = {
					json_decode = function(content)
						local decoded, pos, err = json.decode(content)
						if err then
							error("Invalid JSON: " .. err)
						end
						return decoded
					end,
				},
			}
		end)

		after_each(function()
			process_document_spy:revert()
			sync.process_document = original_process_document
			_G.vim = nil
			tokens_spy.get_tokens:clear()
			tokens_spy.refresh_token:clear()
			utils_spy.get_all_files:clear()
			utils_spy.get_file_name_and_parent_dir:clear()
			utils_spy.traverse_directory:clear()
			utils_spy.save_file:clear()
			utils_spy.save_remote_last_modified_table:clear()
			utils_spy.save_last_synced_table:clear()
		end)

		it("should sync documents correctly", function()
			sync.sync()
			busted.assert.spy(process_document_spy).was_called(2)
			busted.assert.spy(process_document_spy).was_called_with(
				{
					id = "doc1",
					name = "doc1",
					children = {
						{
							id = "doc2",
							name = "doc2",
						},
					},
				},
				nil,
				access_token,
				api_url,
				lastRemoteModifiedTable,
				lastSyncedTable,
				vim.fn.json_decode(remote_document_tree)
			)
			busted.assert.spy(process_document_spy).was_called_with(
				{
					id = "doc3",
					name = "doc3",
					children = {
						{
							id = "doc4",
							name = "doc4",
						},
					},
				},
				nil,
				access_token,
				api_url,
				lastRemoteModifiedTable,
				lastSyncedTable,
				vim.fn.json_decode(remote_document_tree)
			)
			busted.assert.spy(utils_spy.save_file).was_called_with("/path/to/cache/file", remote_document_tree)
			busted.assert.spy(utils_spy.save_remote_last_modified_table).was_called_with(lastRemoteModifiedTable)
			busted.assert.spy(utils_spy.save_last_synced_table).was_called_with(lastSyncedTable)
		end)

		it("should refresh token if unauthorized", function()
			http_mock.get_tree.returns('{ "error": "Unauthorized" }')
			sync.sync()
			busted.assert.spy(tokens_spy.get_tokens).was_called()
			busted.assert.spy(tokens_spy.refresh_token).was_called()
			-- was note called since mock can only be defined once and get_tree is called twice
			busted.assert.spy(process_document_spy).was_not_called()
		end)

		it("should handle newly created local documents", function()
			utils_mock.get_all_files.returns({
				"/path/to/doc1.md",
				"/path/to/doc1/doc2.md",
				"/path/to/doc3.md",
				"/path/to/doc3/doc4.md",
			})
			utils_mock.traverse_directory.returns()
			utils_mock.read_file.returns(
				'{"documents": [ {"id": "doc1", "name": "doc1", "children": [ {"id": "doc2", "name": "doc2"} ]}, {"id": "doc3", "name": "doc3", "children": [ {"id": "doc4", "name": "doc4"}, {"id": "doc5", "name": "doc5"} ]} ]}'
			)
			utils_mock.get_file_name_and_parent_dir.returns("doc4", "doc5")

			utils_mock.flatten_document_tree.returns({
				{
					id = "doc1",
					name = "doc1",
				},
				{
					id = "doc2",
					name = "doc2",
				},
				{
					id = "doc3",
					name = "doc3",
				},
				{
					id = "doc4",
					name = "doc4",
				},
			})
			utils_mock.create_node_map.returns({
				doc1 = {
					id = "doc1",
					name = "doc1",
				},
				doc2 = {
					id = "doc2",
					name = "doc2",
				},
				doc3 = {
					id = "doc3",
					name = "doc3",
				},
				doc4 = {
					id = "doc4",
					name = "doc4",
				},
			})

			sync.sync()

			busted.assert.spy(process_document_spy).was_called(2)
			busted.assert.spy(process_document_spy).was_called_with(
				{
					id = "doc1",
					name = "doc1",
					children = {
						{
							id = "doc2",
							name = "doc2",
						},
					},
				},
				nil,
				access_token,
				api_url,
				lastRemoteModifiedTable,
				lastSyncedTable,
				vim.fn.json_decode(remote_document_tree)
			)
			busted.assert.spy(process_document_spy).was_called_with(
				{
					id = "doc3",
					name = "doc3",
					children = {
						{
							id = "doc4",
							name = "doc4",
						},
					},
				},
				nil,
				access_token,
				api_url,
				lastRemoteModifiedTable,
				lastSyncedTable,
				vim.fn.json_decode(remote_document_tree)
			)
		end)
	end)

	describe("create_document_space", function()
		local documentPath = "path/to/doc1"
		local access_token = "dummy_access_token"
		local apiUrl = "https://api.example.com"
		local lastRemoteModifiedTable = {}
		local lastSyncedTable = {}
		local document =
			'{"id": "doc1", "title": "Test Document", "content": "This is a test document.", "lastModified": "2023-10-01T12:00:00Z"}'
		local workspace_path = "/workspace"
		local dummy_document_tree = {}

		local utils_mock
		local http_mock
		local utils_spy
		local http_spy
		local original_save_document
		local save_document_spy

		before_each(function()
			utils_mock = mock(utils, true)
			http_mock = mock(http, true)
			utils_spy = busted.mock(utils)
			http_spy = busted.mock(http)

			utils_mock.get_workspace_path.returns(workspace_path)
			utils_mock.create_directory_if_not_exists.returns()
			http_mock.get_document.returns(documentContent)
			original_save_document = sync.save_document
			sync.save_document = function() end
			save_document_spy = busted.spy.on(sync, "save_document")
		end)

		after_each(function()
			utils_spy.get_workspace_path:clear()
			http_spy.get_document:clear()
			sync.save_document = original_save_document
			save_document_spy:revert()
		end)

		it("should create document space and save document", function()
			sync.create_document_space(
				document,
				documentPath,
				access_token,
				apiUrl,
				lastRemoteModifiedTable,
				lastSyncedTable,
				dummy_document_tree
			)

			local expected_path = workspace_path .. "/" .. documentPath
			busted.assert.spy(utils_spy.create_directory_if_not_exists).was_called_with(expected_path)
			busted.assert.spy(save_document_spy).was_called_with(
				document,
				expected_path,
				lastRemoteModifiedTable,
				lastSyncedTable,
				access_token,
				apiUrl,
				dummy_document_tree
			)
		end)
	end)

	describe("process_document", function()
		local document = {
			id = "doc1",
			name = "Test Document",
			children = {
				{
					id = "child_doc1",
					name = "Child Document 1",
				},
				{
					id = "child_doc2",
					name = "Child Document 2",
				},
			},
		}
		local parent_name = nil
		local access_token = "dummy_access_token"
		local api_url = "https://api.example.com"
		local lastRemoteModifiedTable = {}
		local lastSyncedTable = {}
		local dummy_document_tree = {}

		local original_create_document_space
		local process_document_spy
		local create_document_space_spy

		before_each(function()
			process_document_spy = busted.spy.on(sync, "process_document")
			original_create_document_space = sync.create_document_space
			sync.create_document_space = function() end
			create_document_space_spy = busted.spy.on(sync, "create_document_space")
		end)

		after_each(function()
			process_document_spy:revert()
			sync.create_document_space = original_create_document_space
			create_document_space_spy:revert()
		end)

		it("should process a document and its children", function()
			sync.process_document(
				document,
				parent_name,
				access_token,
				api_url,
				lastRemoteModifiedTable,
				lastSyncedTable,
				dummy_document_tree
			)

			busted.assert.spy(create_document_space_spy).was_called(3)
			busted.assert.spy(process_document_spy).was_called(3)

			busted.assert.spy(create_document_space_spy).was_called_with(
				document,
				document.name,
				access_token,
				api_url,
				lastRemoteModifiedTable,
				lastSyncedTable,
				dummy_document_tree
			)

			busted.assert.spy(create_document_space_spy).was_called_with(
				document.children[1],
				document.name .. "/" .. document.children[1].name,
				access_token,
				api_url,
				lastRemoteModifiedTable,
				lastSyncedTable,
				dummy_document_tree
			)

			busted.assert.spy(create_document_space_spy).was_called_with(
				document.children[2],
				document.name .. "/" .. document.children[2].name,
				access_token,
				api_url,
				lastRemoteModifiedTable,
				lastSyncedTable,
				dummy_document_tree
			)

			busted.assert.spy(process_document_spy).was_called_with(
				document.children[1],
				document.name,
				access_token,
				api_url,
				lastRemoteModifiedTable,
				lastSyncedTable,
				dummy_document_tree
			)

			busted.assert.spy(process_document_spy).was_called_with(
				document.children[2],
				document.name,
				access_token,
				api_url,
				lastRemoteModifiedTable,
				lastSyncedTable,
				dummy_document_tree
			)
		end)

		it("should process a document without children", function()
			local single_document = {
				id = "doc2",
				name = "Single Document",
			}

			sync.process_document(
				single_document,
				parent_name,
				access_token,
				api_url,
				lastRemoteModifiedTable,
				lastSyncedTable,
				dummy_document_tree
			)

			busted.assert.spy(create_document_space_spy).was_called(1)
			busted.assert.spy(process_document_spy).was_called(1)
			busted.assert.spy(create_document_space_spy).was_called_with(
				single_document,
				single_document.name,
				access_token,
				api_url,
				lastRemoteModifiedTable,
				lastSyncedTable,
				dummy_document_tree
			)
		end)
	end)
end)
