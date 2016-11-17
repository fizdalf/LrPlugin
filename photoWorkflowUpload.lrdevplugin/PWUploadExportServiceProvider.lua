--
-- Created by IntelliJ IDEA.
-- User: Fizdalf
-- Date: 28/10/2016
-- Time: 16:23
-- To change this template use File | Settings | File Templates.
--
local Require = require 'Require'.path("../debugscript.lrdevplugin")
local Debug = require 'Debug'.init()
require 'strict'


require 'PWUploadExportDialogSections'

local LrLogger = import 'LrLogger'

local myLogger = LrLogger('testLogger')
myLogger:enable("logfile")



return {
    hideSections = { 'exportLocation' },
    allowFileFormats = nil, -- nil equates to all available formats

    allowColorSpaces = nil, -- nil equates to all color spaces

    exportPresetFields = {},
    startDialog = Debug.showErrors(PWUploadExportDialogSections.startDialog),
    endDialog = Debug.showErrors(PWUploadExportDialogSections.endDialog),
    sectionsForBottomOfDialog = Debug.showErrors(PWUploadExportDialogSections.sectionsForBottomOfDialog),
    processRenderedPhotos = Debug.showErrors(PWUploadExportDialogSections.processRenderedPhotos),
}