--[[----------------------------------------------------------------------------

Info.lua
Summary information for ftp_upload sample plug-in

--------------------------------------------------------------------------------

ADOBE SYSTEMS INCORPORATED
 Copyright 2007 Adobe Systems Incorporated
 All Rights Reserved.

NOTICE: Adobe permits you to use, modify, and distribute this file in accordance
with the terms of the Adobe license agreement accompanying it. If you have received
this file from a source other than Adobe, then your use, modification, or distribution
of it requires the prior written permission of Adobe.


------------------------------------------------------------------------------]]


return {
    LrSdkVersion = 5.0,
    LrSdkMinimumVersion = 2.0, -- minimum SDK version required by this plug-in

    LrToolkitIdentifier = 'co.uk.pavilionweb.lightroom.export.photoworkflow',
    LrPluginName = LOC "$$$/FTPUpload/PluginName=Photo Worflow Upload plugin",
    LrExportServiceProvider = {
        title = "Photo Workflow Upload",
        file = 'PWUploadExportServiceProvider.lua',
    },
    LrExportMenuItems = {
        { title = "Debug Script", file = "DebugScript.lua" }
    },
    VERSION = { major = 0, minor = 0, revision = 1, build = 0, },
}
