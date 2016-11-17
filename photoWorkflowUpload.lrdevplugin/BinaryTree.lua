--
-- Created by IntelliJ IDEA.
-- User= Fizdalf
-- Date= 14/11/2016
-- Time= 14=33
-- To change this template use File | Settings | File Templates.
--
require 'Utils'
local LrLogger = import 'LrLogger'
local myLogger = LrLogger('testLogger')
myLogger:enable("logfile")

function BinaryTree()
    local self = {
        root = nil
    }

    local function Node(key, item, left, right)
        local self = {
            key = key or nil,
            item = item or nil,
            left = left or nil,
            right = right or nil
        }

        local function getKey()
            return self.key
        end

        local function setKey(key)
            self.key = key
        end

        local function getItem()
            return self.item
        end

        local function setItem(item)
            self.item = item;
        end

        local function getLeft()
            return self.left;
        end

        local function setLeft(left)
            self.left = left
        end

        local function getRight()
            return self.right
        end

        local function setRight(right)
            self.right = right
        end

        return {
            getKey = getKey,
            setKey = setKey,
            getItem = getItem,
            setItem = setItem,
            getLeft = getLeft,
            setLeft = setLeft,
            getRight = getRight,
            setRight = setRight,
        }
    end

    local function bst_insert(key, item, t)

        if (key == nil) then
            error('key is null')
        end
        -- if t is nil (the binary tree) is null that means we have found a place to put our data
        if (t == nil) then

            return Node(key, item)
        else

            local tKey = t.getKey();

            if (key < tKey) then

                t.setLeft(bst_insert(key, item, t.getLeft()))
                return t
            elseif key == tKey then

                t.setItem(item)
                return t
            elseif key > tKey then

                t.setRight(bst_insert(key, item, t.getRight()))
                return t
            else
                error('this shouldn\'t be possible')
            end
        end
    end

    local function insertItem(key, item)
        self.root = bst_insert(key, item, self.root)
    end

    local function bst_search(key, node)
        if (node == nil or key == nil) then
            return nil
        else
            local nodeKey = node.getKey()
            if (key < nodeKey) then
                return bst_search(key, node.getLeft())
            elseif (key == nodeKey) then
                return node.getItem()
            elseif (key > nodeKey) then
                return bst_search(key, node.getRight())
            end
        end
    end

    local function search(key)
        return bst_search(key, self.root)
    end

    local function bst_min(node)
        local nodeLeft = node.getLeft();
        if (nodeLeft == nil) then
            return node.getKey(), node.getItem()
        else
            return bst_min(nodeLeft)
        end
    end

    local function bst_remove(node, key, parentNode)
        local nodeKey = node.getKey();
        if key < nodeKey then
            local nodeLeft = node.getLeft()
            if nodeLeft ~= nil then
                return bst_remove(nodeLeft, key, node)
            else
                return false
            end
        elseif key > nodeKey then
            local nodeRight = node.getRight()
            if nodeRight ~= nil then
                return bst_remove(nodeRight, key, node)
            else
                return false;
            end
        else
            local nodeLeft = node.getLeft()
            local nodeRight = node.getRight()
            if (nodeLeft ~= nil and nodeRight ~= nil) then
                local minKey, minItem = bst_min(nodeRight)
                node.setKey(minKey)
                node.setItem(minItem)
                bst_remove(nodeRight, minKey, node)
            elseif (parentNode.getLeft().getKey() == nodeKey) then
                parentNode.setLeft(nodeLeft or nodeRight)
            elseif (parentNode.getRight().getKey() == nodeKey) then
                parentNode.setRight(nodeLeft or nodeRight)
            end
        end
    end

    local function remove(key)
        if (self.root == nil) then
            return false
        else
            if (self.root.getKey == key) then
                local auxRoot = Node();
                auxRoot.setLeft(self.root)
                local result = bst_remove(self.root, key, auxRoot)
                self.root = auxRoot.getLeft();
                return result;
            else
                return bst_remove(self.root, key, null)
            end
        end
    end

    local function merge(a, b)
        -- create a new table where we have elements of a then elements of b

        if (a ~= nil and b ~= nil) then
            local toReturn = {}
            for i, v in pairs(a) do
                table.insert(toReturn, v)
            end
            for i, v in pairs(b) do
                table.insert(toReturn, v)
            end
            return toReturn

        elseif (a == nil) then
            return b
        else
            return a
        end
    end

    local function inorder(node)
        local nodeLeft = node.getLeft()
        local nodeRight = node.getRight()
        local toReturn = {};
        if (nodeLeft ~= nil) then
            toReturn = inorder(nodeLeft)
        end
        toReturn = merge(toReturn, { node.getItem() })
        if (nodeRight ~= nil) then
            return merge(toReturn, inorder(nodeRight))
        else
            return toReturn
        end
    end

    local function getAll()
        if self.root == nil then
            return nil
        else
            return inorder(self.root)
        end
    end

    local function serialize()
        local allItems = getAll()
        if allItems == nil then
            return "nil"
        end
        local toReturn = "{";

        for key, value in pairs(allItems) do
            local valueType = type(value)
            if (valueType == 'string') then
                toReturn = toReturn .. "'" .. value .. "'"
            elseif (valueType == 'number') then
                toReturn = toReturn .. value
            else
                if (type(value.serialize) == 'function') then
                    -- this is a primitive value..so if it's a
                    toReturn = toReturn .. value.serialize()
                end
            end

            toReturn = toReturn .. ","
        end

        toReturn = toReturn .. " }"
        return toReturn
    end

    local function isEmpty()
        return (self.root == nil)
    end

    return {
        insertItem = insertItem,
        search = search,
        remove = remove,
        getAll = getAll,
        serialize = serialize,
        isEmpty = isEmpty
    }
end

