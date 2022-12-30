plib.Require( 'chttp', true )

local ArgAssert = ArgAssert
local string = string

function string.IsURL( str )
	ArgAssert( str, 1, 'string' )
	return string.match( str, '^https?://.*' ) ~= nil
end

function http.IsSuccess( code )
	ArgAssert( code, 1, 'number' )
	return ((code > 199) and (code < 300)) or (code == 0)
end

function http.Encode( str )
	ArgAssert( str, 1, 'string' )
	return string.gsub(string.gsub(str, '[^%w _~%.%-]', function( char )
		return string.format( '%%%02X', string.byte( char ) )
	end), ' ', '+')
end

do
	local tonumber = tonumber
	function http.Decode( str )
		ArgAssert( str, 1, 'string' )
		return string.gsub(string.gsub( str, '+', ' ' ), '%%(%x%x)', function( c )
			return string.char( tonumber( c, 16 ) )
		end)
	end
end

function http.ParseQuery( str )
	ArgAssert( str, 1, 'string' )

	local query = {}
	for key, value in string.gmatch( str, '([^&=?]-)=([^&=?]+)' ) do
		query[ key ] = http.Decode( value )
	end

	return query
end

do
	local pairs = pairs
	function http.Query( tbl )
		ArgAssert( tbl, 1, 'table' )
		local out

		for key, value in pairs( tbl ) do
			out = (out and (out .. '&') or '') .. key .. '=' .. value
		end

		return '?' .. out
	end
end

do
	local format = '--%s\r\n%s\r\n%s\r\n--%s--\r\n'
	function http.PrepareUpload( content, filename )
		ArgAssert( content, 1, 'string' )
		ArgAssert( filename, 2, 'string' )

		local boundary = 'fboundary' .. math.random( 1, 100 )
		local header_bound = 'Content-Disposition: form-data; name=\'file\'; filename=\'' .. filename .. '\'\r\nContent-Type: application/octet-stream\r\n'
		local data = string.format( format, boundary, header_bound, content, boundary )

		return {
			{ 'Content-Length', #data },
			{ 'Content-Type', 'multipart/form-data; boundary=' .. boundary }
		}, data
	end
end

do

	local isfunction = isfunction
	local plib_Warn = plib.Warn
	local plib_Info = plib.Info
	local file_Open = file.Open
	local SysTime = SysTime

	function http.Download( url, filePath, onSuccess, onFailure, headers )
		ArgAssert( url, 1, 'string' )
		ArgAssert( filePath, 2, 'string' )
		plib_Info( 'File \'{0}\' is downloading...', filePath )

		http.Fetch(url, function( content, size, responseHeaders, code )
			if http.IsSuccess( code ) then
				if (size == 0) then
					plib_Warn( 'File [{0}] size is zero!', filePath )
					return
				end

				local stopwatch = SysTime()
				local fileClass = file_Open( filePath, 'rb', 'DATA' )
				if (fileClass) then
					fileClass:Write( body )
					fileClass:Close()

					plib_Info( 'Download completed successfully, file was saved as: \'data/{0}\' ({1} seconds)', filePath, string.format( '%.4f', SysTime() - stopwatch ) )

					if isfunction( onSuccess ) then
						onSuccess( body, responseHeaders, size, filePath )
					end

					return
				end

				plib_Warn( 'Downloading failed, file failed to open due to it not existing or being used by another process: \'data/{0}\'', filePath )
				return
			end

			plib_Warn( 'An error code \'{0}\' was received while downloading: \'{1}\'', code, filePath )
			if isfunction( onFailure ) then
				onFailure( 'Error code: ' .. code, filePath )
			end
		end,
		function( err )
			plib_Warn( 'An error occurred while trying to download \'{0}\':\n{1}', filePath, err )
			if isfunction( onFailure ) then
				onFailure( err, filePath )
			end
		end, headers, 120)
	end

	file.Download = http.Download
end