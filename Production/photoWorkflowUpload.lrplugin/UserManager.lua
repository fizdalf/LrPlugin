--
-- Created by IntelliJ IDEA.
-- User= Fizdalf
-- Date= 14/11/2016
-- Time= 17=07
-- To change this template use File | Settings | File Templates.
--
require 'BinaryTree';

local LrLogger = import 'LrLogger'
local LrTasks = import 'LrTasks'
local LrErrors = import 'LrErrors'
local myLogger = LrLogger('testLogger')
local LrHttp = import 'LrHttp'

local JSON = require "JSON" -- one-time load of the routines

require 'Utils'


myLogger:enable("logfile")
function Item(id)
    local self = {}

    local _id = id

    function self.getId()
        return _id
    end

    function self.setId(id)
        _id = id
    end

    function self.toString()
        return "id = " .. _id .. ""
    end

    return self
end

function ItemWithName(id, name)
    local self = Item(id)

    local _name = name;

    function self.getName()
        return _name
    end

    function self.setName(name)
        _name = name
    end

    local baseToString = self.toString
    function self.toString()
        return baseToString() .. ", name = \"" .. _name .. "\""
    end

    return self
end

function Session(id, name, date)
    local self = ItemWithName(id, name)
    local _date = date

    function self.getDate()
        return _date
    end

    function self.getFormattedDate()
        local s = _date
        local p = "(%d+)-(%d+)-(%d+)"
        local year, month, day = s:match(p)
        return day .. "-" .. month .. "-" .. year
    end

    function self.setDate(date)
        _date = date
    end

    local baseToString = self.toString
    function self.toString()
        return baseToString() .. ", date = '" .. _date .. "'"
    end

    function self.serialize()

        return "{" .. self.toString() .. "}"
    end

    function self.loadData(sessionData)
        self.setId(sessionData['id'])
        self.setName(sessionData['name'])
        self.setDate(sessionData['date'])
    end

    return self
end

function Order(id, date, status)
    local self = Item(id)
    local _date = date
    local _status = status

    function self.getDate()
        return _date
    end

    function self.getFormattedDate()
        local s = _date
        local p = "(%d+)-(%d+)-(%d+)"
        local year, month, day = s:match(p)
        return day .. "-" .. month .. "-" .. year
    end

    function self.setDate(date)
        _date = date
    end

    function self.getStatus()
        return _status
    end

    function self.setStatus(status)
        _status = status
    end

    local baseToString = self.toString
    function self.toString()
        return baseToString() .. ", date = '" .. (_date or "nil") .. "', status = '" .. (_status or "nil") .. "'"
    end

    function self.loadData(orderData)
        self.setId(orderData['id'])
        self.setDate(orderData['date'])
        self.setStatus(orderData['status'])
    end

    function self.serialize()
        return "{ " .. self.toString() .. " }"
    end

    return self
end

