-- PakettiCanvasFont.lua
-- Global canvas line-font helper for Renoise tools (Lua 5.1)

-- LETTERS -------------------------------------------------------------
function PakettiCanvasFontDrawLetterA(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y + size)
  ctx:line_to(x + size/2, y)
  ctx:line_to(x + size, y + size)
  ctx:move_to(x + size/4, y + size/2)
  ctx:line_to(x + 3*size/4, y + size/2)
  ctx:stroke()
end

function PakettiCanvasFontDrawLetterB(ctx, x, y, size)
  ctx:begin_path()
  -- left stem
  ctx:move_to(x, y)
  ctx:line_to(x, y + size)
  -- upper bowl (rounded with diagonals), full width
  ctx:move_to(x, y)
  ctx:line_to(x + (13*size)/20, y)
  ctx:line_to(x + size, y + size/4)
  ctx:line_to(x + (13*size)/20, y + size/2)
  -- lower bowl (rounded with diagonals), full width
  ctx:move_to(x, y + size)
  ctx:line_to(x + (13*size)/20, y + size)
  ctx:line_to(x + size, y + 3*size/4)
  ctx:line_to(x + (13*size)/20, y + size/2)
  -- connect bowls to the left stem at midpoint
  ctx:line_to(x, y + size/2)
  ctx:stroke()
end

function PakettiCanvasFontDrawLetterC(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x + size, y)
  ctx:line_to(x, y)
  ctx:line_to(x, y + size)
  ctx:line_to(x + size, y + size)
  ctx:stroke()
end

function PakettiCanvasFontDrawLetterD(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y)
  ctx:line_to(x, y + size)
  ctx:line_to(x + 3*size/4, y + size)
  ctx:line_to(x + size, y + 3*size/4)
  ctx:line_to(x + size, y + size/4)
  ctx:line_to(x + 3*size/4, y)
  ctx:line_to(x, y)
  ctx:stroke()
end

function PakettiCanvasFontDrawLetterE(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x + size, y)
  ctx:line_to(x, y)
  ctx:line_to(x, y + size)
  ctx:line_to(x + size, y + size)
  ctx:move_to(x, y + size/2)
  ctx:line_to(x + 3*size/4, y + size/2)
  ctx:stroke()
end

function PakettiCanvasFontDrawLetterF(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y + size)
  ctx:line_to(x, y)
  ctx:line_to(x + size, y)
  ctx:move_to(x, y + size/2)
  ctx:line_to(x + 3*size/4, y + size/2)
  ctx:stroke()
end

function PakettiCanvasFontDrawLetterG(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x + size, y)
  ctx:line_to(x, y)
  ctx:line_to(x, y + size)
  ctx:line_to(x + size, y + size)
  ctx:line_to(x + size, y + size/2)
  ctx:line_to(x + size/2, y + size/2)
  ctx:stroke()
end

function PakettiCanvasFontDrawLetterH(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y)
  ctx:line_to(x, y + size)
  ctx:move_to(x + size, y)
  ctx:line_to(x + size, y + size)
  ctx:move_to(x, y + size/2)
  ctx:line_to(x + size, y + size/2)
  ctx:stroke()
end

function PakettiCanvasFontDrawLetterI(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y)
  ctx:line_to(x + size, y)
  ctx:move_to(x + size/2, y)
  ctx:line_to(x + size/2, y + size)
  ctx:move_to(x, y + size)
  ctx:line_to(x + size, y + size)
  ctx:stroke()
end

function PakettiCanvasFontDrawLetterJ(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y)
  ctx:line_to(x + size, y)
  ctx:move_to(x + size/2, y)
  ctx:line_to(x + size/2, y + size)
  ctx:line_to(x, y + size)
  ctx:stroke()
end

function PakettiCanvasFontDrawLetterK(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y)
  ctx:line_to(x, y + size)
  ctx:move_to(x + size, y)
  ctx:line_to(x, y + size/2)
  ctx:line_to(x + size, y + size)
  ctx:stroke()
end

function PakettiCanvasFontDrawLetterL(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y)
  ctx:line_to(x, y + size)
  ctx:line_to(x + size, y + size)
  ctx:stroke()
end

function PakettiCanvasFontDrawLetterM(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y + size)
  ctx:line_to(x, y)
  ctx:line_to(x + size/2, y + size/2)
  ctx:line_to(x + size, y)
  ctx:line_to(x + size, y + size)
  ctx:stroke()
