--
-- Created by IntelliJ IDEA.
-- User: Fizdalf
-- Date: 28/10/2016
-- Time: 16:30
-- To change this template use File | Settings | File Templates.
--
-- Lightroom SDK
local LrView = import 'LrView'
local LrDialogs = import 'LrDialogs'
local LrHttp = import 'LrHttp'
local LrErrors = import 'LrErrors'
local LrTasks = import 'LrTasks'
local LrBinding = import 'LrBinding'
local LrLogger = import 'LrLogger'
local LrPathUtils = import 'LrPathUtils'
local LrFileUtils = import 'LrFileUtils'
local LrFunctionContext = import 'LrFunctionContext'


local LrStringUtils = import 'LrStringUtils'

local myLogger = LrLogger('testLogger')
myLogger:enable("logfile")

require 'UserManager'
require 'Utils'

local JSON = require "JSON" -- one-time load of the routines

PWUploadExportDialogSections = {}

local function updateExportStatus(propertyTable)

    local message
    repeat
        if propertyTable.loggedInUser == nil then
            propertyTable.logBtnLbl = "Login"
            message = "Please Login to Continue"
            break;
        else
            propertyTable.logBtnLbl = "Logout"
        end

        if propertyTable.selectedClient == nil then
            message = "Please select a client"
            break;
        end

        if propertyTable.selectedUpload then
            if propertyTable.selectedUpload == 'session' then
                if not propertyTable.sessionIds then
                    message = "Please select a session"
                    break;
                end
            else
                if not propertyTable.orderIds then
                    message = "Please select an order"
                    break;
                end
            end
        else
            message = "Please select session or order"
        end
    until true
    if message then
        propertyTable.message = message
        propertyTable.hasError = true
        propertyTable.hasNoError = false
        propertyTable.LR_cantExportBecause = message
    else
        propertyTable.message = nil
        propertyTable.hasError = false
        propertyTable.hasNoError = true
        propertyTable.LR_cantExportBecause = nil
    end
end

local function checkLogin(propertyTable)
    if ((propertyTable.email ~= nil and propertyTable.email ~= '') and propertyTable.password ~= nil and propertyTable.password ~= '') then
        propertyTable.readyToLogin = true;
    else
        propertyTable.readyToLogin = false;
    end
end

local function checkSelectedClient(propertyTable)
    local selectedClientId = propertyTable.UserManager.getSelectedClientId()
    if (selectedClientId) then
        local intermediateTable = {}
        table.insert(intermediateTable, selectedClientId)
        propertyTable.clientIds = intermediateTable
        propertyTable.isInitialized = true;

        local selectedSessionId = propertyTable.UserManager.getSelectedSessionId()
        if (selectedSessionId) then
            propertyTable.selectedUpload = "session"
        end

        local selectedOrderId = propertyTable.UserManager.getSelectedOrderId()
        if (selectedOrderId) then
            print_to_log_table("..select orders ..cause we have an order id")
            propertyTable.selectedUpload = "order"
        end
    end
end

local function checkSelectedSession(propertyTable)
    local selectedSessionId = propertyTable.UserManager.getSelectedSessionId()
    if (selectedSessionId) then
        local intermediateTable = {}
        table.insert(intermediateTable, selectedSessionId)
        propertyTable.sessionIds = intermediateTable
        updateExportStatus(propertyTable)
    end
end

local function checkSelectedOrder(propertyTable)
    local selectedOrderId = propertyTable.UserManager.getSelectedOrderId()
    if (selectedOrderId) then
        print_to_log_table("we have an order id")
        local intermediateTable = {}
        table.insert(intermediateTable, selectedOrderId)
        propertyTable.orderIds = intermediateTable
        updateExportStatus(propertyTable)
    end
end

local function selectedClient(prop, key, value)
    local selectedClientId = prop.clientIds[1]
    local foundClient = prop.loggedInUser.findClient(selectedClientId)
    prop.selectedClient = foundClient
    prop.selectedUpload = ''
    prop.UserManager.setSelectedClientId(prop.clientIds[1])
    prop.selectedSession = nil
    prop.selectedOrder = nil
    if (prop.isInitialized) then
        myLogger:trace("resetting sessionID and OrderId")
        prop.UserManager.setSelectedSessionId(nil)
        prop.UserManager.setSelectedOrderId(nil)
    end
    updateExportStatus(prop)
end

local function selectedSession(prop, key, value)
    local selectedSessionId = prop.sessionIds[1]
    local foundSession = prop.selectedClient.findSession(selectedSessionId)
    prop.selectedSession = foundSession
    prop.UserManager.setSelectedSessionId(prop.sessionIds[1])
    updateExportStatus(prop)
