local sync = require("rocketnotes.sync")
local utils = require("rocketnotes.utils")
local tokens = require("rocketnotes.tokens")
local http = require("rocketnotes.http")
local json = require("dkjson")
local mock = require("luassert.mock")
local assert = require("luassert")
local busted = require("busted")

describe("rocketnotes.sync", function()
	describe("saveDocument", function()
		local file_name = "Test Document.md"
		local lastRemoteModified = "2023-09-30T12:00:00Z"
		local documentTitle = "Test Document"
		local documentContent = "This is a test document."
		local document = '{"id": "doc1", "title": "'
			.. documentTitle
			.. '", "content": "'
			.. documentContent
			.. '", "lastModified": "'
			.. lastRemoteModified
			.. '"}'
		local path = "/path/to/documents"
		local lastSynced = "2023-09-31T12:00:00Z"
		local lastRemoteModifiedTable = { doc1 = lastRemoteModified }
		local lastSyncedTable = { doc1 = lastSynced }
		local access_token = "dummy_access_token"
		local api_url = "https://api.example.com"
		local region = "us-west-1"
		local lastLocalModified = "2023-09-29T12:00:00Z"
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
			http_mock.postDocument.returns()

			http_spy = busted.spy.on(http, "postDocument")

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

			local date1, date2 = sync.saveDocument(
				document,
				path,
				lastRemoteModifiedTable,
				lastSyncedTable,
				access_token,
				api_url,
				region
			)

			assert.spy(utils_spy.create_file).was.called_with(path .. "/" .. file_name)
			assert.spy(utils_spy.write_file).was.called_with(path .. "/" .. file_name, documentContent)
			assert.are.equal(date1, lastRemoteModified)
			assert.are.equal(date2, lastLocalModified)
			busted.assert.spy(http_spy).was_not_called()
		end)

		it("should update the remote document if only local file was modified", function()
			utils_mock.file_exists.returns(true)

			local date1, date2 = sync.saveDocument(
				document,
				path,
				lastRemoteModifiedTable,
				lastSyncedTable,
				access_token,
				api_url,
				region
			)

			assert.are.equal(date1, lastRemoteModified)
			assert.are.equal(date2, lastLocalModified)
			assert.spy(utils_spy.create_file).was.not_called()
			assert.spy(utils_spy.write_file).was.not_called_with()
			assert.spy(utils_spy.read_file).was.called_with(path .. "/" .. file_name)
			busted.assert.spy(http_spy).was_called_with(
				access_token,
				api_url,
				region,
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

			local date1, date2 = sync.saveDocument(
				document,
				path,
				{ doc1 = remoteModifiedDocument },
				lastSyncedTable,
				access_token,
				api_url,
				region
			)

			assert.are.equal(date1, lastRemoteModified)
			assert.are.equal(date2, remoteModifiedDocument)
			assert.spy(utils_spy.create_file).was.called_with(path .. "/" .. file_name)
			assert.spy(utils_spy.write_file).was.called_with(path .. "/" .. file_name, documentContent)
			busted.assert.spy(http_spy).was_not_called()
		end)

		it(
			"should write remote document to a separate file if both local file and remote document were modified",
			function()
				utils_mock.file_exists.returns(true)

				local remoteModifiedDocument = "2023-09-31T12:00:00Z"

				local date1, date2 = sync.saveDocument(
					document,
					path,
					{ doc1 = remoteModifiedDocument },
					lastSyncedTable,
					access_token,
					api_url,
					region
				)

				assert.are.equal(date1, lastRemoteModified)
				assert.are.equal(date2, lastLocalModified)
				assert.spy(utils_spy.create_file).was.called_with(path .. "/" .. documentTitle .. "_remote.md")
				assert.spy(utils_spy.write_file).was.called_with(path .. "/" .. file_name, documentContent)
				busted.assert.spy(http_spy).was_not_called()
			end
		)

		it("should return last modified dates if neither local nor remote files were modified", function()
			utils_mock.file_exists.returns(true)
			utils_mock.get_last_modified_date_of_file.returns(lastSynced)

			local date1, date2 = sync.saveDocument(
				document,
				path,
				lastRemoteModifiedTable,
				lastSyncedTable,
				access_token,
				api_url,
				region
			)

			assert.are.equal(date1, lastRemoteModified)
			assert.are.equal(date2, lastSynced)
			assert.spy(utils_spy.create_file).was.not_called()
			assert.spy(utils_spy.write_file).was.not_called()
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
			http_mock.getTree.returns(remote_document_tree)
			utils_mock.loadRemoteLastModifiedTable.returns(lastRemoteModifiedTable)
			utils_mock.loadLastSyncedTable.returns(lastSyncedTable)
			utils_mock.getAllFiles.returns({})

			tokens_mock.refresh_token.returns()
			tokens_mock.get_tokens.returns(id_token, access_token, refresh_token, clientId, api_url, domain, region)

			utils_spy = busted.mock(utils)
			tokens_spy = busted.mock(tokens)

			original_process_document = sync.process_document
			sync.process_document = function()
				return
			end
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
			sync.process_document = original_process_document
			process_document_spy:revert()
			_G.vim = nil
		end)

		it("should sync documents correctly", function()
			sync.sync()
			busted.assert.spy(process_document_spy).was_called(2)
			busted.assert.spy(process_document_spy).was_called_with({
				id = "doc1",
				name = "doc1",
				children = {
					{
						id = "doc2",
						name = "doc2",
					},
				},
			}, nil, access_token, api_url, region, lastRemoteModifiedTable, lastSyncedTable)
			busted.assert.spy(process_document_spy).was_called_with({
				id = "doc3",
				name = "doc3",
				children = {
					{
						id = "doc4",
						name = "doc4",
					},
				},
			}, nil, access_token, api_url, region, lastRemoteModifiedTable, lastSyncedTable)
		end)

		it("should refresh token if unauthorized", function()
			http.getTree.returns('{ "error": "Unauthorized" }')
			sync.sync()
			busted.assert.spy(tokens_spy.get_tokens).was_called()
			busted.assert.spy(tokens_spy.refresh_token).was_called()
			busted.assert.spy(process_document_spy).was_not_called()
		end)

		it("should handle newly created local documents", function()
			utils_mock.getAllFiles.returns({
				"/path/to/doc1.md",
				"/path/to/doc1/doc2.md",
				"/path/to/doc3.md",
				"/path/to/doc3/doc4.md",
			})
			utils_mock.traverseDirectory.returns()
			utils_mock.read_file.returns(
				'{"documents": [ {"id": "doc1", "name": "doc1", "children": [ {"id": "doc2", "name": "doc2"} ]}, {"id": "doc3", "name": "doc3", "children": [ {"id": "doc4", "name": "doc4"}, {"id": "doc5", "name": "doc5"} ]} ]}'
			)
			utils_mock.getFileNameAndParentDir.returns("doc4", "doc5")

			utils_mock.flattenDocumentTree.returns({
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
			utils_mock.createNodeMap.returns({
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
			busted.assert.spy(process_document_spy).was_called_with({
				id = "doc1",
				name = "doc1",
				children = {
					{
						id = "doc2",
						name = "doc2",
					},
				},
			}, nil, access_token, api_url, region, lastRemoteModifiedTable, lastSyncedTable)
			busted.assert.spy(utils_spy.getAllFiles).was_called_with("/path/to/workspace")
			busted.assert.spy(utils_spy.getFileNameAndParentDir).was_called_with("/path/to/doc1.md")
			busted.assert.spy(utils_spy.traverseDirectory).was_called(1)
		end)
	end)
end)