end

function PakettiCanvasFontDrawLetterN(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y + size)
  ctx:line_to(x, y)
  ctx:line_to(x + size, y + size)
  ctx:line_to(x + size, y)
  ctx:stroke()
end

function PakettiCanvasFontDrawLetterO(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y)
  ctx:line_to(x + size, y)
  ctx:line_to(x + size, y + size)
  ctx:line_to(x, y + size)
  ctx:line_to(x, y)
  ctx:stroke()
end

function PakettiCanvasFontDrawLetterP(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y + size)
  ctx:line_to(x, y)
  ctx:line_to(x + size, y)
  ctx:line_to(x + size, y + size/2)
  ctx:line_to(x, y + size/2)
  ctx:stroke()
end

function PakettiCanvasFontDrawLetterQ(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y)
  ctx:line_to(x + size, y)
  ctx:line_to(x + size, y + size)
  ctx:line_to(x, y + size)
  ctx:line_to(x, y)
  ctx:move_to(x + size/2, y + size/2)
  ctx:line_to(x + size, y + size)
  ctx:stroke()
end

function PakettiCanvasFontDrawLetterR(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y + size)
  ctx:line_to(x, y)
  ctx:line_to(x + size, y)
  ctx:line_to(x + size, y + size/2)
  ctx:line_to(x, y + size/2)
  ctx:line_to(x + size, y + size)
  ctx:stroke()
end

function PakettiCanvasFontDrawLetterS(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x + size, y + size/4)
  ctx:line_to(x + size, y)
  ctx:line_to(x, y)
  ctx:line_to(x, y + size/2)
  ctx:line_to(x + size, y + size/2)
  ctx:line_to(x + size, y + size)
  ctx:line_to(x, y + size)
  ctx:line_to(x, y + 3*size/4)
  ctx:stroke()
end

function PakettiCanvasFontDrawLetterT(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y)
  ctx:line_to(x + size, y)
  ctx:move_to(x + size/2, y)
  ctx:line_to(x + size/2, y + size)
  ctx:stroke()
end

function PakettiCanvasFontDrawLetterU(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y)
  ctx:line_to(x, y + size)
  ctx:line_to(x + size, y + size)
  ctx:line_to(x + size, y)
  ctx:stroke()
end

function PakettiCanvasFontDrawLetterV(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y)
  ctx:line_to(x + size/2, y + size)
  ctx:line_to(x + size, y)
  ctx:stroke()
end

function PakettiCanvasFontDrawLetterW(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y)
  ctx:line_to(x + size/4, y + size)
  ctx:line_to(x + size/2, y + size/2)
  ctx:line_to(x + 3*size/4, y + size)
  ctx:line_to(x + size, y)
  ctx:stroke()
end

function PakettiCanvasFontDrawLetterX(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y)
  ctx:line_to(x + size, y + size)
  ctx:move_to(x + size, y)
  ctx:line_to(x, y + size)
  ctx:stroke()
end

function PakettiCanvasFontDrawLetterY(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y)
  ctx:line_to(x + size/2, y + size/2)
  ctx:line_to(x + size, y)
  ctx:move_to(x + size/2, y + size/2)
  ctx:line_to(x + size/2, y + size)
  ctx:stroke()
end

function PakettiCanvasFontDrawLetterZ(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y)
  ctx:line_to(x + size, y)
  ctx:line_to(x, y + size)
  ctx:line_to(x + size, y + size)
  ctx:stroke()
end

-- DIGITS --------------------------------------------------------------
function PakettiCanvasFontDrawDigit0(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y)
  ctx:line_to(x + size, y)
  ctx:line_to(x + size, y + size)
  ctx:line_to(x, y + size)
  ctx:line_to(x, y)
  ctx:line_to(x + size, y + size)
  ctx:stroke()
end

function PakettiCanvasFontDrawDigit1(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x + size/2, y)
  ctx:line_to(x + size/2, y + size)
  ctx:move_to(x + size/2, y)
  ctx:line_to(x + size/4, y + size/4)
  ctx:stroke()
end

function PakettiCanvasFontDrawDigit2(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y)
  ctx:line_to(x + size, y)
  ctx:line_to(x + size, y + size/2)
  ctx:line_to(x, y + size/2)
  ctx:line_to(x, y + size)
  ctx:line_to(x + size, y + size)
  ctx:stroke()
