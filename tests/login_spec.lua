local login = require("rocketnotes.login")
local tokens = require("rocketnotes.tokens")
local busted = require("busted")
local assert = require("luassert")
local mock = require("luassert.mock")

local response_file_path = "/tmp/cognito_login_response.json"

describe("LoginModule", function()
	local original_os_execute
	local original_vim_fn_input
	local original_vim_fn_inputsecret
	local tokens_spy

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

		local tokens_mock = mock(tokens, true)
		tokens_mock.get_tokens.returns(
			"id_token",
			"access_token",
			"refresh_token",
			"clientId",
			"api_url",
			"domain",
			"region",
			"username",
			"password"
		)
		tokens_mock.save_tokens.returns()

		tokens_spy = busted.mock(tokens)
	end)

	after_each(function()
		os.execute = original_os_execute
		vim.fn.input = original_vim_fn_input
		vim.fn.inputsecret = original_vim_fn_inputsecret
		os.remove(response_file_path)
		tokens_spy.save_tokens:clear()
	end)

	it("should login successfully", function()
		local file = io.open(response_file_path, "w")
		file:write('{"id_token": "new_id_token", "access_token": "new_access_token" }')
		file:close()

		login.login()
		assert.spy(tokens_spy.save_tokens).was_called()
	end)

	it("should handle incorrect username or password", function()
		local file = io.open(response_file_path, "w")
		file:write('{"error": "NotAuthorizedException"}')
		file:close()

		login.login()
		assert.spy(tokens_spy.save_tokens).was_not_called()
	end)
end)
