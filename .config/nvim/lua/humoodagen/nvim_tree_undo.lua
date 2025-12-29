local M = {}

local STASH_ROOT = "/Volumes/t7/.nvim-tree-undo"
local TTL_SECONDS = 24 * 60 * 60

local disabled = false
local warned = false
local replaying = false

local base_dir = nil
local items_dir = nil
local stack_file = nil

local function notify_once(msg)
    if warned then
        return
    end
    warned = true
    vim.notify(msg, vim.log.levels.WARN)
end

local function is_dir(path)
    local stat = vim.loop.fs_stat(path)
    return stat and stat.type == "directory"
end

local function project_root()
    local cwd = vim.loop.cwd() or vim.fn.getcwd()
    local root = cwd

    if vim.fs and vim.fs.find then
        local git_dir = vim.fs.find(".git", { path = cwd, upward = true })[1]
        if git_dir then
            root = vim.fn.fnamemodify(git_dir, ":h")
        end
    else
        local git_dir = vim.fn.finddir(".git", cwd .. ";")
        if git_dir and git_dir ~= "" then
            root = vim.fn.fnamemodify(git_dir, ":h")
        end
    end

    return vim.fn.fnamemodify(root, ":p")
end

local function project_id(root)
    local ok, hash = pcall(vim.fn.sha256, root)
    if ok and hash and hash ~= "" then
        return hash
    end
    return (root:gsub("[^%w%.-]", "_")):sub(1, 120)
end

local function ensure_paths()
    if disabled then
        return false
    end
    if not is_dir("/Volumes/t7") then
        disabled = true
        notify_once("nvim-tree undo disabled: /Volumes/t7 not available")
        return false
    end

    local root = project_root()
    local id = project_id(root)
    base_dir = STASH_ROOT .. "/" .. id
    items_dir = base_dir .. "/items"
    stack_file = base_dir .. "/stack.json"

    vim.fn.mkdir(items_dir, "p")
    return true
end

local function read_stack()
    if not ensure_paths() then
        return {}
    end
    if not vim.loop.fs_stat(stack_file) then
        return {}
    end

    local lines = vim.fn.readfile(stack_file)
    if #lines == 0 then
        return {}
    end

    local ok, decoded = pcall(vim.fn.json_decode, table.concat(lines, "\n"))
    if not ok or type(decoded) ~= "table" then
        return {}
    end

    return decoded
end

local function write_stack(stack)
    if not ensure_paths() then
        return
    end
    local ok, encoded = pcall(vim.fn.json_encode, stack)
    if not ok then
        return
    end
    vim.fn.writefile({ encoded }, stack_file)
end

local function remove_path(path)
    if not path or path == "" then
        return true
    end
    return vim.fn.delete(path, "rf") == 0
end

local function prune_stack(stack)
    local now = os.time()
    local kept = {}

    for _, entry in ipairs(stack) do
        local ts = type(entry) == "table" and entry.ts or nil
        if type(ts) == "number" and now - ts <= TTL_SECONDS then
            table.insert(kept, entry)
        else
            if type(entry) == "table" and entry.stash_path then
                remove_path(entry.stash_path)
            end
        end
    end

    if #kept ~= #stack then
        write_stack(kept)
    end

    return kept
end

local function push(entry)
    if replaying then
        return
    end
    local stack = read_stack()
    stack = prune_stack(stack)
    table.insert(stack, entry)
    write_stack(stack)
end

local function path_exists(path)
    return path and vim.loop.fs_stat(path) ~= nil
end

local function ensure_parent_dir(path)
    local parent = vim.fn.fnamemodify(path, ":h")
    if parent and parent ~= "" then
        vim.fn.mkdir(parent, "p")
    end
end

local function unique_stash_path(src)
    local base = vim.fn.fnamemodify(src, ":t")
    local suffix = tostring(os.time()) .. "_" .. tostring(vim.loop.hrtime())
    local dest = items_dir .. "/" .. base .. "_" .. suffix
    if not path_exists(dest) then
        return dest
    end
    return items_dir .. "/" .. base .. "_" .. suffix .. "_" .. tostring(math.random(1000, 9999))
end

local function apply_inverse(entry)
    replaying = true
    local ok = false

    if entry.type == "create" then
        if not path_exists(entry.src) then
            ok = true
        else
            ok = remove_path(entry.src)
        end
    elseif entry.type == "rename" then
        if entry.dst and path_exists(entry.dst) then
            ensure_parent_dir(entry.src)
            ok = vim.loop.fs_rename(entry.dst, entry.src) and true or false
        end
    elseif entry.type == "delete" then
        if entry.stash_path and path_exists(entry.stash_path) then
            if path_exists(entry.src) then
                ok = false
            else
                ensure_parent_dir(entry.src)
                ok = vim.loop.fs_rename(entry.stash_path, entry.src) and true or false
            end
        end
    end

    replaying = false
    return ok
end

function M.record_create(path)
    if not path or path == "" then
        return
    end
    if not ensure_paths() then
        return
    end
    push({ type = "create", src = path, ts = os.time() })
end

function M.record_rename(old_path, new_path)
    if not old_path or old_path == "" or not new_path or new_path == "" then
        return
    end
    if not ensure_paths() then
        return
    end
    push({ type = "rename", src = old_path, dst = new_path, ts = os.time() })
end

function M.trash(node)
    if not node or not node.absolute_path then
        return false
    end
    if not ensure_paths() then
        return false
    end

    local src = node.absolute_path
    local dest = unique_stash_path(src)
    local ok = vim.loop.fs_rename(src, dest)
    if not ok then
        return false
    end

    push({ type = "delete", src = src, stash_path = dest, ts = os.time() })
    return true
end

function M.undo_last()
    if not ensure_paths() then
        return
    end

    local stack = read_stack()
    stack = prune_stack(stack)

    local entry = stack[#stack]
    if not entry then
        vim.notify("nvim-tree undo: stack empty", vim.log.levels.INFO)
        return
    end

    local ok = apply_inverse(entry)
    if ok then
        table.remove(stack)
        write_stack(stack)
        require("nvim-tree.api").tree.reload()
        return
    end

    vim.notify("nvim-tree undo failed for " .. tostring(entry.type), vim.log.levels.WARN)
end

return M
