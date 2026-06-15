#!/bin/bash
# check_progress.sh — Bash Dungeon 进度检查脚本
# 用法：在游戏根目录下运行 ./check_progress.sh
# 通过检测目录/文件状态推断玩家进度，不依赖外部数据库

# ── 颜色定义 ──────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ── 定位游戏根目录（支持从任意子目录运行）──────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GAME_ROOT="$SCRIPT_DIR"

# 如果脚本在 Enter/ 内，向上找一级不算；以 Enter 目录存在为准
if [ -d "$GAME_ROOT/Enter" ]; then
    DUNGEON="$GAME_ROOT/Enter"
elif [ -d "$GAME_ROOT/../Enter" ]; then
    DUNGEON="$(cd "$GAME_ROOT/.." && pwd)/Enter"
else
    echo -e "${RED}错误：找不到 Enter 目录。请在游戏根目录内运行此脚本。${NC}"
    exit 1
fi

# ── 辅助函数 ──────────────────────────────────────────────
visited()   { echo -e "  ${GREEN}[✓]${NC} $1"; }
locked()    { echo -e "  ${RED}[✗]${NC} $1"; }
current()   { echo -e "  ${YELLOW}[▶]${NC} $1 ${BOLD}← 当前位置${NC}"; }

has_file() {
    local dir="$1" name="$2"
    [ -e "$dir/$name" ] || [ -L "$dir/$name" ]
}

dir_visible() {
    # 若隐藏目录已被重命名为可见（不以.开头），则视为已解锁
    local parent="$1" hidden_name="$2"
    local visible_name="${hidden_name#.}"
    [ -d "$parent/$visible_name" ]
}

dir_hidden() {
    # 若隐藏目录仍以.开头存在，则视为未解锁
    local parent="$1" hidden_name="$2"
    [ -d "$parent/$hidden_name" ]
}

# ── 区域路径定义 ──────────────────────────────────────────
CORRIDOR="$DUNGEON/corridor"
FIRST_CHAMBER_H=".first_chamber"
SECOND_CHAMBER_H=".2nd_chamber"
GARDEN_H=".garden_of_mitra"
PS1_H=".PS1"
ROOM1_H=".room1"
SHOP_H=".shop"
ROOM2_H=".room2"
CHAMBER_OF_LOSS_H=".chamber_of_loss"

# ── 开始检测 ──────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║      🏰 Bash Dungeon 进度报告 🏰       ║${NC}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════╝${NC}"
echo ""

# ─────────────────────────────────────────────────────────
echo -e "${BOLD}【一、已访问区域】${NC}"
echo ""

# 起点
visited "入口 (Enter)"

# 走廊
if [ -d "$CORRIDOR" ]; then
    visited "走廊 (corridor)"
fi

# 逐层检测
PREV_LOC="$CORRIDOR"
NEXT_HIDDEN="$FIRST_CHAMBER_H"
AREAS=(
    "first_chamber|第一密室 (.first_chamber)|$CORRIDOR|$FIRST_CHAMBER_H"
    "2nd_chamber|第二密室 (.2nd_chamber)|\$prev|$SECOND_CHAMBER_H"
    "garden_of_mitra|密特拉花园 (.garden_of_mitra)|\$prev|$GARDEN_H"
    "PS1|PS1之房 (.PS1)|\$prev_garden|$PS1_H"
    "room1|房间一 (.room1)|\$prev_garden|$ROOM1_H"
    "shop|商店 (.shop)|\$prev_room1|$SHOP_H"
    "room2|房间二 (.room2)|\$prev_shop|$ROOM2_H"
    "chamber_of_loss|失落密室 (.chamber_of_loss)|\$prev_room2|$CHAMBER_OF_LOSS_H"
)

# 手动逐级检测以保持路径准确
declare -a UNLOCKED_AREAS=()
declare -a LOCKED_AREAS=()
CURRENT_AREA=""

