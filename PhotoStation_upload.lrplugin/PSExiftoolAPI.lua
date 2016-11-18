--[[----------------------------------------------------------------------------

PSExiftoolAPI.lua
Exiftool API for Lightroom Photo StatLr
Copyright(c) 2015, Martin Messmer

exports:
	- open
	- close
	
	- doExifTranslations
	- queryLrFaceRegionList
	- setLrFaceRegionList
	
Copyright(c) 2015, Martin Messmer

This file is part of Photo StatLr - Lightroom plugin.

Photo StatLr is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Photo StatLr is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Photo StatLr.  If not, see <http://www.gnu.org/licenses/>.

Photo StatLr uses the following free software to do its job:
	- convert.exe,			see: http://www.imagemagick.org/
	- ffmpeg.exe, 			see: https://www.ffmpeg.org/
	- qt-faststart.exe, 	see: http://multimedia.cx/eggs/improving-qt-faststart/
	- exiftool.exe			see: http://www.sno.phy.queensu.ca/~phil/exiftool/
]]
--------------------------------------------------------------------------------

-- Lightroom API
--local LrApplication 	= import 'LrApplication'
local LrDate 			= import 'LrDate'
local LrFileUtils 		= import 'LrFileUtils'
local LrPathUtils 		= import 'LrPathUtils'
local LrPrefs	 		= import 'LrPrefs'
local LrTasks 			= import 'LrTasks'
--local LrView 			= import 'LrView'

require "PSUtilities"

--============================================================================--

PSExiftoolAPI = {}


PSExiftoolAPI.downloadUrl = 'http://www.sno.phy.queensu.ca/~phil/exiftool/' 
PSExiftoolAPI.defaultInstallPath = iif(WIN_ENV, 
								'C:\\\Windows\\\exiftool.exe', 
								'/usr/local/bin/exiftool') 

--========================= locals =================================================================================

local noWhitespaceConversion = true	-- do not convert whitespaces to \n 
local etConfigFile = LrPathUtils.child(_PLUGIN.path, 'PSExiftool.conf')

---------------------- sendCmd ----------------------------------------------------------------------
-- function sendCmd(h, cmd, noWsConv)
-- send a command to exiftool listener by appending the command to the commandFile
local function sendCmd(h, cmd, noWsConv)
	-- all commands/parameters/options have to seperated by \n, therefore substitute whitespaces by \n 
	-- terminate command with \n 
	local cmdlines = iif(noWsConv, cmd .. "\n", string.gsub(cmd,"%s", "\n") .. "\n")
	writeLogfile(4, "sendCmd:\n" .. cmdlines)
	
	local cmdFile = io.open(h.etCommandFile, "a")
	if not cmdFile then return false end
	
	cmdFile:write(cmdlines)
	io.close(cmdFile)
	return true;
end

---------------------- executeCmds ----------------------------------------------------------------------

-- function executeCmds(h)
-- send a execute command to exiftool listener by appending the command to the commandFile
-- wait for the corresponding result
local function executeCmds(h)
	h.cmdNumber = h.cmdNumber + 1
	
	if not sendCmd(h, string.format("-execute%04d\n", h.cmdNumber)) then
		return nil
	end
	
	-- wait for exiftool to acknowledge the command
	local cmdResult = nil
	local startTime = LrDate.currentTime()
	local now = startTime
	local expectedResult = iif(h.cmdNumber == 1, 
								string.format(					"(.*){ready%04d}",	  			    h.cmdNumber),
								string.format("{ready%04d}[\r\n]+(.*){ready%04d}", h.cmdNumber - 1, h.cmdNumber))
								
	
	while not cmdResult  and (now < (startTime + 10)) do
		LrTasks.yield()
		if LrFileUtils.exists(h.etLogFile) and LrFileUtils.isReadable(h.etLogFile) then 
			local resultStrings
--			resultStrings = LrFileUtils.readFile(h.etLogFile) -- won't work, because file is still opened by exiftool
			local logfile = io.input (h.etLogFile)
			resultStrings = logfile:read("*a")
			io.close(logfile)
			if resultStrings then
