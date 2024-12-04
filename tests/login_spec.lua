local login = require("rocketnotes.login")
local tokens = require("rocketnotes.tokens")
local busted = require("busted")
local assert = require("luassert")

local response_file_path = "/tmp/cognito_login_response.json"

describe("LoginModule", function()
	local original_os_execute
	local original_vim_fn_input
	local original_vim_fn_inputsecret
	local original_tokens_get_tokens
	local original_tokens_save_tokens

	before_each(function()
		original_os_execute = os.execute
		os.execute = function(cmd)
			return 0
		end

		_G.vim = {
			fn = {
				input = function(prompt)
					return "mock_input"
				end,
			},
		}

		original_vim_fn_input = vim.fn.input
		vim.fn.input = function(prompt)
			return "mock_input"
		end

		original_vim_fn_inputsecret = vim.fn.inputsecret
		vim.fn.inputsecret = function(prompt)
			return "mock_secret"
		end

		-- Mock tokens.get_tokens
		original_tokens_get_tokens = tokens.get_tokens
		tokens.get_tokens = function()
			return "id_token",
				"access_token",
				"refresh_token",
				"clientId",
				"api_url",
				"domain",
				"region",
				"username",
				"password"
		end

		-- Mock tokens.save_tokens
		original_tokens_save_tokens = tokens.save_tokens
		tokens.save_tokens = function(
			id_token,
			access_token,
			refresh_token,
			clientId,
			apiUrl,
			domain,
			region,
			username,
			password
		)
			-- Do nothing
		end
	end)

	after_each(function()
		-- Restore original functions
		os.execute = original_os_execute
		vim.fn.input = original_vim_fn_input
		vim.fn.inputsecret = original_vim_fn_inputsecret
		tokens.get_tokens = original_tokens_get_tokens
		tokens.save_tokens = original_tokens_save_tokens
		os.remove(response_file_path)
	end)

	it("should login successfully", function()
		local file = io.open(response_file_path, "w")
		file:write('{"id_token": "new_id_token", "access_token": "new_access_token" }')
		file:close()

		local tokens_mock = busted.mock(tokens)
		login.login()
		assert.spy(tokens_mock.save_tokens).was_called()
	end)

	it("should handle incorrect username or password", function()
		local file = io.open(response_file_path, "w")
		file:write('{"error": "NotAuthorizedException"}')
		file:close()

		local tokens_mock = busted.mock(tokens)
		login.login()
		assert.spy(tokens_mock.save_tokens).was_not_called()
	end)
end)