# Level 1: first_chamber (parent = corridor)
P="$CORRIDOR"
if dir_visible "$P" "$FIRST_CHAMBER_H"; then
    UNLOCKED_AREAS+=("第一密室 (first_chamber)")
    FC="$P/first_chamber"
    # Level 2: 2nd_chamber
    if dir_visible "$FC" "$SECOND_CHAMBER_H"; then
        UNLOCKED_AREAS+=("第二密室 (2nd_chamber)")
        SC="$FC/2nd_chamber"
        # Level 3: garden_of_mitra
        if dir_visible "$SC" "$GARDEN_H"; then
            UNLOCKED_AREAS+=("密特拉花园 (garden_of_mitra)")
            GM="$SC/garden_of_mitra"
            # Level 3a: PS1
            if dir_visible "$GM" "$PS1_H"; then
                UNLOCKED_AREAS+=("PS1 之房")
            else
                LOCKED_AREAS+=("PS1 之房 (.PS1)")
            fi
            # Level 4: room1
            if dir_visible "$GM" "$ROOM1_H"; then
                UNLOCKED_AREAS+=("房间一 (room1)")
                R1="$GM/room1"
                # Level 5: shop
                if dir_visible "$R1" "$SHOP_H"; then
                    UNLOCKED_AREAS+=("商店 (shop)")
                    SH="$R1/shop"
                    # Level 6: room2
                    if dir_visible "$SH" "$ROOM2_H"; then
                        UNLOCKED_AREAS+=("房间二 (room2)")
                        R2="$SH/room2"
                        # Level 7: chamber_of_loss
                        if dir_visible "$R2" "$CHAMBER_OF_LOSS_H"; then
                            UNLOCKED_AREAS+=("失落密室 (chamber_of_loss)")
                            COL="$R2/chamber_of_loss"
                            CURRENT_AREA="失落密室"
                        else
                            LOCKED_AREAS+=("失落密室 (.chamber_of_loss)")
                            CURRENT_AREA="房间二"
                        fi
                    else
                        LOCKED_AREAS+=("房间二 (.room2)")
                        CURRENT_AREA="商店"
                    fi
                else
                    LOCKED_AREAS+=("商店 (.shop)")
                    LOCKED_AREAS+=("房间二 (.room2)")
                    LOCKED_AREAS+=("失落密室 (.chamber_of_loss)")
                    CURRENT_AREA="房间一"
                fi
            else
                LOCKED_AREAS+=("房间一 (.room1)")
                LOCKED_AREAS+=("商店 (.shop)")
                LOCKED_AREAS+=("房间二 (.room2)")
                LOCKED_AREAS+=("失落密室 (.chamber_of_loss)")
                CURRENT_AREA="密特拉花园"
            fi
        else
            LOCKED_AREAS+=("密特拉花园 (.garden_of_mitra)")
            LOCKED_AREAS+=("PS1 之房 (.PS1)")
            LOCKED_AREAS+=("房间一 (.room1)")
            LOCKED_AREAS+=("商店 (.shop)")
            LOCKED_AREAS+=("房间二 (.room2)")
            LOCKED_AREAS+=("失落密室 (.chamber_of_loss)")
            CURRENT_AREA="第二密室"
        fi
    else
        LOCKED_AREAS+=("第二密室 (.2nd_chamber)")
        LOCKED_AREAS+=("密特拉花园 (.garden_of_mitra)")
        LOCKED_AREAS+=("PS1 之房 (.PS1)")
        LOCKED_AREAS+=("房间一 (.room1)")
        LOCKED_AREAS+=("商店 (.shop)")
        LOCKED_AREAS+=("房间二 (.room2)")
        LOCKED_AREAS+=("失落密室 (.chamber_of_loss)")
        CURRENT_AREA="第一密室"
    fi
else
    LOCKED_AREAS+=("第一密室 (.first_chamber)")
    LOCKED_AREAS+=("第二密室 (.2nd_chamber)")
    LOCKED_AREAS+=("密特拉花园 (.garden_of_mitra)")
    LOCKED_AREAS+=("PS1 之房 (.PS1)")
    LOCKED_AREAS+=("房间一 (.room1)")
    LOCKED_AREAS+=("商店 (.shop)")
    LOCKED_AREAS+=("房间二 (.room2)")
    LOCKED_AREAS+=("失落密室 (.chamber_of_loss)")
    CURRENT_AREA="走廊"
fi

for area in "${UNLOCKED_AREAS[@]}"; do
    visited "$area"
done
echo -e "  ${YELLOW}[▶]${NC} ${BOLD}$CURRENT_AREA${NC} ${CYAN}← 当前区域${NC}"
for area in "${LOCKED_AREAS[@]}"; do
    locked "$area"
done