--				writeLogfile(4, "executeCmds(): got response file contents:\n" .. resultStrings .. "\n")
				cmdResult = string.match(resultStrings, expectedResult) 
			end
		end
		now = LrDate.currentTime()
	end
	writeLogfile(3, string.format("executeCmds(%s, cmd %d) took %d secs, got:\n%s\n", h.etLogFile, h.cmdNumber, now - startTime, ifnil(cmdResult, '<Nil>', cmdResult)))
	return cmdResult 
end

---------------------- parseResponse ----------------------------------------------------------------

-- function parseResponse(photoFilename, tag, sep)
-- parse an exiftool response for a given tag
-- 		response	- the query response
-- syntax of response is:
--		<tag>		: <value>{;<value>}
local function parseResponse(response, tag, sep)
	if (not response) then return nil end
	
	local value = string.match(response, tag .. "%s+:%s+([^\r\n]+)")
		
	if sep then
		-- if separator given: return a table of values
		writeTableLogfile(4, tag, split(value, sep))
		return split(value, sep)
	end	

	writeLogfile(4, string.format("tag: %s --> value: %s\n", tag, value))
	return value
end 

---------------------- open -------------------------------------------------------------------------

-- function PSExiftoolAPI.open(exportParams)
-- Start exiftool listener in background: one for each export/publish thread
function PSExiftoolAPI.open(exportParams)
	local prefs = LrPrefs.prefsForPlugin()
	local h = {} -- the handle
	
	h.exiftool = prefs.exiftoolprog
	if not LrFileUtils.exists(h.exiftool) then 
		writeLogfile(1, "PSExiftoolAPI.open: Cannot start exifTool Listener: " .. h.exiftool .. " not found!\n")
		return false 
	end
	
	-- the commandFile and logFile must be unique for each exiftool listener
	h.etCommandFile = LrPathUtils.child(tmpdir, "ExiftoolCmds-" .. tostring(LrDate.currentTime()) .. ".txt")
	h.etLogFile = LrPathUtils.replaceExtension(h.etCommandFile, "log")
	h.etErrLogFile = LrPathUtils.replaceExtension(h.etCommandFile, "error.log")

	-- open and truncate commands file
	local cmdFile = io.open(h.etCommandFile, "w")
	io.close (cmdFile)

	
	LrTasks.startAsyncTask ( function()
			-- Start exiftool in listen mode
			-- when exiftool was stopped, clean up the commandFile and logFile
        	
        	local cmdline = cmdlineQuote() .. 
        					'"' .. h.exiftool .. '" ' ..
        					'-config "' .. etConfigFile .. '" ' ..
        					'-stay_open True ' .. 
        					'-@ "' .. h.etCommandFile .. '" ' ..
        					' -common_args -charset filename=UTF8 -overwrite_original -fast2 -m ' ..
--        					' -common_args -charset filename=UTF8 -overwrite_original -fast2 -n -m ' ..
        					'> "'  .. h.etLogFile .. 	'" ' ..
        					'2> "' .. h.etErrLogFile .. '"' .. 
        					cmdlineQuote()
        	local retcode
        	
        	-- store all pre-configured translations 
			local i = 0
			h.exifXlat = {}
			if exportParams.exifXlatFaceRegions then
				i = i + 1 
				h.exifXlat[i] = '-RegionInfoMp<MyRegionMp'
			end
			if exportParams.exifXlatRating then
				i = i + 1 
				h.exifXlat[i] = '-XMP:Subject+<MyRatingSubject'
			end

        	writeLogfile(2, string.format("exiftool Listener(%s): starting ...\n", cmdline))
        	h.cmdNumber = 0
        	local exitStatus = LrTasks.execute(cmdline)
        	if exitStatus > 0 then
        		writeLogfile(1, string.format("exiftool Listener(%s): terminated with error %s!\n", h.etCommandFile, tostring(exitStatus)))
        		retcode = false
        	else
        		writeLogfile(2, string.format("exiftool Listener(%s): terminated.\n", h.etCommandFile))
        		retcode = true
        	end
        
        	LrFileUtils.delete(h.etCommandFile)
        	LrFileUtils.delete(h.etLogFile)
        	LrFileUtils.delete(h.etErrLogFile)
        	
        	return retcode
        end 
	)	
	
	return h