function Client(id, name, sessionList, orderList)
    local self = ItemWithName(id, name)
    local _sessionList = sessionList or BinaryTree()
    local _orderList = orderList or BinaryTree()
    local _lastUpdatedDateSessions
    local _lastUpdatedDateOrders

    function self.addSession(session)
        _sessionList.insertItem(session.getId(), session)
    end

    function self.removeSession(id)
        return _sessionList.remove(id);
    end

    function self.findSession(id)
        return _sessionList.search(id)
    end

    function self.getAllSessions(isView)
        local sessions = _sessionList.getAll()
        if sessions then
            if (isView) then
                local bst = BinaryTree()
                for key, session in pairs(sessions) do
                    local name = ((session.getId() or " no id") .. " - " .. session.getFormattedDate() or "no date ") .. " - " .. (session.getName() or "no description")
                    bst.insertItem(name, { title = name, value = session.getId() })
                end
                return bst.getAll()
            else
                return sessions
            end
        else
            return nil
        end
    end

    function self.addOrder(order)
        _orderList.insertItem(order.getId(), order)
    end

    function self.removeOrder(id)
        return _orderList.remove(id);
    end

    function self.findOrder(id)
        return _orderList.search(id)
    end

    function self.getAllOrders(isView)
        local orders = _orderList.getAll()
        if orders then
            if (isView) then
                local bst = BinaryTree()
                for key, order in pairs(orders) do
                    local name = (order.getId() or " no id") .. " - " .. (order.getFormattedDate() or "no date ") .. " - " .. (order.getStatus() or "no status")
                    bst.insertItem(name, { title = name, value = order.getId() })
                end
                return bst.getAll()
            else
                return orders
            end
        else
            return nil
        end
    end

    function self.fetchSessions(apiKey, updateCallback, doneCallback)
        if (apiKey ~= nil) then
            LrTasks.startAsyncTask(function()
                local headers = {
                    { field = 'Authorization', value = apiKey }
                }
                local serverQuery = SERVER .. "/clients/" .. self.getId() .. "/sessions"
                if (_lastUpdatedDateSessions ~= nil) then
                    serverQuery = serverQuery .. "?modifiedAfter=" .. _lastUpdatedDateSessions
                end

                local result, hdrs = LrHttp.get(serverQuery, headers)
                if not result then
                    if hdrs and hdrs.error then
                        LrErrors.throwUserError(hdrs.error.nativeCode)
                    end
                else
                    for _, header in pairs(hdrs) do
                        if (type(header) == 'table' and header.field == "Date") then
                            local s = header.value
                            local p = "%a+, (%d+) (%a+) (%d+) (%d+):(%d+):(%d+) GMT"
                            local day, month, year, hour, min, sec = s:match(p)
                            local MON = { Jan = "01", Feb = "02", Mar = "03", Apr = "04", May = "05", Jun = "06", Jul = "07", Aug = "08", Sep = "09", Oct = "10", Nov = "11", Dec = "12" }
                            month = MON[month]
                            day = string.format("%02d", day)
                            _lastUpdatedDateSessions = year .. "-" .. month .. "-" .. day .. " " .. hour .. ":" .. min .. ":" .. sec
                        end
                    end

                    local lua_result = JSON:decode(result)
                    local sessionsToFetch
                    if (lua_result.sessions) then
                        sessionsToFetch = #lua_result.sessions;
                        local sessionsFetched = 0;
                        updateCallback(sessionsToFetch, sessionsFetched)
                        for _, value in pairs(lua_result.sessions) do

                            local currentSession = value -- cache the client head

                            local foundSession = _sessionList.search(currentSession['id']) -- search for it in the BST
                            if (currentSession['deleted'] == 1) then -- check if the client is marke for deletion

                                if (foundSession) then -- in case we find it
                                    --remove it from the list (all associated sessions and orders are gone for free :D)
                                    _sessionList.remove(currentSession['id'])
                                end
                                sessionsFetched = sessionsFetched + 1
                                updateCallback(sessionsToFetch, sessionsFetched)
                            else
                                local sessionName = currentSession['name']
                                local sessionDate = currentSession.date
                                if (foundSession) then
                                    foundSession.setName(sessionName)
                                    foundSession.setDate(sessionDate)
                                else
                                    _sessionList.insertItem(currentSession['id'], Session(currentSession['id'], sessionName, sessionDate))
                                end
                                sessionsFetched = sessionsFetched + 1
                                updateCallback(sessionsToFetch, sessionsFetched)
                            end
                        end
                    end
                    doneCallback()
                end
            end)
        end
    end

    function self.fetchOrders(apiKey, updateCallback, doneCallback)
        if (apiKey ~= nil) then
            LrTasks.startAsyncTask(function()
                local headers = {
                    { field = 'Authorization', value = apiKey }
                }

                local serverQuery = SERVER .. "/clients/" .. self.getId() .. "/orders"
                if (_lastUpdatedDateOrders ~= nil) then
                    serverQuery = serverQuery .. "?modifiedAfter=" .. _lastUpdatedDateOrders
                end
                local result, hdrs = LrHttp.get(serverQuery, headers)
                if not result then
                    if hdrs and hdrs.error then
                        LrErrors.throwUserError(hdrs.error.nativeCode)
                    end
                else
                    for _, header in pairs(hdrs) do
                        if (type(header) == 'table' and header.field == "Date") then
                            local s = header.value
                            local p = "%a+, (%d+) (%a+) (%d+) (%d+):(%d+):(%d+) GMT"
                            local day, month, year, hour, min, sec = s:match(p)
                            local MON = { Jan = "01", Feb = "02", Mar = "03", Apr = "04", May = "05", Jun = "06", Jul = "07", Aug = "08", Sep = "09", Oct = "10", Nov = "11", Dec = "12" }
                            month = MON[month]
                            day = string.format("%02d", day)
                            _lastUpdatedDateOrders = year .. "-" .. month .. "-" .. day .. " " .. hour .. ":" .. min .. ":" .. sec
                        end
                    end

                    local lua_result = JSON:decode(result)
                    local ordersToFetch
                    if (lua_result.orders) then
                        ordersToFetch = #lua_result.orders;
                        local ordersFetched = 0;
                        updateCallback(ordersToFetch, ordersFetched)
                        for _, value in pairs(lua_result.orders) do

                            local currentOrder = value -- cache the client head

                            local foundOrder = _orderList.search(currentOrder['id']) -- search for it in the BST
                            if (currentOrder['deleted'] == 1) then -- check if the client is marke for deletion

                                if (foundOrder) then -- in case we find it
                                    --remove it from the list (all associated orders and orders are gone for free :D)
                                    _orderList.remove(currentOrder['id'])
                                end
                                ordersFetched = ordersFetched + 1
                                updateCallback(ordersToFetch, ordersFetched)
                            else

                                local orderDate = currentOrder.date
                                local orderStatus = currentOrder.status
                                if (foundOrder) then
                                    foundOrder.setDate(orderDate)
                                    foundOrder.setStatus(orderStatus)
                                else
                                    _orderList.insertItem(currentOrder['id'], Order(currentOrder['id'], orderDate, orderStatus))
                                end
                                ordersFetched = ordersFetched + 1
                                updateCallback(ordersToFetch, ordersFetched)
                            end
                        end
                    end
                    doneCallback()
                end
            end)
        end
    end

    function self.loadData(clientData)
        self.setId(clientData['id'])
        self.setName(clientData['name'])
        if (clientData['orderList']) then
            for _, value in pairs(clientData['orderList']) do
                local currentOrder = Order()
                currentOrder.loadData(value)
                self.addOrder(currentOrder)
            end
        end
        if (clientData['sessionList']) then
            for _, value in pairs(clientData['sessionList']) do
                local currentSession = Session()
                currentSession.loadData(value)
                self.addSession(currentSession)
            end
        end
    end

    function self.serialize()
        return "{" .. self.toString() .. ", sessionList = " .. _sessionList.serialize() .. ", orderList =" .. _orderList.serialize() .. "}"
    end

    return self
