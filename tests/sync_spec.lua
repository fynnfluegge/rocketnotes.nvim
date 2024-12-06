local sync = require("rocketnotes.sync")
local utils = require("rocketnotes.utils")
local http = require("rocketnotes.http")
local json = require("dkjson")
local mock = require("luassert.mock")
local assert = require("luassert")
local busted = require("busted")

describe("rocketnotes.sync", function()
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

	before_each(function()
		utils_mock = mock(utils, true)
		utils_mock.create_file.returns(path .. "/Test Document.md")
		utils_mock.write_file.returns()
		utils_mock.read_file.returns("This is a test document.")
		utils_mock.get_last_modified_date_of_file.returns(lastLocalModified)

		http_mock = mock(http, true)
		http_mock.postDocument.returns()

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
	end)

	it("should create a new file if it does not exist", function()
		utils_mock.file_exists.returns(false)
		local utils_spy = busted.mock(utils)
		local http_spy = busted.spy.on(http, "postDocument")

		local date1, date2 =
			sync.saveDocument(document, path, lastRemoteModifiedTable, lastSyncedTable, access_token, api_url, region)

		assert.spy(utils_spy.create_file).was.called_with(path .. "/" .. file_name)
		assert.spy(utils_spy.write_file).was.called_with(path .. "/" .. file_name, documentContent)
		assert.are.equal(date1, lastRemoteModified)
		assert.are.equal(date2, lastLocalModified)
		busted.assert.spy(http_spy).was_not_called()
		http_spy:revert()
	end)

	it("should update the remote document if only local file was modified", function()
		utils_mock.file_exists.returns(true)
		local utils_spy = busted.mock(utils)
		local http_spy = busted.spy.on(http, "postDocument")

		local date1, date2 =
			sync.saveDocument(document, path, lastRemoteModifiedTable, lastSyncedTable, access_token, api_url, region)

		assert.are.equal(date1, lastRemoteModified)
		assert.are.equal(date2, lastLocalModified)
		assert.spy(utils_spy.create_file).was.called_with(path .. "/" .. file_name)
		assert.spy(utils_spy.write_file).was.called_with(path .. "/" .. file_name, documentContent)
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
		http_spy:revert()
	end)

	it("should update the local file if only remote document was modified", function()
		utils_mock.file_exists.returns(true)
		utils_mock.get_last_modified_date_of_file.returns(lastSynced)
		local utils_spy = busted.mock(utils)
		local http_spy = busted.spy.on(http, "postDocument")

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

		http_spy:revert()
	end)

	-- it("should do save document post request if only local file was modified", function()
	-- 	utils.file_exists.returns(true)
	-- 	utils.get_last_modified_date_of_file.returns("2023-09-30T12:00:00Z")
	-- 	utils.read_file.returns("This is a test document.")
	-- 	utils.create_file.returns(path .. "/Test Document.md")
	--
	-- 	local lastModified, localLastModified =
	-- 		sync.saveDocument(document, path, lastRemoteModifiedTable, lastSyncedTable, access_token, api_url, region)
	--
	-- 	assert.are.equal("2023-10-01T12:00:00Z", lastModified)
	-- 	assert.are.equal("2023-09-30T12:00:00Z", localLastModified)
	-- 	assert.stub(sync.postDocument).was.called()
	-- end)

	-- it("should return last modified dates if neither local nor remote files were modified", function()
	-- 	utils.file_exists.returns(true)
	-- 	utils.get_last_modified_date_of_file.returns("2023-09-30T12:00:00Z")
	-- 	utils.create_file.returns(path .. "/Test Document.md")
	--
	-- 	local lastModified, localLastModified =
	-- 		sync.saveDocument(document, path, lastRemoteModifiedTable, lastSyncedTable, access_token, api_url, region)
	--
	-- 	assert.are.equal("2023-10-01T12:00:00Z", lastModified)
	-- 	assert.are.equal("2023-09-30T12:00:00Z", localLastModified)
	-- end)
end)