end

---------------------- close -------------------------------------------------------------------------

-- function PSExiftoolAPI.close(h)
-- Stop exiftool listener by sending a terminate command to its commandFile
function PSExiftoolAPI.close(h)
	if not h then return false end
	
	writeLogfile(4, "PSExiftoolAPI.close: terminating exiftool.\n")
	sendCmd(h, "-stay_open False")
	
	return true
end

---------------------- doExifTranslations -------------------------------------------------------------
-- function PSExiftoolAPI.doExifTranslations(h, photoFilename, additionalCmd)
-- do all configured exif adjustments
function PSExiftoolAPI.doExifTranslations(h, photoFilename, additionalCmd)
	if not h then return false end
	
	------------- add all pre-configured translations ------------------
	for i=1, #h.exifXlat do
		if not sendCmd(h, h.exifXlat[i]) then return false end
	end
	------------- add additional translations ------------------
	if (additionalCmd and not sendCmd(h, additionalCmd))
	
	--------------- write filename to processing queue -----------------
	or not sendCmd(h, photoFilename, noWhitespaceConversion)
	or not executeCmds(h) then
		return false
	end

	return true
end

----------------------------------------------------------------------------------
-- function queryLrFaceRegionList(h, photoFilename)
-- query <mwg-rs:RegionList> elements: Picasa and Lr store detected face regions here
function PSExiftoolAPI.queryLrFaceRegionList(h, photoFilename)

	-- if photo is RAW then get XMP info from sidecar file where Lr puts it
	if PSLrUtilities.isRAW(photoFilename) then
		photoFilename = LrPathUtils.replaceExtension(photoFilename, 'xmp')
	end

	if not sendCmd(h, "-ImageWidth -ImageHeight -Orientation -HasCrop -CropTop -CropLeft -CropBottom -CropRight -CropAngle -XMP-mwg-rs:RegionAreaH -XMP-mwg-rs:RegionAreaW -XMP-mwg-rs:RegionAreaX -XMP-mwg-rs:RegionAreaY ".. 
					  "-XMP-mwg-rs:RegionName -XMP-mwg-rs:RegionType -XMP-mwg-rs:RegionRotation")
	or not sendCmd(h, photoFilename, noWhitespaceConversion)
	then
		return nil
	end  

	local queryResults = executeCmds(h) 

	if not queryResults then
		writeLogfile(3, "PSExiftoolAPI.queryLrFaceRegionList: execute query data failed\n")
		return nil
	end
	
	-- Face Region translations ---------
	local foundFaceRegions = false
	local personTags = {}
	local photoDimension = {}
	local sep = ', '
	
	photoDimension.width 	= parseResponse(queryResults, 'Image Width')
	photoDimension.height 	= parseResponse(queryResults, 'Image Height')
	photoDimension.orient 	= parseResponse(queryResults, 'Orientation')
	photoDimension.hasCrop 	= parseResponse(queryResults, 'Has Crop')
	photoDimension.cropTop 	= parseResponse(queryResults, 'Crop Top')
	photoDimension.cropLeft	= parseResponse(queryResults, 'Crop Left')
	photoDimension.cropBottom 	= parseResponse(queryResults, 'Crop Bottom')
	photoDimension.cropRight = parseResponse(queryResults, 'Crop Right')
	local personTagHs 		= parseResponse(queryResults, 'Region Area H', sep)	
	local personTagWs 		= parseResponse(queryResults, 'Region Area W', sep)	
	local personTagXs 		= parseResponse(queryResults, 'Region Area X', sep)	
	local personTagYs 		= parseResponse(queryResults, 'Region Area Y', sep)	
	local personTagTypes	= parseResponse(queryResults, 'Region Type', sep)
	local personTagNames	= parseResponse(queryResults, 'Region Name', sep)		
	local personTagRotations= parseResponse(queryResults, 'Region Rotation', sep)		

	if personTagHs and personTagWs and personTagXs and personTagYs then
		for i = 1, #personTagHs do
			if not personTagTypes or ifnil(personTagTypes[i], 'Face') == 'Face' then
				foundFaceRegions = true
				local personTag = {}
				
				personTag.xCenter 	= personTagXs[i]  
				personTag.yCenter 	= personTagYs[i]
				personTag.width 	= personTagWs[i]
				personTag.height 	= personTagHs[i]
				personTag.rotation 	= personTagRotations[i]
				if personTagNames then personTag.name = personTagNames[i] end
				
				personTags[i] = personTag 
				
				writeLogfile(3, string.format("PSExiftoolAPI.queryLrFaceRegionList: found %s %f, %f, %f, %f rot %f\n", 
												personTags[i].name,
												personTags[i].xCenter,
												personTags[i].yCenter,
												personTags[i].width,
												personTags[i].height,	
												personTags[i].rotation	
											))
			else
				writeLogfile(3, "PSExiftoolAPI.queryLrFaceRegionList: found non-face area: " .. personTagTypes[i] .. "\n")
			end						
		end
	end
	
	return personTags, photoDimension
