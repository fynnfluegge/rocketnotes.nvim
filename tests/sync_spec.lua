local sync = require("rocketnotes.sync")
local utils = require("rocketnotes.utils")
local json = require("dkjson")
local mock = require("luassert.mock")
local assert = require("luassert")
local busted = require("busted")

describe("rocketnotes.sync", function()
	local lastRemoteModified = "2023-09-30T12:00:00Z"
	local document = '{"id": "doc1", "title": "Test Document", "content": "This is a test document.", "lastModified": "'
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

	before_each(function()
		utils_mock = mock(utils, true)
		utils_mock.create_file.returns(path .. "/Test Document.md")
		utils_mock.write_file.returns()
		utils_mock.get_last_modified_date_of_file.returns(lastLocalModified)

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
		local test = busted.mock(utils)

		local date1, date2 =
			sync.saveDocument(document, path, lastRemoteModifiedTable, lastSyncedTable, access_token, api_url, region)

		assert.spy(test.create_file).was.called_with(path .. "/Test Document.md")
		assert.spy(test.write_file).was.called_with(path .. "/Test Document.md", "This is a test document.")
		assert.are.equal(date1, lastRemoteModified)
		assert.are.equal(date2, lastLocalModified)
	end)

	-- it("should update the local file if only remote file was modified", function()
	-- 	utils.file_exists.returns(true)
	-- 	utils.get_last_modified_date_of_file.returns("2023-09-30T12:00:00Z")
	-- 	utils.create_file.returns(path .. "/Test Document.md")
	--
	-- 	local lastModified, localLastModified =
	-- 		sync.saveDocument(document, path, lastRemoteModifiedTable, lastSyncedTable, access_token, api_url, region)
	--
	-- 	assert.are.equal("2023-10-01T12:00:00Z", lastModified)
	-- 	assert.are.equal("2023-09-30T12:00:00Z", localLastModified)
	-- 	assert.stub(utils.create_file).was.called_with(path .. "/Test Document.md")
	-- 	assert.stub(utils.write_file).was.called_with(path .. "/Test Document.md", "This is a test document.")
	-- end)

	-- it("should save a second copy of the file if both local and remote files were modified", function()
	-- 	utils.file_exists.returns(true)
	-- 	utils.get_last_modified_date_of_file.returns("2023-09-29T12:00:00Z")
	-- 	utils.create_file.returns(path .. "/Test Document.md")
	--
	-- 	local lastModified, localLastModified =
	-- 		sync.saveDocument(document, path, lastRemoteModifiedTable, lastSyncedTable, access_token, api_url, region)
	--
	-- 	assert.are.equal("2023-10-01T12:00:00Z", lastModified)
	-- 	assert.are.equal("2023-09-29T12:00:00Z", localLastModified)
	-- 	assert.stub(utils.create_file).was.called_with(path .. "/Test Document_remote.md")
	-- 	assert.stub(utils.write_file).was.called_with(path .. "/Test Document_remote.md", "This is a test document.")
	-- end)

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