end

function PakettiCanvasFontDrawDigit3(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y)
  ctx:line_to(x + size, y)
  ctx:line_to(x + size, y + size/2)
  ctx:line_to(x, y + size/2)
  ctx:move_to(x + size, y + size/2)
  ctx:line_to(x + size, y + size)
  ctx:line_to(x, y + size)
  ctx:stroke()
end

function PakettiCanvasFontDrawDigit4(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y)
  ctx:line_to(x, y + size/2)
  ctx:line_to(x + size, y + size/2)
  ctx:move_to(x + size, y)
  ctx:line_to(x + size, y + size)
  ctx:stroke()
end

function PakettiCanvasFontDrawDigit5(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x + size, y)
  ctx:line_to(x, y)
  ctx:line_to(x, y + size/2)
  ctx:line_to(x + size, y + size/2)
  ctx:line_to(x + size, y + size)
  ctx:line_to(x, y + size)
  ctx:stroke()
end

function PakettiCanvasFontDrawDigit6(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x + size, y)
  ctx:line_to(x, y)
  ctx:line_to(x, y + size)
  ctx:line_to(x + size, y + size)
  ctx:line_to(x + size, y + size/2)
  ctx:line_to(x, y + size/2)
  ctx:stroke()
end

function PakettiCanvasFontDrawDigit7(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y)
  ctx:line_to(x + size, y)
  ctx:line_to(x + size/2, y + size)
  ctx:stroke()
end

function PakettiCanvasFontDrawDigit8(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y)
  ctx:line_to(x + size, y)
  ctx:line_to(x + size, y + size)
  ctx:line_to(x, y + size)
  ctx:line_to(x, y)
  ctx:move_to(x, y + size/2)
  ctx:line_to(x + size, y + size/2)
  ctx:stroke()
end

function PakettiCanvasFontDrawDigit9(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x + size, y + size)
  ctx:line_to(x + size, y)
  ctx:line_to(x, y)
  ctx:line_to(x, y + size/2)
  ctx:line_to(x + size, y + size/2)
  ctx:stroke()
end

-- PUNCTUATION --------------------------------------------------------
function PakettiCanvasFontDrawSpace(ctx, x, y, size)
  -- no-op
end

function PakettiCanvasFontDrawDot(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x + size/2, y + size)
  ctx:line_to(x + size/2, y + size - 2)
  ctx:stroke()
end

function PakettiCanvasFontDrawComma(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x + size/2, y + size)
  ctx:line_to(x + size/2, y + size - 2)
  ctx:move_to(x + size/2, y + size)
  ctx:line_to(x + size/2 - 2, y + size + 2)
  ctx:stroke()
end

function PakettiCanvasFontDrawUnderscore(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y + size)
  ctx:line_to(x + size, y + size)
  ctx:stroke()
end

function PakettiCanvasFontDrawDash(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x + size/4, y + size/2)
  ctx:line_to(x + 3*size/4, y + size/2)
  ctx:stroke()
end

function PakettiCanvasFontDrawHash(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x + size/3, y + size/4)
  ctx:line_to(x + size/3, y + 3*size/4)
  ctx:move_to(x + 2*size/3, y + size/4)
  ctx:line_to(x + 2*size/3, y + 3*size/4)
  ctx:move_to(x + size/6, y + size/3)
  ctx:line_to(x + 5*size/6, y + size/3)
  ctx:move_to(x + size/6, y + 2*size/3)
  ctx:line_to(x + 5*size/6, y + 2*size/3)
  ctx:stroke()
end

function PakettiCanvasFontDrawPlus(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x + size/2, y + size/4)
  ctx:line_to(x + size/2, y + 3*size/4)
  ctx:move_to(x + size/4, y + size/2)
  ctx:line_to(x + 3*size/4, y + size/2)
  ctx:stroke()
end

function PakettiCanvasFontDrawColon(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x + size/2, y + size/3)
  ctx:line_to(x + size/2, y + size/3 + 1)
  ctx:move_to(x + size/2, y + 2*size/3)
  ctx:line_to(x + size/2, y + 2*size/3 + 1)
  ctx:stroke()
end