end

function User(id, name, email, apiKey, clientList, lastUpdatedDate)
    local self = ItemWithName(id, name)
    local _email = email
    local _apiKey = apiKey
    local _clientList = clientList or BinaryTree();
    local _lastUpdatedDate = lastUpdatedDate or nil;


    function self.getEmail()
        return _email
    end

    function self.setEmail(email)
        _email = email
    end

    function self.getApiKey()
        return _apiKey;
    end

    function self.setApiKey(apiKey)
        _apiKey = apiKey
    end

    function self.addClient(client)
        _clientList.insertItem(client.getId(), client)
    end

    function self.removeClient(id)
        return _clientList.remove(id)
    end

    function self.findClient(id)
        return _clientList.search(id)
    end

    function self.getClients(forView)
        local clients = _clientList.getAll()
        if clients then
            if (forView) then
                local bst = BinaryTree()
                for key, value in pairs(clients) do
                    bst.insertItem(value.getName(), { title = value.getName(), value = value.getId() })
                end
                return bst.getAll()
            else
                return clients
            end
        else
            return nil
        end
    end

    function self.getLastUpdatedDate()
        return _lastUpdatedDate
    end

    function self.setLastUpdatedDate(date)
        _lastUpdatedDate = date
    end

    local baseToString = self.toString
    function self.toString()
        return baseToString() .. ", email = '" .. self.getEmail() .. "' , apiKey = '" .. self.getApiKey() ..
                "' , lastUpdatedDate = '" .. (self.getLastUpdatedDate() or "") .. "'"
    end

    function self.serialize()
        return "{ " .. self.toString() .. " , clientList = " .. _clientList.serialize() .. " }"
    end

    function self.fetchClients(updateFunction, doneFunction)
        -- lets see if we don't put the startAsync here..
        -- first we should check if we have already pulled clients
        if (_apiKey) then
            LrTasks.startAsyncTask(function()
                local headers = {
                    { field = 'Authorization', value = _apiKey }
                }
                local serverQuery = SERVER .. "/clients?plugin=true"
                if (_lastUpdatedDate) then
                    -- we have pulled data at least once ..we just need to pull updates now

                    serverQuery = serverQuery .. "&modifiedAfter=" .. _lastUpdatedDate
                end

                local result, hdrs = LrHttp.get(serverQuery, headers)
                if not result then
                    if hdrs and hdrs.error then
                        LrErrors.throwUserError(hdrs.error.nativeCode)
                    end
                else
                    for _, header in pairs(hdrs) do
                        if (type(header) == 'table' and header.field == "Date") then
                            local s = header.value
                            local p = "%a+, (%d+) (%a+) (%d+) (%d+):(%d+):(%d+) GMT"
                            local day, month, year, hour, min, sec = s:match(p)
                            local MON = { Jan = "01", Feb = "02", Mar = "03", Apr = "04", May = "05", Jun = "06", Jul = "07", Aug = "08", Sep = "09", Oct = "10", Nov = "11", Dec = "12" }
                            month = MON[month]
                            day = string.format("%02d", day)
                            _lastUpdatedDate = year .. "-" .. month .. "-" .. day .. " " .. hour .. ":" .. min .. ":" .. sec
                        end
                    end

                    local lua_result = JSON:decode(result)
                    local clientsToFetch
                    if (lua_result.clients) then
                        clientsToFetch = #lua_result.clients;
                        local clientsFetched = 0;
                        updateFunction(clientsToFetch, clientsFetched)
                        for _, value in pairs(lua_result.clients) do

                            local currentClient = value -- cache the client head

                            local foundClient = _clientList.search(currentClient['id']) -- search for it in the BST
                            if (currentClient['deleted'] == 1) then -- check if the client is marke for deletion

                                if (foundClient) then -- in case we find it
                                    --remove it from the list (all associated sessions and orders are gone for free :D)
                                    _clientList.remove(currentClient['id'])
                                end
                                clientsFetched = clientsFetched + 1
                                updateFunction(clientsToFetch, clientsFetched)
                            else
                                local clientName = currentClient['name']
                                if (foundClient) then
                                    foundClient.setName(clientName)
                                else
                                    _clientList.insertItem(currentClient['id'], Client(currentClient['id'], clientName))
                                end
                                clientsFetched = clientsFetched + 1
                                updateFunction(clientsToFetch, clientsFetched)
                            end
                        end
                    end
                    doneFunction();
                end
            end)
        end
        return (_lastUpdatedDate ~= nil)
    end

    function self.loadData(userData)
        self.setId(userData.id)
        self.setName(userData.name)
        self.setApiKey(userData.apiKey)
        self.setEmail(userData.email)
        _lastUpdatedDate = userData.lastUpdatedDate
        if (userData['clientList']) then
            for _, value in pairs(userData['clientList']) do
                local currentClient = Client()
                currentClient.loadData(value)
                self.addClient(currentClient)
            end
        end
    end

    return self
