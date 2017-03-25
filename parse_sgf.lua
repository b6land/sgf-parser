-- this script will reduce the history of Go, translate to a plane board
-- accept SGF file
-- parameter: source SGF file, destination SGF file, player tag(1 for BLACK, -1 for WHITE)
-- example: lua parse_sgf.lua sgf/wgo_demo_1.sgf result.sgf 1
local filename = arg[1]
local player = arg[3]
local new_name = arg[2]
local board = {}
local dir = {{0, 1}, {0, -1}, {1, 0}, {-1, 0}}
local BLACK = 1
local WHITE = -1

-- read the SGF file, and return the string of left-most branch
function get_sgf_string(filename)
    local str

    if filename ~= nil then
        local file = io.open(filename, 'r')
        if file ~= nil then
            str = file:read('*a')
            file:close()
        end
    end

    if str == nil then
        print('File read error.')
        os.exit()
    end

    local node_end = string.find(str, '%)')
    local left_subtree = string.sub(str, 1, node_end)
    left_subtree = string.gsub(left_subtree, '%(;W', ';W')
    left_subtree = string.gsub(left_subtree, '%(;B', ';B')
    -- print(left_subtree)
    return left_subtree
end

-- parse the tag in string, and play go by tag
function parse(sgf_string)
    local start = 1
    local str_start, str
    while start < string.len(sgf_string) do
        str_start, start = string.find(sgf_string, '[ABW]+%[[a-z]+%]', start)
        if str_start == nil then
            break
        end
        str = string.sub(sgf_string, str_start, start)
        if string.sub(str, 1, 1) == 'A' then
            local player
            local r, c
            if string.sub(str, 2, 2) == 'B' then
                player = BLACK
            else
                player = WHITE
            end
            r, c = conv_rc(string.sub(str, 4, 5))
            board = play(board, r, c, player)

            local next_tag = string.find(sgf_string, '[ABW]+%[[a-z]+%]', start)
            local tag_start
            local tag_end = start
            while true do
                tag_start, tag_end = string.find(sgf_string, '%[[a-z]+%]', tag_end)
                if tag_start == nil or tag_start >= next_tag then
                    break
                end
                local tag = string.sub(sgf_string, tag_start, tag_end)
                r, c = conv_rc(string.sub(tag, 2, 3))
                board = play(board, r, c, player)
                str = str .. tag
            end
        elseif string.sub(str, 1, 1) == 'B' then
            local player = BLACK
            r, c = conv_rc(string.sub(str, 3, 4))
            board = play(board, r, c, player)
        elseif string.sub(str, 1, 1) == 'W' then
            local player = WHITE
            r, c = conv_rc(string.sub(str, 3, 4))
            board = play(board, r, c, player)
        end
        print(str)
    end
    show(board)
    return board
end

-- alphabet to number
function conv_rc(move)
    row = string.byte(move, 2, 2) - 96
    col = string.byte(move, 1, 1) - 96
    return row, col
end

-- number to alphabet
function conv(row, col)
    local p = string.char(col + 96)
    p = p .. string.char(row + 96)
    return p
end

-- no ko's check
function play(board, row, col, player)
    if row < 1 or row > 19 or col < 1 or col > 19 then
        print('Invalid position : ' .. row .. ', ' .. col)
        os.exit()
    end
    
    if board[row][col] == 0 then
        board[row][col] = player
        for i = 1, 4 do
            local new_row = row + dir[i][1]
            local new_col = col + dir[i][2]
            if new_row > 0 and new_row < 20 and new_col > 0 and new_col < 20 then
                local mark = {}
                mark = initialize(mark)
                ans, mark = capture(board, new_row, new_col, -player, mark)
                if ans == true then
                    board = remove_by_mark(board, mark)
                end
            end
        end

    else
        print('Move error ! ')
    end
    return board
end

-- calculate liberty by recursive funciton
-- if the stone's neighbor doesn't have empty, means no liberty, return false
-- if all the stone of this string with 0 liberty, means this string captured
function capture(board, row, col, player, mark)
    local ans = true
    local a
    mark[row][col] = 1
    for i = 1, 4 do
        local new_row = row + dir[i][1]
        local new_col = col + dir[i][2]
        if new_row > 0 and new_row < 20 and new_col > 0 and new_col < 20 then
            if board[new_row][new_col] == 0 then
                return false, mark
            elseif board[new_row][new_col] == player and mark[new_row][new_col] == 0 then
                a, mark = capture(board, new_row, new_col, player, mark)
                ans = ans and a
            end
        end
    end
    return ans, mark
end

-- remove the stone on the board with mark
function remove_by_mark(board, mark)
    for r = 1, 19 do
        for c = 1, 19 do
            if mark[r][c] == 1 then
                board[r][c] = 0
            end
        end
    end
    return board
end

-- show board
function show(board)
    for r = 1, 19 do
        local str = ''
        for c = 1, 19 do
            local icon = '.'
            if board[r][c] == BLACK then
                icon = 'x'
            elseif board[r][c] == WHITE then
                icon = 'o'
            end
            str = str .. ' ' .. icon
        end
        print(str)
    end
end

-- initialize the table
function initialize(board)
    for r = 1, 19 do
        board[r] = {}
        for c = 1, 19 do
            board[r][c] = 0
        end
    end
    return board
end

-- write a new file, that contains Player tag, Add Black and White tag
function write_game(board, name, player)
    player = tonumber(player)
    if player ~= BLACK and player ~= WHITE then
        print('Player name error.')
        os.exit()
    end
    local file = io.open(name, 'w')
    if file == nil then
        print('Can\'t write new file.')
        os.exit()
    end
    file:write('(;FF[4]CA[UTF-8]AP[]KM[6.5]')
    -- write AB tag
    local AB_first = false
    local AW_first = false
    local str = ''
    for r = 1, 19 do
        for c = 1, 19 do
            if board[r][c] == BLACK then
                if AB_first == false then
                    str = str .. 'AB'
                    AB_first = true
                end
                str = str .. '[' .. conv(r, c) .. ']'
            end
        end
    end
    -- write AW tag
    for r = 1, 19 do
        for c = 1, 19 do
            if board[r][c] == WHITE then
                if AW_first == false then
                    str = str .. 'AW'
                    AW_first = true
                end
                str = str .. '[' .. conv(r, c) .. ']'
            end
        end
    end
    file:write(str)
    if player == BLACK then
        file:write('PL[B])')
    else 
        file:write('PL[W])')
    end
    file:close()
end

board = initialize(board)
local gameplay = get_sgf_string(filename)
board = parse(gameplay)
write_game(board, new_name, player)