function PakettiCanvasFontDrawSemicolon(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x + size/2, y + size/3)
  ctx:line_to(x + size/2, y + size/3 + 1)
  ctx:move_to(x + size/2, y + 2*size/3)
  ctx:line_to(x + size/2, y + 2*size/3 + 1)
  ctx:move_to(x + size/2, y + 2*size/3 + 1)
  ctx:line_to(x + size/2 - 2, y + 2*size/3 + 3)
  ctx:stroke()
end

function PakettiCanvasFontDrawExclamation(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x + size/2, y)
  ctx:line_to(x + size/2, y + 3*size/4)
  ctx:move_to(x + size/2, y + size)
  ctx:line_to(x + size/2, y + size - 2)
  ctx:stroke()
end

function PakettiCanvasFontDrawQuestion(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y + size/4)
  ctx:line_to(x + size/2, y)
  ctx:line_to(x + size, y + size/4)
  ctx:line_to(x + size/2, y + size/2)
  ctx:line_to(x + size/2, y + 3*size/4)
  ctx:move_to(x + size/2, y + size)
  ctx:line_to(x + size/2, y + size - 2)
  ctx:stroke()
end

function PakettiCanvasFontDrawSlash(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y + size)
  ctx:line_to(x + size, y)
  ctx:stroke()
end

function PakettiCanvasFontDrawBackslash(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y)
  ctx:line_to(x + size, y + size)
  ctx:stroke()
end

function PakettiCanvasFontDrawAmpersand(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x + size, y + size/4)
  ctx:line_to(x + size/2, y)
  ctx:line_to(x, y + size/4)
  ctx:line_to(x + size/2, y + size/2)
  ctx:line_to(x, y + size)
  ctx:line_to(x + size/2, y + 3*size/4)
  ctx:line_to(x + size, y + size)
  ctx:stroke()
end

function PakettiCanvasFontDrawParenLeft(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x + 3*size/4, y)
  ctx:line_to(x + size/3, y + size/4)
  ctx:line_to(x + size/3, y + 3*size/4)
  ctx:line_to(x + 3*size/4, y + size)
  ctx:stroke()
end

function PakettiCanvasFontDrawParenRight(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x + size/4, y)
  ctx:line_to(x + 2*size/3, y + size/4)
  ctx:line_to(x + 2*size/3, y + 3*size/4)
  ctx:line_to(x + size/4, y + size)
  ctx:stroke()
end

function PakettiCanvasFontDrawPercent(ctx, x, y, size)
  local s3 = size/3
  ctx:begin_path()
  ctx:move_to(x, y + size)
  ctx:line_to(x + size, y)
  -- top-left small box
  ctx:move_to(x, y)
  ctx:line_to(x + s3, y)
  ctx:line_to(x + s3, y + s3)
  ctx:line_to(x, y + s3)
  ctx:line_to(x, y)
  -- bottom-right small box
  ctx:move_to(x + 2*s3, y + 2*s3)
  ctx:line_to(x + size, y + 2*s3)
  ctx:line_to(x + size, y + size)
  ctx:line_to(x + 2*s3, y + size)
  ctx:line_to(x + 2*s3, y + 2*s3)
  ctx:stroke()
end

function PakettiCanvasFontDrawDoubleQuote(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x + size/3, y)
  ctx:line_to(x + size/3, y + size/3)
  ctx:move_to(x + 2*size/3, y)
  ctx:line_to(x + 2*size/3, y + size/3)
  ctx:stroke()
end

function PakettiCanvasFontDrawSingleQuote(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x + size/2, y)
  ctx:line_to(x + size/2, y + size/3)
  ctx:stroke()
end

function PakettiCanvasFontDrawCaret(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y + size/2)
  ctx:line_to(x + size/2, y)
  ctx:line_to(x + size, y + size/2)
  ctx:stroke()
end

function PakettiCanvasFontDrawLess(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x + size, y)
  ctx:line_to(x, y + size/2)
  ctx:line_to(x + size, y + size)
  ctx:stroke()
end

function PakettiCanvasFontDrawGreater(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y)
  ctx:line_to(x + size, y + size/2)
  ctx:line_to(x, y + size)
  ctx:stroke()
end

-- EXTENDED GLYPHS -----------------------------------------------------
-- Scandinavian letters: ä ö å (lowercase and uppercase forms)
local function draw_umlaut_bars(ctx, x, y, size)
  local dot = math.max(1, math.floor(size/6))
  ctx:begin_path()
  ctx:move_to(x + size/3, y - dot)
  ctx:line_to(x + size/3, y)
  ctx:move_to(x + 2*size/3, y - dot)
  ctx:line_to(x + 2*size/3, y)
  ctx:stroke()
