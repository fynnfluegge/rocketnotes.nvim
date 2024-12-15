local utils = require("rocketnotes.utils")

describe("get_all_files", function()
	it("should return files with their immediate parent directory", function()
		-- Mock the io.popen function to simulate the output of the `find` command
		local originalPopen = io.popen
		io.popen = function()
			return {
				lines = function()
					local lines = {
						"/example_dir/file1.txt",
						"/example_dir/file2.md",
						"/example_dir/subdir/file3.lua",
						"/example_dir/subdir/nested/file4.py",
					}
					local i = 0
					return function()
						i = i + 1
						return lines[i]
					end
				end,
				close = function() end,
			}
		end

		-- Call the function with the mock data
		local result = utils.get_all_files("/example_dir")

		-- Restore the original io.popen function
		io.popen = originalPopen

		-- Validate the result
		assert.are.same({
			"/example_dir/file1.txt",
			"/example_dir/file2.md",
			"/example_dir/subdir/file3.lua",
			"/example_dir/subdir/nested/file4.py",
		}, result)

		local parent, file = utils.get_file_name_and_parent_dir(result[1])
		assert.are.same({ "example_dir", "file1" }, { parent, file })
	end)
end)

describe("flatten_document_tree", function()
	it("flattens a nested document tree", function()
		local sample_tree = {
			{
				id = "1",
				name = "Shortcuts",
				parent = "root",
				pinned = true,
				children = nil,
			},
			{
				id = "2",
				name = "Zsh",
				parent = "root",
				pinned = false,
				children = {
					{
						id = "3",
						name = "Shell Commands",
						parent = "2",
						pinned = false,
						children = nil,
					},
					{
						id = "4",
						name = "Alacritty",
						parent = "2",
						pinned = false,
						children = nil,
					},
					{
						id = "5",
						name = "Ranger",
						parent = "2",
						pinned = false,
						children = nil,
					},
					{
						id = "6",
						name = "Terminal tools",
						parent = "2",
						pinned = false,
						children = {
							{
								id = "7",
								name = "curl",
								parent = "6",
								pinned = false,
								children = {
									{
										id = "8",
										name = "test",
										parent = "7",
										pinned = false,
										children = nil,
									},
								},
							},
						},
					},
				},
			},
		}

		local expected_flat_list = {
			{ id = "1", name = "Shortcuts", parent = "root", pinned = true },
			{ id = "2", name = "Zsh", parent = "root", pinned = false },
			{ id = "3", name = "Shell Commands", parent = "2", pinned = false },
			{ id = "4", name = "Alacritty", parent = "2", pinned = false },
			{ id = "5", name = "Ranger", parent = "2", pinned = false },
			{ id = "6", name = "Terminal tools", parent = "2", pinned = false },
			{ id = "7", name = "curl", parent = "6", pinned = false },
			{ id = "8", name = "test", parent = "7", pinned = false },
		}

		local flat_list = utils.flatten_document_tree(sample_tree)

		assert.are.same(expected_flat_list, flat_list)
	end)
end)

describe("utils.decode_base64", function()
	it("should decode base64 encoded strings correctly", function()
		local encoded = "SGVsbG8gd29ybGQ="
		local decoded = utils.decode_base64(encoded)
		assert.are.equal("Hello world", decoded)
	end)

	it("should return an empty string for empty input", function()
		local encoded = ""
		local decoded = utils.decode_base64(encoded)
		assert.are.equal("", decoded)
	end)

	it("should handle invalid base64 input gracefully", function()
		local encoded = "invalid_base64"
		local decoded = utils.decode_base64(encoded)
		assert.are_not.equal(nil, decoded)
	end)
end)
