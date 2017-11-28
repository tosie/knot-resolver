-- check prerequisites
local supports_http = pcall(require, 'http') and pcall(require, 'http.request')
if not supports_http then
	pass('skipping http module test because its not installed')
	done()
end

-- load dependencies
if supports_http then
	local test_utils = require('test_utils')
	local request = require('http.request')
	local cqueues = require('cqueues')

	-- setup resolver
	modules = {
		http = {
			port = 0, -- Select random port
			cert = false,
		}
	}

	local server = http.servers[1]
	ok(server ~= nil, 'creates server instance')
	local _, host, port = server:localname()
	ok(host and port, 'binds to an interface')

	-- constructor for asynchronously executed functions
	local function asynchronous(cb)
		local cq = cqueues.new()
		cq:wrap(cb)
		event.socket(cq:pollfd(), function (ev)
			cq:step(0)
			if cq:empty() then
				event.cancel(ev)
			end
		end)
		return cq
	end

	-- helper for returning useful values to test on
	local function http_get(uri)
		local headers, stream = assert(request.new_from_uri(uri .. '/'):go())
		local body = assert(stream:get_body_as_string())
		return tonumber(headers:get(':status')), body, headers:get('content-type')
	end

	-- test whether http interface responds and binds
	local function test_builtin_pages()
		local code, body, mime
		local uri = string.format('http://%s:%d', host, port)
		-- simple static page
		code, body, mime = http_get(uri .. '/')
		same(code, 200, 'static page return 200 OK')
		ok(#body > 0, 'static page has non-empty body')
		same(mime, 'text/html', 'static page has text/html content type')
		-- non-existent page
		code = http_get(uri .. '/badpage')
		same(code, 404, 'non-existent page returns 404')
		-- /stats endpoint serves metrics
		code, body, mime = http_get(uri .. '/stats')
		same(code, 200, '/stats page return 200 OK')
		ok(#body > 0, '/stats page has non-empty body')
		same(mime, 'application/json', '/stats page has correct content type')
		-- /metrics serves metrics
		code, body, mime = http_get(uri .. '/metrics')
		same(code, 200, '/metrics page return 200 OK')
		ok(#body > 0, '/metrics page has non-empty body')
		same(mime, 'text/plain; version=0.0.4', '/metrics page has correct content type')
		-- /trace serves trace log for requests
		code, body, mime = http_get(uri .. '/trace/localhost/A')
		same(code, 200, '/trace page return 200 OK')
		ok(#body > 0, '/trace page has non-empty body')
		same(mime, 'text/plain', '/trace page has correct content type')
		-- /trace checks variables
		code = http_get(uri .. '/trace/localhost/BADTYPE')
		same(code, 400, '/trace checks type')
		code = http_get(uri .. '/trace/')
		same(code, 400, '/trace requires name')
	end

	-- plan tests
	local tests = {
		test_builtin_pages,
	}

	-- run tests asynchronously
	asynchronous(function ()
		for _, t in ipairs(tests) do
			test_utils.test(t)
		end
		done()
	end)
end