end

----------------------------------------------------------------------------------
-- setLrFaceRegionList(h, srcPhoto, personTags, origPhotoDimension)
-- set <mwg-rs:RegionList> elements: Picasa and Lr store detected face regions here
function PSExiftoolAPI.setLrFaceRegionList(h, srcPhoto, personTags, origPhotoDimension)
	local photoFilename = srcPhoto:getRawMetadata('path')
	local personTagNames, personTagTypes, personTagRotations, personTagXs, personTagYs, personTagWs, personTagHs = '', '', '', '', '', '', ''
	local width, height, rotation, switchDim
	local separator = ';'
	
	-- if photo is RAW then put XMP info to sidecar file where Lr is expecting it
	if PSLrUtilities.isRAW(photoFilename) then
		photoFilename = LrPathUtils.replaceExtension(photoFilename, 'xmp')
	end
	
	if srcPhoto:getRawMetadata('isVirtualCopy') or srcPhoto:getRawMetadata('isCropped') then
		writeLogfile(3, string.format("setLrFaceRegionList for %s failed: %s/%s - not supported!\n",
							photoFilename,
							iif(srcPhoto:getRawMetadata('isVirtualCopy'), 'virtual copy', ''), 
							iif(srcPhoto:getRawMetadata('isCropped'), 'cropped photo', ''))) 
		return nil
	end
	
	-- adjust width and height if original photo was cropped 
	-- Not supported: Lr won't accept face regions for cropped photos
	--[[
	if origPhotoDimension.hasCrop == 'True' then
		origPhotoDimension.width 	= math.floor((origPhotoDimension.cropRight - origPhotoDimension.cropLeft) * origPhotoDimension.width)
		origPhotoDimension.height 	= math.floor((origPhotoDimension.cropBottom - origPhotoDimension.cropTop) * origPhotoDimension.height)
	end
	]]
	
	-- if orig photo is rotated, then region info (which was applied to the rotated photo) must be rotated also
	local appDimOrgW, appDimOrgH
	if string.find(origPhotoDimension.orient, 'Horizontal') then
		appDimOrgW = origPhotoDimension.width
		appDimOrgH = origPhotoDimension.height
		rotation	= string.format("%1.5f", 0)
	elseif string.find(origPhotoDimension.orient, '90') then
		appDimOrgW = origPhotoDimension.height
		appDimOrgH = origPhotoDimension.width
		rotation = string.format("-%1.5f", math.rad(90))
	elseif string.find(origPhotoDimension.orient, '180') then
		appDimOrgW = origPhotoDimension.width
		appDimOrgH = origPhotoDimension.height
		rotation	= string.format("%1.5f", math.rad(180))
	elseif string.find(origPhotoDimension.orient, '270') then
		appDimOrgW = origPhotoDimension.height
		appDimOrgH = origPhotoDimension.width
		rotation = string.format("%1.5f", math.rad(90))
	end

	for i = 1, #personTags do
		local xLr,  yLr,  wLr,  hLr
		local xOrg, yOrg, wOrg, hOrg
		local sep = iif(i == 1, '', separator)
		
		personTagNames = personTagNames .. sep .. personTags[i].name
		personTagTypes = personTagTypes .. sep .. 'Face'
		personTagRotations = personTagRotations .. sep .. rotation
		
		-- convert PS (left upper) coordinates to Lr (center) coordinates
		xLr = personTags[i].x + (personTags[i].width / 2)
		yLr = personTags[i].y + (personTags[i].height / 2)
		wLr = personTags[i].width
		hLr = personTags[i].height

		-- rotate Lr coordinates if orig photo is rotated
    	if string.find(origPhotoDimension.orient, 'Horizontal') then
    		xOrg = xLr
    		yOrg = yLr
    		wOrg = wLr
    		hOrg = hLr
    	elseif string.find(origPhotoDimension.orient, '90') then
    		xOrg = yLr
    		yOrg = 1 - xLr
    		wOrg = hLr
    		hOrg = wLr
    	elseif string.find(origPhotoDimension.orient, '180') then
    		xOrg = 1 - xLr
    		yOrg = 1 - yLr
    		wOrg = wLr
    		hOrg = hLr
    	elseif string.find(origPhotoDimension.orient, '270') then
    		xOrg = 1 - yLr
    		yOrg = xLr
    		wOrg = hLr
    		hOrg = wLr
    	end

		personTagXs = personTagXs .. sep .. string.format("%1.5f", xOrg)
		personTagYs = personTagYs .. sep .. string.format("%1.5f", yOrg)
		personTagWs = personTagWs .. sep .. string.format("%1.5f", wOrg)
		personTagHs = personTagHs .. sep .. string.format("%1.5f", hOrg)
	end

	if not 	sendCmd(h, "-sep ".. separator)	