TOTAL_AREAS=10  # Enter + corridor + 8 hidden
UNLOCKED_COUNT=$(( ${#UNLOCKED_AREAS[@]} + 2 ))  # +Enter +corridor
echo ""
echo -e "  探索进度：${BOLD}$UNLOCKED_COUNT / $TOTAL_AREAS${NC} 区域"

# ─────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}【二、已获得的关键物品】${NC}"
echo ""

ITEM_COUNT=0

# 检查文件型物品（通过游戏过程中生成的文件判断）
check_item() {
    local label="$1" found=0
    shift
    for path in "$@"; do
        if [ -e "$path" ] || [ -L "$path" ]; then
            found=1
            break
        fi
    done
    if [ $found -eq 1 ]; then
        visited "$label"
        ((ITEM_COUNT++))
    else
        locked "$label"
    fi
}

# 色彩护符：通过运行走廊中的 chest 获得（表现为 first_chamber 被解锁）
if dir_visible "$CORRIDOR" "$FIRST_CHAMBER_H"; then
    visited "色彩护符 (amulet of color)"
    ((ITEM_COUNT++))
else
    locked "色彩护符 (amulet of color) — 运行走廊中的 ./chest"
fi

# short_sword: rat 被杀后 first_chamber 解锁，检查 rat_remains 或目录可见
if dir_visible "$CORRIDOR" "$FIRST_CHAMBER_H"; then
    FC_PATH="$CORRIDOR/first_chamber"
    if [ -e "$FC_PATH/rat_remains" ] || has_file "$FC_PATH" "rat_remains"; then
        visited "短剑 (short_sword)"
        ((ITEM_COUNT++))
    else
        locked "短剑 (short_sword) — 击败老鼠后获得"
    fi
else
    locked "短剑 (short_sword) — 第一密室"
fi

# long_sword: garden_of_mitra 可见即获得
if dir_visible "$CORRIDOR" "$FIRST_CHAMBER_H" && \
   dir_visible "$CORRIDOR/first_chamber" "$SECOND_CHAMBER_H" && \
   dir_visible "$CORRIDOR/first_chamber/2nd_chamber" "$GARDEN_H"; then
    visited "长剑 (long_sword)"
    ((ITEM_COUNT++))
else
    locked "长剑 (long_sword) — 密特拉花园"
fi

# 力量之言 (word_of_power): garden_of_mitra
if dir_visible "$CORRIDOR" "$FIRST_CHAMBER_H" && \
   dir_visible "$CORRIDOR/first_chamber" "$SECOND_CHAMBER_H" && \
   dir_visible "$CORRIDOR/first_chamber/2nd_chamber" "$GARDEN_H"; then
    GM_PATH="$CORRIDOR/first_chamber/2nd_chamber/garden_of_mitra"
    if has_file "$GM_PATH" "word_of_power"; then
        visited "力量之言·花园版 (word_of_power)"
        ((ITEM_COUNT++))
    else
        locked "力量之言·花园版 (word_of_power)"
    fi
else
    locked "力量之言·花园版 (word_of_power) — 密特拉花园"
fi

# 知识卷轴: room1 chest 后
if dir_visible "$CORRIDOR" "$FIRST_CHAMBER_H" && \
   dir_visible "$CORRIDOR/first_chamber" "$SECOND_CHAMBER_H" && \
   dir_visible "$CORRIDOR/first_chamber/2nd_chamber" "$GARDEN_H" && \
   dir_visible "$CORRIDOR/first_chamber/2nd_chamber/garden_of_mitra" "$ROOM1_H" && \
   dir_visible "$CORRIDOR/first_chamber/2nd_chamber/garden_of_mitra/room1" "$SHOP_H"; then
    visited "知识卷轴·房间一版 (scroll_of_knowledge)"
    ((ITEM_COUNT++))
else
    locked "知识卷轴·房间一版 (scroll_of_knowledge) — 房间一宝箱"
fi

# 商店物品检测（通过 shop 目录可见 + 特定文件存在）
if dir_visible "$CORRIDOR" "$FIRST_CHAMBER_H" && \
   dir_visible "$CORRIDOR/first_chamber" "$SECOND_CHAMBER_H" && \
   dir_visible "$CORRIDOR/first_chamber/2nd_chamber" "$GARDEN_H" && \
   dir_visible "$CORRIDOR/first_chamber/2nd_chamber/garden_of_mitra" "$ROOM1_H" && \
   dir_visible "$CORRIDOR/first_chamber/2nd_chamber/garden_of_mitra/room1" "$SHOP_H"; then
    SHOP_PATH="$CORRIDOR/first_chamber/2nd_chamber/garden_of_mitra/room1/shop"
    check_item "飞镖 (dart)" "$SHOP_PATH/dart"
    check_item "传送门 (portal)" "$SHOP_PATH/portal"
    check_item "戏法卷轴 (trick)" "$SHOP_PATH/trick"
else
    locked "飞镖 (dart) — 商店"
    locked "传送门 (portal) — 商店"
    locked "戏法卷轴 (trick) — 商店"
fi

# 函数教程文件 (functions) — vault 解谜后生成
if dir_visible "$CORRIDOR" "$FIRST_CHAMBER_H" && \
   dir_visible "$CORRIDOR/first_chamber" "$SECOND_CHAMBER_H" && \
   dir_visible "$CORRIDOR/first_chamber/2nd_chamber" "$GARDEN_H" && \
   dir_visible "$CORRIDOR/first_chamber/2nd_chamber/garden_of_mitra" "$ROOM1_H" && \
   dir_visible "$CORRIDOR/first_chamber/2nd_chamber/garden_of_mitra/room1" "$SHOP_H" && \
   dir_visible "$CORRIDOR/first_chamber/2nd_chamber/garden_of_mitra/room1/shop" "$ROOM2_H" && \
   dir_visible "$CORRIDOR/first_chamber/2nd_chamber/garden_of_mitra/room1/shop/room2" "$CHAMBER_OF_LOSS_H"; then
    R2_PATH="$CORRIDOR/first_chamber/2nd_chamber/garden_of_mitra/room1/shop/room2"
    if has_file "$R2_PATH" "functions"; then
        visited "函数教程 (functions)"
        ((ITEM_COUNT++))
    else
        locked "函数教程 (functions) — 解开 vault 谜题"
    fi
else
    locked "函数教程 (functions) — 房间二 vault"
fi

# 力量之言·密室版
if dir_visible "$CORRIDOR" "$FIRST_CHAMBER_H" && \
   dir_visible "$CORRIDOR/first_chamber" "$SECOND_CHAMBER_H" && \
   dir_visible "$CORRIDOR/first_chamber/2nd_chamber" "$GARDEN_H" && \
   dir_visible "$CORRIDOR/first_chamber/2nd_chamber/garden_of_mitra" "$ROOM1_H" && \
   dir_visible "$CORRIDOR/first_chamber/2nd_chamber/garden_of_mitra/room1" "$SHOP_H" && \
   dir_visible "$CORRIDOR/first_chamber/2nd_chamber/garden_of_mitra/room1/shop" "$ROOM2_H" && \
   dir_visible "$CORRIDOR/first_chamber/2nd_chamber/garden_of_mitra/room1/shop/room2" "$CHAMBER_OF_LOSS_H"; then
    COL_PATH="$CORRIDOR/first_chamber/2nd_chamber/garden_of_mitra/room1/shop/room2/chamber_of_loss"
    if has_file "$COL_PATH" "word_of_power"; then
        visited "力量之言·密室版 (word_of_power)"
        ((ITEM_COUNT++))
    else
        locked "力量之言·密室版 (word_of_power)"
    fi
else
    locked "力量之言·密室版 (word_of_power) — 失落密室"
fi

TOTAL_ITEMS=11
echo ""
echo -e "  收集进度：${BOLD}$ITEM_COUNT / $TOTAL_ITEMS${NC} 物品"

# ── 环境变量检测（仅在当前 shell 有效）─────────────────────
echo ""
echo -e "${BOLD}【三、环境变量状态（当前 Shell）】${NC}"
echo ""
echo -e "  ${CYAN}提示：环境变量仅在当前终端会话中有效，关闭终端后重置。${NC}"
echo ""

if [ -n "$I" ]; then
    echo -e "  ${GREEN}[✓]${NC} 背包 (\$I)：${BOLD}$I${NC}"
else
    echo -e "  ${YELLOW}[—]${NC} 背包 (\$I)：未设置"
fi

if [ -n "$HP" ]; then
    echo -e "  ${GREEN}[✓]${NC} 生命值 (\$HP)：${BOLD}$HP${NC}"
else
    echo -e "  ${YELLOW}[—]${NC} 生命值 (\$HP)：未设置（花园中设为 100）"
fi

if [ -n "$gold" ]; then
    echo -e "  ${GREEN}[✓]${NC} 金币 (\$gold)：${BOLD}$gold${NC}"
else
    echo -e "  ${YELLOW}[—]${NC} 金币 (\$gold)：未设置"
fi

# ─────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}【四、下一步建议】${NC}"
echo ""

case "$CURRENT_AREA" in
    "走廊")
        echo -e "  ${CYAN}1.${NC} 阅读走廊中的羊皮卷（parchment），学习基本命令"
        echo -e "  ${CYAN}2.${NC} 运行 ${BOLD}./chest${NC} 获取色彩护符并解锁第一密室"
        echo -e "  ${CYAN}3.${NC} 进入 ${BOLD}cd first_chamber${NC} 继续探索"
        ;;
    "第一密室")
        echo -e "  ${CYAN}1.${NC} 设置武器：${BOLD}export I=short_sword${NC}"
        echo -e "  ${CYAN}2.${NC} 与老鼠战斗：${BOLD}./rat${NC}"
        echo -e "  ${CYAN}3.${NC} 击败后进入 ${BOLD}cd 2nd_chamber${NC}"
        ;;
    "第二密室")
        echo -e "  ${CYAN}1.${NC} 阅读 HINT 文件了解技巧"
        echo -e "  ${CYAN}2.${NC} 用 ${BOLD}cat poem | wc -l${NC} 数出诗的行数"
        echo -e "  ${CYAN}3.${NC} 运行 ${BOLD}./chest${NC} 并输入行数作为答案"
        ;;
    "密特拉花园")
        echo -e "  ${CYAN}1.${NC} 设置生命值：${BOLD}export HP=100${NC}"
        echo -e "  ${CYAN}2.${NC} 捡起长剑：${BOLD}export I=long_sword,\$I${NC}"
        echo -e "  ${CYAN}3.${NC} 运行 ${BOLD}./thorns${NC}，然后 ${BOLD}./potioneer poem${NC} 解锁新区域"
        echo -e "  ${CYAN}4.${NC} 探索 ${BOLD}cd PS1${NC} 和 ${BOLD}cd room1${NC}"
        ;;
    "房间一")
        echo -e "  ${CYAN}1.${NC} 用 ${BOLD}grep -i pass LoremIpsum${NC} 找出密码"
        echo -e "  ${CYAN}2.${NC} 运行 ${BOLD}./chest${NC} 并输入密码 ${BOLD}256${NC}"
        echo -e "  ${CYAN}3.${NC} 进入 ${BOLD}cd shop${NC} 访问商店"
        ;;
    "商店")
        echo -e "  ${CYAN}1.${NC} 用 ${BOLD}source ./shopkeeper${NC}（必须用 source！）打开商店"
        echo -e "  ${CYAN}2.${NC} 购买你需要的物品（飞镖、传送门等）"
        echo -e "  ${CYAN}3.${NC} 完成后进入 ${BOLD}cd room2${NC}"
        ;;
    "房间二")
        echo -e "  ${CYAN}1.${NC} 用 ${BOLD}echo \"237 / 3.1\" | bc -l${NC} 计算答案"
        echo -e "  ${CYAN}2.${NC} 运行 ${BOLD}./vault${NC} 并输入答案（约 76.4516...）"
        echo -e "  ${CYAN}3.${NC} 进入 ${BOLD}cd chamber_of_loss${NC}"
        ;;
    "失落密室")
        echo -e "  ${CYAN}1.${NC} 运行 ${BOLD}./lever${NC} 拉下操纵杆"
        echo -e "  ${CYAN}2.${NC} 学习 ${BOLD}rm${NC} 命令的危险性与安全替代方案"
        echo -e "  ${CYAN}3.${NC} 🎉 恭喜你已探索完当前所有内容！等待新区域开放。"
        ;;
esac

echo ""
echo -e "${BOLD}${CYAN}══════════════════════════════════════════${NC}"
echo -e "  ${CYAN}提示：在游戏目录内随时运行 ${BOLD}./check_progress.sh${NC} 查看进度"
echo -e "${BOLD}${CYAN}══════════════════════════════════════════${NC}"
echo ""