end

local function selectedOrder(prop, key, value)
    local selectedOrderId = prop.orderIds[1]
    local foundOrder = prop.selectedClient.findOrder(selectedOrderId)
    prop.selectedOrder = foundOrder
    prop.UserManager.setSelectedOrderId(prop.orderIds[1])
    updateExportStatus(prop)
end

local function getClientUpdates(prop)
    if (prop.loggedInUser) then
        LrTasks.startAsyncTask(function()
            LrFunctionContext.callWithContext('function', function(context)
                local isDone = false
                local isUpdate
                local progressScope = LrDialogs.showModalProgressDialog({
                    title = 'Retrieving Clients ',
                    cannotCancel = false,
                    functionContext = context,
                })
                local updateCallBack = function(clientsToFetch, clientsFetched)
                    progressScope:setPortionComplete(clientsFetched, clientsToFetch)
                    local caption
                    if (isUpdate) then
                        caption = "Updating Clients: "
                    else
                        caption = "Fetching Clients: "
                    end
                    caption = caption .. clientsFetched .. "/" .. clientsToFetch
                    progressScope:setCaption(caption)
                end

                local doneCallback = function()
                    prop.clientsList = prop.loggedInUser.getClients(true)
                    prop.filteredClientsList = prop.clientsList
                    progressScope:done()
                    isDone = true
                end

                isUpdate = prop.loggedInUser.fetchClients(updateCallBack, doneCallback)
                while not isDone do
                    if (progressScope:isCanceled()) then
                        progressScope:cancel()
                        break
                    end
                    LrTasks.sleep(0)
                end
                checkSelectedClient(prop)
            end)
        end)
    end
end

local function getSessionUpdates(prop)
    if (prop.loggedInUser and prop.selectedClient) then
        LrTasks.startAsyncTask(function()
            LrFunctionContext.callWithContext('function', function(context)
                local isDone = false
                local isUpdate
                local progressScope = LrDialogs.showModalProgressDialog({
                    title = 'Retrieving Sessions ',
                    cannotCancel = false,
                    functionContext = context,
                })

                local updateCallBack = function(sessionsToFetch, sessionsFetched)
                    progressScope:setPortionComplete(sessionsFetched, sessionsToFetch)
                    local caption
                    if (isUpdate) then
                        caption = "Updating Sessions: "
                    else
                        caption = "Fetching Sessions: "
                    end
                    caption = caption .. sessionsFetched .. "/" .. sessionsToFetch
                    progressScope:setCaption(caption)
                end

                local doneCallback = function()
                    prop.sessionsList = prop.selectedClient.getAllSessions(true)
                    prop.filteredSessionsList = prop.sessionsList
                    progressScope:done()
                    isDone = true
                end

                isUpdate = prop.selectedClient.fetchSessions(prop.loggedInUser.getApiKey(), updateCallBack, doneCallback)
                while not isDone do
                    if (progressScope:isCanceled()) then
                        progressScope:cancel()
                        break
                    end
                    LrTasks.sleep(0)
                end
                checkSelectedSession(prop)
            end)
        end)
    end
end

local function getOrderUpdates(prop)
    if (prop.loggedInUser and prop.selectedClient) then
        LrTasks.startAsyncTask(function()
            LrFunctionContext.callWithContext('function', function(context)
                local isDone = false
                local isUpdate
                local progressScope = LrDialogs.showModalProgressDialog({
                    title = 'Retrieving Orders ',
                    cannotCancel = false,
                    functionContext = context,
                })

                local updateCallBack = function(ordersToFetch, ordersFetched)
                    progressScope:setPortionComplete(ordersFetched, ordersToFetch)
                    local caption
                    if (isUpdate) then
                        caption = "Updating Orders: "
                    else
                        caption = "Fetching Orders: "
                    end
                    caption = caption .. ordersFetched .. "/" .. ordersToFetch
                    progressScope:setCaption(caption)
                end

                local doneCallback = function()
                    prop.ordersList = prop.selectedClient.getAllOrders(true)
                    prop.filteredOrdersList = prop.ordersList
                    progressScope:done()
                    isDone = true
                end

                isUpdate = prop.selectedClient.fetchOrders(prop.loggedInUser.getApiKey(), updateCallBack, doneCallback)
                while not isDone do
                    if (progressScope:isCanceled()) then
                        progressScope:cancel()
                        break
                    end
                    LrTasks.sleep(0)
                end
                checkSelectedOrder(prop)
            end)
        end)
    end
end