-- HACK: Lr writes rotated dimensions as RegionAppliedToDimensions, but won't accepted anything other than the original phot dimensions
--	or not 	sendCmd(h, "-XMP-mwg-rs:RegionAppliedToDimensionsW=" .. tostring(appDimOrgW))
--	or not 	sendCmd(h, "-XMP-mwg-rs:RegionAppliedToDimensionsH=" .. tostring(appDimOrgH))
	or not 	sendCmd(h, "-XMP-mwg-rs:RegionAppliedToDimensionsW=" .. tostring(origPhotoDimension.width))
	or not 	sendCmd(h, "-XMP-mwg-rs:RegionAppliedToDimensionsH=" .. tostring(origPhotoDimension.height))
	or not 	sendCmd(h, "-XMP-mwg-rs:RegionAppliedToDimensionsUnit=pixel") 
	or not	sendCmd(h, 
					"-XMP-mwg-rs:RegionName="		.. personTagNames .. " " ..
					"-XMP-mwg-rs:RegionType="		.. personTagTypes .. " " ..
					"-XMP-mwg-rs:RegionRotation="	.. personTagRotations .. " " ..
					"-XMP-mwg-rs:RegionAreaX=" 		.. personTagXs .. " " ..
					"-XMP-mwg-rs:RegionAreaY="		.. personTagYs .. " " ..
					"-XMP-mwg-rs:RegionAreaW="		.. personTagWs .. " " ..
					"-XMP-mwg-rs:RegionAreaH="		.. personTagHs .. " "
				)
	or not sendCmd(h, photoFilename, noWhitespaceConversion)
	then
		writeLogfile(3, string.format("setLrFaceRegionList for %s failed: isRAW: %s, isRotated: %s, hasCrop: %s\n", 
					photoFilename, 
					iif(PSLrUtilities.isRAW(photoFilename), 'yes', 'no'),  
					ifnil(origPhotoDimension.hasCrop, 'False')))
		return nil
	end  

	return executeCmds(h)
end