end

function PakettiCanvasFontDrawLowerA_Umlaut(ctx, x, y, size)
  PakettiCanvasFontDrawLetterA(ctx, x, y, size)
  draw_umlaut_bars(ctx, x, y, size)
end

function PakettiCanvasFontDrawLowerO_Umlaut(ctx, x, y, size)
  PakettiCanvasFontDrawLetterO(ctx, x, y, size)
  draw_umlaut_bars(ctx, x, y, size)
end

function PakettiCanvasFontDrawLowerA_Ring(ctx, x, y, size)
  PakettiCanvasFontDrawLetterA(ctx, x, y, size)
  local r = math.max(1, math.floor(size/5))
  ctx:begin_path()
  ctx:move_to(x + size/2 - r, y - r)
  ctx:line_to(x + size/2 + r, y - r)
  ctx:line_to(x + size/2 + r, y + r)
  ctx:line_to(x + size/2 - r, y + r)
  ctx:line_to(x + size/2 - r, y - r)
  ctx:stroke()
end

-- Symbols: = and §
function PakettiCanvasFontDrawEquals(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y + size/3)
  ctx:line_to(x + size, y + size/3)
  ctx:move_to(x, y + 2*size/3)
  ctx:line_to(x + size, y + 2*size/3)
  ctx:stroke()
end

function PakettiCanvasFontDrawSection(ctx, x, y, size)
  -- Stylized § using stacked S-like segments
  ctx:begin_path()
  ctx:move_to(x + size, y + size/6)
  ctx:line_to(x + size/3, y)
  ctx:line_to(x, y + size/3)
  ctx:line_to(x + 2*size/3, y + size/2)
  ctx:line_to(x, y + 2*size/3)
  ctx:line_to(x + size/3, y + size)
  ctx:line_to(x + size, y + 5*size/6)
  ctx:stroke()
end

-- Mac modifier glyphs (approximate line forms)
function PakettiCanvasFontDrawCommand(ctx, x, y, size)
  -- Four rounded loops like ⌘ approximated with lines
  local s = size
  ctx:begin_path()
  ctx:move_to(x + s/3, y)
  ctx:line_to(x + s/3, y + s/3)
  ctx:line_to(x, y + s/3)
  ctx:line_to(x, y)
  ctx:move_to(x + 2*s/3, y)
  ctx:line_to(x + 2*s/3, y + s/3)
  ctx:line_to(x + s, y + s/3)
  ctx:line_to(x + s, y)
  ctx:move_to(x + s/3, y + s)
  ctx:line_to(x + s/3, y + 2*s/3)
  ctx:line_to(x, y + 2*s/3)
  ctx:line_to(x, y + s)
  ctx:move_to(x + 2*s/3, y + s)
  ctx:line_to(x + 2*s/3, y + 2*s/3)
  ctx:line_to(x + s, y + 2*s/3)
  ctx:line_to(x + s, y + s)
  ctx:stroke()
end

function PakettiCanvasFontDrawOption(ctx, x, y, size)
  -- Like ⌥: a slanted top line with a vertical bar
  ctx:begin_path()
  ctx:move_to(x, y + size/3)
  ctx:line_to(x + size/2, y + size/3)
  ctx:line_to(x + size, y)
  ctx:move_to(x + size/2, y + size)
  ctx:line_to(x + size/2, y + size/3)
  ctx:stroke()
end

function PakettiCanvasFontDrawControl(ctx, x, y, size)
  -- Like ⌃: a simple caret-shape centered
  PakettiCanvasFontDrawCaret(ctx, x, y, size)
end

function PakettiCanvasFontDrawShift(ctx, x, y, size)
  -- Like ⇧: an up arrow with bar
  ctx:begin_path()
  ctx:move_to(x + size/2, y)
  ctx:line_to(x, y + size/2)
  ctx:line_to(x + size/3, y + size/2)
  ctx:move_to(x + size/2, y)
  ctx:line_to(x + size, y + size/2)
  ctx:line_to(x + 2*size/3, y + size/2)
  ctx:move_to(x + size/3, y + size/2)
  ctx:line_to(x + size/3, y + size)
  ctx:move_to(x + 2*size/3, y + size/2)
  ctx:line_to(x + 2*size/3, y + size)
  ctx:stroke()
