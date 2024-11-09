local utils = require("rocketnotes.utils")

describe("flattenDocumentTree", function()
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

		local flat_list = utils.flattenDocumentTree(sample_tree)

		assert.are.same(expected_flat_list, flat_list)
	end)
end)