local function login(propertyTable)
    LrTasks.startAsyncTask(function()
        local mimeChunks = {}
        mimeChunks[#mimeChunks + 1] = { name = 'email', value = propertyTable.email, contentType = 'application/json' }
        mimeChunks[#mimeChunks + 1] = { name = 'password', value = propertyTable.password, contentType = 'application/json' }

        local result, hdrs = LrHttp.postMultipart(SERVER .. "/login", mimeChunks)
        if not result then
            if hdrs and hdrs.error then
                LrErrors.throwUserError(hdrs.error)
            end
        else
            local lua_result = JSON:decode(result)
            if (lua_result.state ~= 1) then
                LrDialogs.message("Login Failed!")
            else
                if (lua_result.userType ~= 'member') then
                    LrDialogs.message("Login Failed!")
                else
                    LrDialogs.message("Welcome ", lua_result.userName)

                    local loggedUser = User(lua_result.userId, lua_result.userName, propertyTable.email, lua_result.ApiKey)
                    -- check if the user exists already in the UM

                    local foundUser = propertyTable.UserManager.findUser(lua_result.userId)
                    if (foundUser) then
                        -- we have found the user..update the data ..just in case
                        foundUser.setName(loggedUser.getName())
                        foundUser.setEmail(propertyTable.email)
                        foundUser.setApiKey(lua_result.ApiKey)
                    else
                        -- we haven't found the user ..it's a first timer!
                        propertyTable.UserManager.addUser(loggedUser)
                    end
                    -- set the user as the logged in user
                    propertyTable.UserManager.setLoggedInUser(loggedUser)
                    propertyTable.loggedInUser = loggedUser
                    propertyTable.loggedInUserName = loggedUser.getName()
                    --
                    getClientUpdates(propertyTable)
                end
            end
        end
    end)
end

local function logout(propertyTable)
    propertyTable.UserManager.setLoggedInUser(nil)
    propertyTable.loggedInUser = nil
end

local function updateSelectedUpload(prop, key, value)
    if (prop.selectedUpload == 'session') then
        prop.orderIds = nil;
        prop.selectedOrder = nil
        prop.UserManager.setSelectedOrderId(nil)
        getSessionUpdates(prop)
    else
        prop.sessionIds = nil;
        prop.selectedSession = nil
        prop.UserManager.setSelectedSessionId(nil)
        getOrderUpdates(prop)
    end
    updateExportStatus(prop)
end

local function filterClients(prop)

    local searchString = prop.clientSearchString

    if (searchString and searchString ~= '') then
        local matchCount = 0
        local filteredList = {}
        local listToFilter
        if (string.len(searchString) > 1) then
            listToFilter = prop.filteredClientsList
        else
            listToFilter = prop.clientsList
        end
        for key, viewClient in pairs(listToFilter) do
            local isMatch = string.find(viewClient.title, nocase(searchString)) ~= nil
            if (isMatch) then
                matchCount = matchCount + 1
                table.insert(filteredList, viewClient)
            end
        end
        prop.filteredClientsList = filteredList
    else
        prop.filteredClientsList = prop.clientsList
    end
end

local function filterSessions(prop)
    local searchString = prop.sessionSearchString

    if (searchString and searchString ~= '') then
        local matchCount = 0
        local filteredList = {}
        local listToFilter
        if (string.len(searchString) > 1) then
            listToFilter = prop.filteredSessionsList
        else
            listToFilter = prop.sessionsList
        end
        for key, viewSession in pairs(listToFilter) do
            local isMatch = string.find(viewSession.title, nocase(searchString)) ~= nil
            if (isMatch) then
                matchCount = matchCount + 1
                table.insert(filteredList, viewSession)
            end
        end
        prop.filteredSessionsList = filteredList
    else
        prop.filteredSessionsList = prop.sessionsList
    end
end

local function filterOrders(prop)
    local searchString = prop.orderSearchString

    if (searchString and searchString ~= '') then
        local matchCount = 0
        local filteredList = {}
        local listToFilter
        if (string.len(searchString) > 1) then
            listToFilter = prop.filteredOrdersList
        else
            listToFilter = prop.ordersList
        end
        for key, viewOrder in pairs(listToFilter) do
            local isMatch = string.find(viewOrder.title, nocase(searchString)) ~= nil
            if (isMatch) then
                matchCount = matchCount + 1
                table.insert(filteredList, viewOrder)
            end
        end
        prop.filteredOrdersList = filteredList
    else
        prop.filteredOrdersList = prop.ordersList
    end
end

local function registeObservers(prop) end

function PWUploadExportDialogSections.startDialog(propertyTable)


    propertyTable.UserManager = UserManager()
    local UM = propertyTable.UserManager
    -- try to load data

    local path = LrPathUtils.child(_PLUGIN.path, "test.txt")
    local chunk, error = loadfile(path)
    if chunk ~= nil then
        -- success, result contains the retrieved chunk
        local testData = chunk()
        UM.loadData(testData)
    end
    propertyTable.selectedUpload = ''
    -- here we should have data loaded

    -- check if there's a logged in user
    propertyTable.loggedInUser = UM.getLoggedInUser()
    if (propertyTable.loggedInUser) then
        propertyTable.loggedInUserName = propertyTable.loggedInUser.getName()
        propertyTable.isInitialized = false
        getClientUpdates(propertyTable)
    end


    propertyTable:addObserver('selectedUpload', updateSelectedUpload)
    propertyTable:addObserver('email', checkLogin)
    propertyTable:addObserver('password', checkLogin)

    propertyTable:addObserver('clientIds', selectedClient)
    propertyTable:addObserver('sessionIds', selectedSession)
    propertyTable:addObserver('orderIds', selectedOrder)

    propertyTable:addObserver('clientSearchString', filterClients)
    propertyTable:addObserver('sessionSearchString', filterSessions)
    propertyTable:addObserver('orderSearchString', filterOrders)
    updateExportStatus(propertyTable)
end

function PWUploadExportDialogSections.endDialog(propertyTable, why)

    local path = LrPathUtils.child(_PLUGIN.path, "test.txt")
    local result, error = io.open(path, "w")
    result:write('return ' .. propertyTable.UserManager.serialize())
    result:close()
end

function PWUploadExportDialogSections.sectionsForBottomOfDialog(_, propertyTable)

    local f = LrView.osFactory()
    local bind = LrView.bind
    local share = LrView.share

    local result = {
        {
            title = "Photo Workflow",
            synopsis = bind { key = 'fullPath', object = propertyTable },
            f:picture {
                value = _PLUGIN:resourceId("icon.png"),
                height = 100,
                width = 100,
                place_horizontal = 0.5,
                frame_width = 2
            },
            f:column {
                place = 'overlapping',
                f:view {
                    visible = LrBinding.keyIsNil 'loggedInUser',
                    spacing = f:control_spacing();
                    f:row {
                        f:static_text {
                            title = "Email:",
                            alignment = 'right',
                            width = share 'labelWidth'
                        },
                        f:edit_field {
                            value = bind 'email',
                            fill_horizontal = 1,
                            immediate = true,
                            width_in_chars = 30
                        },
                    },

                    f:row {
                        spacing = f:label_spacing(),

                        f:static_text {
                            title = 'Password:',
                            alignment = 'right',
                            width = share 'labelWidth'
                        },
                        f:password_field {
                            value = bind 'password',
                            fill_horizontal = 1,
                            immediate = true,
                            width_in_chars = 30
                        },
                    },
                    f:row {
                        f:push_button {
                            title = "Login",
                            enabled = bind 'readyToLogin',
                            action = function(button)
                                login(propertyTable)
                            end
                        }
                    }
                },
                f:view {
                    visible = LrBinding.keyIsNotNil 'loggedInUser',
                    f:row {
                        f:static_text {
                            title = bind 'loggedInUserName',
                            width = share 'labelWidth'
                        },
                        f:push_button {
                            title = "Logout",
                            enabled = true,
                            action = function(button)
                                logout(propertyTable)
                            end
                        }
                    },

                    f:row {
                        f:static_text {
                            visible = LrBinding.keyIsNotNil 'fetchingClients',
                            title = bind 'fetchingClientsTitle',
                            width_in_chars = 30
                        },
                        f:static_text {
                            visible = LrBinding.keyIsNotNil 'fetchingSessions',
                            title = "Fetching sessions..."
                        }
                    },

                    f:view {
                        visible = LrBinding.keyIsNotNil 'clientsList',
                        f:row {
                            f:view {
                                f:static_text {
                                    title = 'Client:',
                                    alignment = 'right'
                                },
                                f:edit_field {
                                    value = bind "clientSearchString",
                                    immediate = true,
                                    width = 180,
                                    placeholder_string = "Search Clients"
                                },
                                f:simple_list {
                                    items = bind 'filteredClientsList',
                                    value = bind 'clientIds',
                                    allows_multiple_selection = false,
                                    width = 180,
                                    value_equal = function(value1, value2)
                                        return value1 == value2
                                    end
                                }
                            },
                            f:view {
                                visible = LrBinding.keyIsNotNil 'clientIds',
                                f:column {
                                    spacing = f:label_spacing(),
                                    f:static_text {
                                        visible = false
                                    },
                                    f:radio_button {
                                        title = "Upload to Session",
                                        value = bind 'selectedUpload',
                                        checked_value = "session"
                                    },
                                    f:radio_button {
                                        title = "Upload to Order",
                                        value = bind 'selectedUpload',
                                        checked_value = 'order'
                                    }
                                }
                            },
                            f:view {
                                place = 'overlapping',
                                f:view {
                                    visible = LrBinding.keyEquals('selectedUpload', 'session'),
                                    f:static_text {
                                        title = 'Session:',
                                        alignment = 'right'
                                    },
                                    f:edit_field {
                                        value = bind "sessionSearchString",
                                        immediate = true,
                                        width = 320,
                                        placeholder_string = "Search Sessions"
                                    },
                                    f:simple_list {
                                        value = bind 'sessionIds',
                                        items = bind 'filteredSessionsList',
                                        width = 320
                                    }
                                },
                                f:view {
                                    visible = LrBinding.keyEquals('selectedUpload', 'order'),
                                    f:static_text {
                                        title = 'Order:',
                                        alignment = 'right'
                                    },
                                    f:edit_field {
                                        value = bind "orderSearchString",
                                        immediate = true,
                                        width = 320,
                                        placeholder_string = "Search Sessions"
                                    },
                                    f:simple_list {
                                        value = bind 'orderIds',
                                        items = bind 'filteredOrdersList',
                                        width = 320
                                    }
                                },
                            }
                        }
                    }
                },
            },
        },
    }

    return result
end

function PWUploadExportDialogSections.processRenderedPhotos(functionContext, exportContext)


    -- Make a local reference to the export parameters.
    local exportSession = exportContext.exportSession
    local exportParams = exportContext.propertyTable


    local UM = exportParams.UserManager
    if (not UM) then
        -- the user is trying to upload withoug opening the export dialog...
        UM = UserManager()
        local path = LrPathUtils.child(_PLUGIN.path, "test.txt")
        local chunk, error = loadfile(path)
        if chunk ~= nil then
            -- success, result contains the retrieved chunk
            local testData = chunk()
            UM.loadData(testData)
        end
    end


    local apiKey = UM.getLoggedInUser().getApiKey()
    local sessionId = UM.getSelectedSessionId()
    local orderId = UM.getSelectedOrderId()
    -- Set progress title.
    local nPhotos = exportSession:countRenditions()

    local progressScope = exportContext:configureProgress {
        title = nPhotos > 1
                and "Uploading " .. nPhotos .. " photos via Photo Workflow"
                or "Uploading one photo via Photo Workflow",
    }

    -- Iterate through photo renditions.

    local failures = {}

    for _, rendition in exportContext:renditions { stopIfCanceled = true } do

        -- Wait for next photo to render.
        local success, pathOrMessage = rendition:waitForRender()
        -- Check for cancellation again after photo has been rendered.
        if progressScope:isCanceled() then break end
        if success then

            local fileName = LrPathUtils.leafName(pathOrMessage)

            local headers = {
                { field = 'Authorization', value = apiKey }
            }
            local mimeChunks = {}
            mimeChunks[#mimeChunks + 1] = { name = 'photo', fileName = fileName, filePath = pathOrMessage, contentType = 'application/octet-stream' }
            if (sessionId) then
                mimeChunks[#mimeChunks + 1] = { name = 'sessionId', value = sessionId, contentType = 'application/json' }
            else
                mimeChunks[#mimeChunks + 1] = { name = 'orderId', value = orderId, contentType = 'application/json' }
            end
            local result, hdrs = LrHttp.postMultipart("http://photoworkflow.co.uk/API1.3.9/upload", mimeChunks, headers)

            if not result then
                if hdrs and hdrs.error then
                    table.insert(failures, fileName)
                    LrErrors.throwUserError(formatError(hdrs.error.nativeCode))
                end
            else
                local lua_result = JSON:decode(result)
                if (lua_result.status ~= 1) then
                    table.insert(failures, result)
                end
            end

            LrFileUtils.delete(pathOrMessage)
        end
    end

    if #failures > 0 then
        local message
        if #failures == 1 then
            message = LOC "$$$/FtpUpload/Upload/Errors/OneFileFailed=1 file failed to upload correctly."
        else
            message = LOC("$$$/FtpUpload/Upload/Errors/SomeFileFailed=^1 files failed to upload correctly.", #failures)
        end
        LrDialogs.message(message, table.concat(failures, "\n"))
    end
end