end

-- Arrows and Return glyph
function PakettiCanvasFontDrawArrowUp(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x + size/2, y)
  ctx:line_to(x, y + size/2)
  ctx:move_to(x + size/2, y)
  ctx:line_to(x + size, y + size/2)
  ctx:move_to(x + size/2, y)
  ctx:line_to(x + size/2, y + size)
  ctx:stroke()
end

function PakettiCanvasFontDrawArrowDown(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x + size/2, y + size)
  ctx:line_to(x, y + size/2)
  ctx:move_to(x + size/2, y + size)
  ctx:line_to(x + size, y + size/2)
  ctx:move_to(x + size/2, y)
  ctx:line_to(x + size/2, y + size)
  ctx:stroke()
end

function PakettiCanvasFontDrawArrowLeft(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y + size/2)
  ctx:line_to(x + size/2, y)
  ctx:move_to(x, y + size/2)
  ctx:line_to(x + size/2, y + size)
  ctx:move_to(x, y + size/2)
  ctx:line_to(x + size, y + size/2)
  ctx:stroke()
end

function PakettiCanvasFontDrawArrowRight(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x + size, y + size/2)
  ctx:line_to(x + size/2, y)
  ctx:move_to(x + size, y + size/2)
  ctx:line_to(x + size/2, y + size)
  ctx:move_to(x, y + size/2)
  ctx:line_to(x + size, y + size/2)
  ctx:stroke()
end

function PakettiCanvasFontDrawReturn(ctx, x, y, size)
  -- Like ↩: rightwards then down and back left
  ctx:begin_path()
  ctx:move_to(x, y + size/3)
  ctx:line_to(x + size, y + size/3)
  ctx:line_to(x + size, y + 2*size/3)
  ctx:line_to(x + size/3, y + 2*size/3)
  ctx:line_to(x + size/3, y + size)
  ctx:stroke()
end

-- LOOKUP -------------------------------------------------------------
PakettiCanvasFontLetterFunctions = {
  A = PakettiCanvasFontDrawLetterA, B = PakettiCanvasFontDrawLetterB, C = PakettiCanvasFontDrawLetterC,
  D = PakettiCanvasFontDrawLetterD, E = PakettiCanvasFontDrawLetterE, F = PakettiCanvasFontDrawLetterF,
  G = PakettiCanvasFontDrawLetterG, H = PakettiCanvasFontDrawLetterH, I = PakettiCanvasFontDrawLetterI,
  J = PakettiCanvasFontDrawLetterJ, K = PakettiCanvasFontDrawLetterK, L = PakettiCanvasFontDrawLetterL,
  M = PakettiCanvasFontDrawLetterM, N = PakettiCanvasFontDrawLetterN, O = PakettiCanvasFontDrawLetterO,
  P = PakettiCanvasFontDrawLetterP, Q = PakettiCanvasFontDrawLetterQ, R = PakettiCanvasFontDrawLetterR,
  S = PakettiCanvasFontDrawLetterS, T = PakettiCanvasFontDrawLetterT, U = PakettiCanvasFontDrawLetterU,
  V = PakettiCanvasFontDrawLetterV, W = PakettiCanvasFontDrawLetterW, X = PakettiCanvasFontDrawLetterX,
  Y = PakettiCanvasFontDrawLetterY, Z = PakettiCanvasFontDrawLetterZ,
  ["0"] = PakettiCanvasFontDrawDigit0, ["1"] = PakettiCanvasFontDrawDigit1, ["2"] = PakettiCanvasFontDrawDigit2,
  ["3"] = PakettiCanvasFontDrawDigit3, ["4"] = PakettiCanvasFontDrawDigit4, ["5"] = PakettiCanvasFontDrawDigit5,
  ["6"] = PakettiCanvasFontDrawDigit6, ["7"] = PakettiCanvasFontDrawDigit7, ["8"] = PakettiCanvasFontDrawDigit8,
  ["9"] = PakettiCanvasFontDrawDigit9,
  [" "] = PakettiCanvasFontDrawSpace, ["."] = PakettiCanvasFontDrawDot, [","] = PakettiCanvasFontDrawComma,
  ["_"] = PakettiCanvasFontDrawUnderscore, ["-"] = PakettiCanvasFontDrawDash, ["#"] = PakettiCanvasFontDrawHash,
  ["+"] = PakettiCanvasFontDrawPlus, [":"] = PakettiCanvasFontDrawColon, [";"] = PakettiCanvasFontDrawSemicolon,
  ["!"] = PakettiCanvasFontDrawExclamation, ["?"] = PakettiCanvasFontDrawQuestion, ["/"] = PakettiCanvasFontDrawSlash,
  ["\\"] = PakettiCanvasFontDrawBackslash, ["&"] = PakettiCanvasFontDrawAmpersand, ["("] = PakettiCanvasFontDrawParenLeft,
  [")"] = PakettiCanvasFontDrawParenRight, ["%"] = PakettiCanvasFontDrawPercent, ['"'] = PakettiCanvasFontDrawDoubleQuote,
  ["'"] = PakettiCanvasFontDrawSingleQuote, ["^"] = PakettiCanvasFontDrawCaret, ["<"] = PakettiCanvasFontDrawLess,
  [">"] = PakettiCanvasFontDrawGreater,
  -- Extended
  ["ä"] = PakettiCanvasFontDrawLowerA_Umlaut, ["Ä"] = PakettiCanvasFontDrawLowerA_Umlaut,
  ["ö"] = PakettiCanvasFontDrawLowerO_Umlaut, ["Ö"] = PakettiCanvasFontDrawLowerO_Umlaut,
  ["å"] = PakettiCanvasFontDrawLowerA_Ring,   ["Å"] = PakettiCanvasFontDrawLowerA_Ring,
  ["="] = PakettiCanvasFontDrawEquals, ["§"] = PakettiCanvasFontDrawSection,
  ["⌘"] = PakettiCanvasFontDrawCommand, ["⌥"] = PakettiCanvasFontDrawOption,
  ["⌃"] = PakettiCanvasFontDrawControl, ["⇧"] = PakettiCanvasFontDrawShift,
  ["↑"] = PakettiCanvasFontDrawArrowUp, ["↓"] = PakettiCanvasFontDrawArrowDown,
  ["←"] = PakettiCanvasFontDrawArrowLeft, ["→"] = PakettiCanvasFontDrawArrowRight,
  ["↩"] = PakettiCanvasFontDrawReturn
}

