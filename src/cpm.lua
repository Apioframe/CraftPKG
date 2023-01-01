local args = {...}

local repos = {}
local json = require("json")

function readRepos()
    local handle = assert(fs.open("./repositories.txt","r"))
    while true do
        local data = handle.readLine()
        if not data then break end
        table.insert(repos, data)
    end
    handle.close()
end
readRepos()
local firstRun = true
local bars = {"\\","|","/","-"}
local i = 1
local macska = false
function status(msg, type, progress, max)
    local x,y = term.getCursorPos()
    if type == "info" then
        if not firstRun then
            if macska then --what is firstRun for in a status funciton yes.
                term.setCursorPos(x,y-1)
                term.clearLine()
                term.setCursorPos(x,y-2)
                term.clearLine()
            else
                term.setCursorPos(x,y-1)
                term.clearLine()
            end
        end
        firstRun = false
        macska = false
        print(bars[i].." ["..type.."] "..msg.." "..math.floor(progress/max*100).."% ("..progress.."/"..max..")")
        local w,h = term.getSize()
        if #(bars[i].." ["..type.."] "..msg.." "..math.floor(progress/max*100).."% ("..progress.."/"..max..")") > w then
            macska = true
        end
    else
        print("["..type.."] "..msg)
    end

    i = i +1
    if i > #bars then
        i = 1
    end
end

local subcommands = {}

function addSubcommand(command,callback)
    subcommands[command] = callback
end



function getPackageMeta(package)
    if not fs.exists("/cpm/package-info.json") then
        return nil
    else
        local handle = assert(fs.open("/cpm/package-info.json","r"))
        local data = handle.readAll()
        handle.close()
        local d = json.decode(data)
        if d[package] then
            return d[package]
        else
            return nil
        end
    end
end

function updatePackageList()
    local datap = {}

    status("Checking package list", "info", 0, 0)
    for _,v in pairs(repos) do
        status("Checking "..v, "info", 0, 0)
        local handle = http.get(v)
        if handle then
            local data = handle.readAll()
            local ddata = json.decode(data)
            for kk,vv in ipairs(ddata.packages) do
                -- vv is just a url to the repo (https://github.com/V0xelTech/KristKorner)
                local pauthor = string.match(vv, "https://github.com/(.*)/")
                local pname = string.match(vv, "https://github.com/.*/(.*)")
                local apiurl = "https://api.github.com/repos/"..pauthor.."/"..pname.."/"
                status("Checking "..pauthor.."/"..pname, "info", kk, #ddata.packages)
                local meta = getPackageMeta(pname)
                local handlea = http.get("https://raw.githubusercontent.com/"..pauthor.."/"..pname.."/master/cpm_package.json")
                if handlea then
                    local dataa = handlea.readAll()
                    local ddataa = json.decode(dataa)
                    if true then
                        status("Updating entry "..ddataa.name, "info", kk, #ddata.packages)

                        -- we are now gonna get all the files in the package's root folder so we don't have to get it when tryna isntall
                        local content = {}
                        function getcontent(dir)
                            local url = apiurl.."contents/"..dir
                            local handleb = http.get(url)
                            if handleb then
                                local datab = handleb.readAll()
                                local ddatab = json.decode(datab)
                                for _,v in ipairs(ddatab) do
                                    if v.type == "file" then
                                        table.insert(content, v.path)
                                    elseif v.type == "dir" then
                                        getcontent(v.path)
                                    end
                                end
                            end
                        end
                        getcontent(ddataa.root)

                        datap[pname] = {
                            name = pname,
                            author = pauthor,
                            version = ddataa.version,
                            description = ddataa.description,
                            root = ddataa.root,
                            files = content,
                            depends = ddataa.depends
                        }

                        handlea.close()

                    end
                else
                    status("Failed to download, figure the package name out urself elbozo", "error", 0, 0)
                end
            end
        else
            status("Failed to update "..v, "error", 0, 0)
        end
    end
    if not fs.exists("/cpm") then
        fs.makeDir("/cpm")
    end
    local handle = assert(fs.open("/cpm/package-info.json","w"))
    handle.write(json.encode(datap))
    handle.close()
end

function installPackage(package)
    if not fs.exists("/cpm/packages") then
        fs.makeDir("/cpm/packages")
    end
    local meta = getPackageMeta(package)
    if meta then
        status("Installing "..meta.name, "info", 0, 0)
        local apiurl = "https://api.github.com/repos/"..meta.author.."/"..meta.name.."/"
        for k,v in ipairs(meta.files) do
            status("Downloading "..v, "info", k, #meta.files)
            local url = "https://raw.githubusercontent.com/"..meta.author.."/"..meta.name.."/master/"..v
            local handle = http.get(url)
            if handle then
                local data = handle.readAll()
                local path = "/cpm/packages/"..meta.name.."/"..v
                if not fs.exists("/cpm/packages/"..meta.name) then
                    fs.makeDir("/cpm/packages/"..meta.name)
                end
                local handlea = assert(fs.open(path,"w"))
                handlea.write(data)
                handlea.close()
                handle.close()
            else
                status("Failed to download "..v, "error", 0, 0)
            end
        end
    else
        status("Package not found", "error", 0, 0)
    end
end

addSubcommand("update",function()
    updatePackageList()
end)

addSubcommand("install", function()
    installPackage(args[2])
end)

for k,v in pairs(subcommands) do
    if args[1] == k then
        v()
    end
end