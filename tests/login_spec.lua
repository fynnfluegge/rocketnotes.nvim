local login = require("rocketnotes.login")
local tokens = require("rocketnotes.tokens")
local busted = require("busted")
local mock = require("luassert.mock")
local json = require("dkjson")

local response_file_path = "/tmp/cognito_login_response.json"

describe("login", function()
	local original_os_execute
	local original_vim_fn_input
	local original_vim_fn_inputsecret
	local tokens_spy
	local base64_token =
		"ewogICAgImNsaWVudElkIjogImNsaWVudF9pZF92YWx1ZSIsCiAgICAiYXBpVXJsIjogImFwaV91cmxfdmFsdWUiLAogICAgImRvbWFpbiI6ICJkb21haW5fdmFsdWUiLAogICAgInJlZ2lvbiI6ICJyZWdpb25fdmFsdWUiCn0K"

	before_each(function()
		original_os_execute = os.execute
		os.execute = function(cmd)
			return 0
		end

		_G.vim = {
			fn = {
				input = function(prompt)
					return base64_token
				end,
			},
		}

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

		original_vim_fn_input = vim.fn.input
		vim.fn.input = function(prompt)
			return base64_token
		end

		original_vim_fn_inputsecret = vim.fn.inputsecret
		vim.fn.inputsecret = function(prompt)
			return "mock_secret"
		end

		original_vim_fn_decode = vim.fn.json_decode
		vim.fn.json_decode = function(content)
			return json.decode(content)
		end

		local tokens_mock = mock(tokens, true)
		tokens_mock.update_tokens_from_username_and_password.returns()

		tokens_spy = busted.mock(tokens)
	end)

	after_each(function()
		os.execute = original_os_execute
		vim.fn.input = original_vim_fn_input
		vim.fn.inputsecret = original_vim_fn_inputsecret
		vim.fn.decode = original_vim_fn_decode
		os.remove(response_file_path)
		tokens_spy.update_tokens_from_username_and_password:clear()
	end)

	it("should login successfully", function()
		login.login()
		busted.assert
			.spy(tokens_spy.update_tokens_from_username_and_password)
			.was_called_with("client_id_value", "region_value", "api_url_value", "domain_value", base64_token, "mock_secret")
	end)

	it("should handle incorrect username or password", function()
		login.login()
		busted.assert
			.spy(tokens_spy.update_tokens_from_username_and_password)
			.was_called_with("client_id_value", "region_value", "api_url_value", "domain_value", base64_token, "mock_secret")
	end)
end)