function PakettiCanvasFontGetLetterFunctions()
  return PakettiCanvasFontLetterFunctions
end

-- TEXT ---------------------------------------------------------------
function PakettiCanvasFontDrawText(ctx, text, x, y, size)
  local current_x = x
  local letter_spacing = size * 1.2
  local i = 1
  local n = #text
  while i <= n do
    local b = string.byte(text, i)
    local char = nil
    local advance = 1
    if not b then break end
    if b < 0x80 then
      char = string.sub(text, i, i)
      char = string.upper(char)
      advance = 1
    elseif b >= 0xE0 then
      -- 3-byte UTF-8
      if i + 2 <= n then
        char = string.sub(text, i, i + 2)
        advance = 3
      else
        char = string.sub(text, i, i)
        advance = 1
      end
    elseif b >= 0xC0 then
      -- 2-byte UTF-8 (covers ä ö å and uppercase variants)
      if i + 1 <= n then
        char = string.sub(text, i, i + 1)
        advance = 2
      else
        char = string.sub(text, i, i)
        advance = 1
      end
    else
      char = string.sub(text, i, i)
      advance = 1
    end
    local fn = PakettiCanvasFontLetterFunctions[char] or PakettiCanvasFontLetterFunctions[string.upper(char or "")]
    if fn then fn(ctx, current_x, y, size) end
    current_x = current_x + letter_spacing
    i = i + advance
  end
end

-- Draw text stacked vertically (top-to-bottom) without rotating glyphs
function PakettiCanvasFontDrawTextVertical(ctx, text, x, y, size)
  local current_y = y
  local letter_spacing = size + 4
  for i = 1, #text do
    local char = text:sub(i, i):upper()
    local fn = PakettiCanvasFontLetterFunctions[char]
    if fn then fn(ctx, x, current_y, size) end
    current_y = current_y + letter_spacing
  end
end

-- Orientation helper: orientation 1 = horizontal, 2 = vertical (stacked)
function PakettiCanvasFontDrawTextWithOrientation(ctx, text, x, y, size, orientation)
  if orientation == 2 then
    PakettiCanvasFontDrawTextVertical(ctx, text, x, y, size)
  else
    PakettiCanvasFontDrawText(ctx, text, x, y, size)
  end
end