end

function UserManager()
    local self = {}
    local _userList = BinaryTree() -- BinaryTree type
    local _loggedInUser
    local _selectedClientId
    local _selectedSessionId
    local _selectedOrderId

    function self.addUser(user)
        return _userList.insertItem(user.getId(), user)
    end

    function self.removeUser(id)
        return _userList.remove(id)
    end

    function self.findUser(id)
        return _userList.search(id)
    end

    function self.getLoggedInUser()
        return _loggedInUser
    end

    function self.setLoggedInUser(user)

        _loggedInUser = user
    end

    function self.getSelectedClientId()
        return _selectedClientId;
    end

    function self.setSelectedClientId(selectedClientId)
        _selectedClientId = selectedClientId
    end

    function self.getSelectedSessionId()
        return _selectedSessionId;
    end

    function self.setSelectedSessionId(selectedSessionId)
        _selectedSessionId = selectedSessionId
    end

    function self.getSelectedOrderId()
        return _selectedOrderId;
    end

    function self.setSelectedOrderId(selectedOrderId)
        _selectedOrderId = selectedOrderId
    end

    function self.loadData(data)
        -- we should get a userList
        if (data) then
            local userList = data['userList']
            -- if the userlist is empty there's no point on proceeding
            if (userList) then
                for _, value in pairs(data['userList']) do
                    -- recreate each user
                    local currentUser = User()
                    currentUser.loadData(value)
                    self.addUser(currentUser)
                end
                local loggedInUserId = data['loggedInUserId']
                if (loggedInUserId) then
                    _loggedInUser = self.findUser(loggedInUserId)
                end
            end

            _selectedClientId = data.selectedClientId

            _selectedSessionId = data.selectedSessionId

            _selectedOrderId = data.selectedOrderId
        end
    end

    function self.serialize()
        local loggedInUserId
        if (_loggedInUser) then
            loggedInUserId = _loggedInUser.getId()
        else
            loggedInUserId = "nil"
        end
        return "{ userList = " .. _userList.serialize() .. " , loggedInUserId = " .. loggedInUserId ..
                ", selectedClientId = " .. (self.getSelectedClientId() or "nil") .. ", selectedSessionId = " ..
                (self.getSelectedSessionId() or "nil") .. ", selectedOrderId = "
                .. (self.getSelectedOrderId() or "nil") .. " }"
    end

    return self
end