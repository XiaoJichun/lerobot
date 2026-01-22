#!/usr/bin/env bash

# 设置颜色输出
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 加载动画函数
spinner() {
  local pid=$1
  local delay=0.1
  local spinstr='|/-\'
  while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
    local temp=${spinstr#?}
    printf " [%c]  " "$spinstr"
    local spinstr=$temp${spinstr%"$temp"}
    sleep $delay
    printf "\b\b\b\b\b\b"
  done
  printf "    \b\b\b\b"
}

# 显示帮助信息
show_help() {
  echo -e "${CYAN}ZSH 增强配置安装脚本${NC}"
  echo -e "用法: $0 [选项]"
  echo -e "选项:"
  echo -e "  ${GREEN}-h, --help${NC}      显示此帮助信息"
  echo -e "  ${GREEN}-c, --clean${NC}     清理现有配置后安装"
  echo -e "  ${GREEN}-u, --update${NC}    更新现有配置"
  echo -e "  ${GREEN}-t, --theme${NC} ${YELLOW}THEME${NC}  选择主题 (可选: p10k, pure, spaceship, agnoster, robbyrussell)"
  echo -e "  ${GREEN}-m, --minimal${NC}   安装最小配置（较少插件，更快）"
  echo -e "  ${GREEN}--no-fonts${NC}      不安装字体"
  echo -e "  ${GREEN}--no-tools${NC}      不安装额外工具(exa、bat等)"
  exit 0
}

# 默认设置
CLEAN_INSTALL=false
UPDATE_MODE=false
THEME="p10k"
MINIMAL=false
INSTALL_FONTS=true
INSTALL_TOOLS=true

# 解析命令行参数
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      show_help
      ;;
    -c|--clean)
      CLEAN_INSTALL=true
      shift
      ;;
    -u|--update)
      UPDATE_MODE=true
      shift
      ;;
    -t|--theme)
      THEME="$2"
      shift 2
      ;;
    -m|--minimal)
      MINIMAL=true
      shift
      ;;
    --no-fonts)
      INSTALL_FONTS=false
      shift
      ;;
    --no-tools)
      INSTALL_TOOLS=false
      shift
      ;;
    *)
      echo -e "${RED}未知选项: $1${NC}"
      show_help
      ;;
  esac
done

# 验证主题选择
case $THEME in
  p10k|pure|spaceship|agnoster|robbyrussell)
    ;;
  *)
    echo -e "${RED}不支持的主题: $THEME${NC}"
    echo -e "${YELLOW}支持的主题: p10k, pure, spaceship, agnoster, robbyrussell${NC}"
    exit 1
    ;;
esac

echo -e "${GREEN}=== 开始安装增强版zsh配置 ===${NC}"
echo -e "${BLUE}主题: ${THEME}${NC}"
echo -e "${BLUE}模式: $(if $MINIMAL; then echo "最小化"; else echo "完整"; fi)${NC}"
echo -e "${BLUE}安装字体: $(if $INSTALL_FONTS; then echo "是"; else echo "否"; fi)${NC}"
echo -e "${BLUE}安装工具: $(if $INSTALL_TOOLS; then echo "是"; else echo "否"; fi)${NC}"

# 如果是清理模式，卸载现有配置
if $CLEAN_INSTALL; then
  echo -e "${YELLOW}=== 清理现有zsh配置 ===${NC}"
  
  # 移除oh-my-zsh
  if [ -d ~/.oh-my-zsh ]; then
    echo -e "${YELLOW}移除 Oh My Zsh...${NC}"
    rm -rf ~/.oh-my-zsh
  fi
  
  # 移除插件目录
  if [ -d ~/.zsh ]; then
    echo -e "${YELLOW}移除 ~/.zsh 目录...${NC}"
    rm -rf ~/.zsh
  fi
  
  # 移除配置文件
  for config_file in ~/.zshrc ~/.zshrc.pre-oh-my-zsh ~/.p10k.zsh ~/.zsh_history; do
    if [ -f "$config_file" ]; then
      echo -e "${YELLOW}移除 $config_file...${NC}"
      rm -f "$config_file"
    fi
  done
  
  echo -e "${GREEN}清理完成!${NC}"
elif $UPDATE_MODE; then
  echo -e "${YELLOW}=== 更新模式 ===${NC}"
  
  # 更新oh-my-zsh
  if [ -d ~/.oh-my-zsh ]; then
    echo -e "${YELLOW}更新 Oh My Zsh...${NC}"
    cd ~/.oh-my-zsh && git pull
  fi
  
  # 更新插件
  for plugin_dir in ~/.oh-my-zsh/custom/plugins/*; do
    if [ -d "$plugin_dir/.git" ]; then
      echo -e "${YELLOW}更新插件 $(basename "$plugin_dir")...${NC}"
      cd "$plugin_dir" && git pull
    fi
  done
  
  # 更新主题
  for theme_dir in ~/.oh-my-zsh/custom/themes/*; do
    if [ -d "$theme_dir/.git" ]; then
      echo -e "${YELLOW}更新主题 $(basename "$theme_dir")...${NC}"
      cd "$theme_dir" && git pull
    fi
  done
  
  echo -e "${GREEN}更新完成! 您可能需要重启终端或执行 'source ~/.zshrc' 以应用更改${NC}"
  exit 0
fi

# 检查是否已安装zsh
if ! command -v zsh &> /dev/null; then
    echo -e "${YELLOW}未检测到zsh，正在安装...${NC}"
    if command -v apt &> /dev/null; then
        sudo apt update
        sudo apt install -y zsh
    elif command -v yum &> /dev/null; then
        sudo yum install -y zsh
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y zsh
    elif command -v pacman &> /dev/null; then
        sudo pacman -S --noconfirm zsh
    elif command -v brew &> /dev/null; then
        brew install zsh
    else
        echo -e "${RED}无法安装zsh，请手动安装后再运行此脚本${NC}"
        exit 1
    fi
fi

# 检查是否已安装git
if ! command -v git &> /dev/null; then
    echo -e "${YELLOW}未检测到git，正在安装...${NC}"
    if command -v apt &> /dev/null; then
        sudo apt update
        sudo apt install -y git
    elif command -v yum &> /dev/null; then
        sudo yum install -y git
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y git
    elif command -v pacman &> /dev/null; then
        sudo pacman -S --noconfirm git
    elif command -v brew &> /dev/null; then
        brew install git
    else
        echo -e "${RED}无法安装git，请手动安装后再运行此脚本${NC}"
        exit 1
    fi
fi

# 安装常用工具（exa, bat等）
if $INSTALL_TOOLS; then
    echo -e "${GREEN}=== 安装常用命令行工具 ===${NC}"
    
    # 根据不同的包管理器安装工具
    if command -v apt &> /dev/null; then
        echo -e "${YELLOW}使用apt安装工具...${NC}"
        # 部分工具可能需要添加外部仓库
        if ! command -v exa &> /dev/null; then
            echo -e "${YELLOW}尝试安装exa...${NC}"
            if apt-cache search --names-only '^exa$' | grep -q exa; then
                sudo apt install -y exa
            else
                echo -e "${YELLOW}无法通过包管理器安装exa，尝试下载二进制文件...${NC}"
                TMP_DIR=$(mktemp -d)
                curl -fsSL -o "$TMP_DIR/exa.zip" https://github.com/ogham/exa/releases/download/v0.10.1/exa-linux-x86_64-v0.10.1.zip
                sudo apt install unzip
                unzip -q "$TMP_DIR/exa.zip" -d "$TMP_DIR"
                sudo mv "$TMP_DIR/bin/exa" /usr/local/bin/
                rm -rf "$TMP_DIR"
            fi
        fi
        
        # 安装bat
        if ! command -v bat &> /dev/null && ! command -v batcat &> /dev/null; then
            echo -e "${YELLOW}安装bat...${NC}"
            sudo apt install -y bat
        fi
        
        # 安装其他有用的工具
        sudo apt install -y fd-find ripgrep ncdu htop tldr
        
    elif command -v yum &> /dev/null || command -v dnf &> /dev/null; then
        # 对于Fedora/RHEL/CentOS系统
        echo -e "${YELLOW}使用dnf/yum安装工具...${NC}"
        if command -v dnf &> /dev/null; then
            sudo dnf install -y exa bat fd-find ripgrep ncdu htop
        else
            sudo yum install -y epel-release
            sudo yum install -y bat ncdu htop
            
            # exa可能需要手动安装
            if ! command -v exa &> /dev/null; then
                echo -e "${YELLOW}exa不在主要仓库中，尝试使用cargo安装...${NC}"
                if ! command -v cargo &> /dev/null; then
                    sudo yum install -y rust cargo
                fi
                cargo install exa
            fi
        fi
        
    elif command -v pacman &> /dev/null; then
        # Arch Linux
        echo -e "${YELLOW}使用pacman安装工具...${NC}"
        sudo pacman -S --noconfirm exa bat fd ripgrep ncdu htop
        
    elif command -v brew &> /dev/null; then
        # macOS
        echo -e "${YELLOW}使用Homebrew安装工具...${NC}"
        brew install exa bat fd ripgrep ncdu htop tldr
    else
        echo -e "${YELLOW}无法确定包管理器，跳过工具安装${NC}"
        echo -e "${YELLOW}请手动安装以下工具: exa, bat, fd, ripgrep, ncdu, htop${NC}"
    fi
    
    echo -e "${GREEN}工具安装完成!${NC}"
fi

# 安装字体
if $INSTALL_FONTS; then
    echo -e "${GREEN}=== 安装推荐字体 ===${NC}"
    
    # 创建临时目录
    FONT_TEMP_DIR=$(mktemp -d)
    
    # 下载并安装Nerd Fonts (以Hack为例)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo -e "${YELLOW}在macOS上安装字体...${NC}"
        brew tap homebrew/cask-fonts
        brew install --cask font-hack-nerd-font
    else
        echo -e "${YELLOW}下载Hack Nerd Font...${NC}"
        curl -fsSL -o "$FONT_TEMP_DIR/Hack.zip" https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/Hack.zip
        
        echo -e "${YELLOW}解压字体文件...${NC}"
        mkdir -p "$FONT_TEMP_DIR/Hack"
        unzip -q "$FONT_TEMP_DIR/Hack.zip" -d "$FONT_TEMP_DIR/Hack"
        
        echo -e "${YELLOW}安装字体...${NC}"
        # 为Linux创建字体目录
        mkdir -p ~/.local/share/fonts
        
        # 复制字体文件
        cp "$FONT_TEMP_DIR/Hack/"*.ttf ~/.local/share/fonts/
        
        # 更新字体缓存
        if command -v fc-cache &> /dev/null; then
            echo -e "${YELLOW}更新字体缓存...${NC}"
            fc-cache -f -v &> /dev/null
        fi
    fi
    
    # 清理临时目录
    rm -rf "$FONT_TEMP_DIR"
    
    echo -e "${GREEN}字体安装完成!${NC}"
    echo -e "${YELLOW}请在您的终端模拟器中手动设置Hack Nerd Font字体以获得最佳图标显示效果${NC}"
fi

# 备份现有的.zshrc（如果不是清理模式且存在）
if [ -f ~/.zshrc ] && ! $CLEAN_INSTALL; then
    echo -e "${YELLOW}备份现有的.zshrc到~/.zshrc.bak.$(date +%Y%m%d_%H%M%S)${NC}"
    cp ~/.zshrc ~/.zshrc.bak.$(date +%Y%m%d_%H%M%S)
fi

# 安装Oh My Zsh
if [ ! -d ~/.oh-my-zsh ]; then
    echo -e "${GREEN}安装Oh My Zsh...${NC}"
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
    echo -e "${YELLOW}Oh My Zsh已安装，跳过...${NC}"
fi

# 克隆插件
echo -e "${GREEN}安装插件...${NC}"

# zsh-autosuggestions
if [ ! -d ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions ]; then
    echo -e "${YELLOW}安装 zsh-autosuggestions...${NC}"
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
fi

# zsh-syntax-highlighting
if [ ! -d ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting ]; then
    echo -e "${YELLOW}安装 zsh-syntax-highlighting...${NC}"
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
fi

# 安装更多插件（如果不是最小安装模式）
if ! $MINIMAL; then
    # zsh-completions
    if [ ! -d ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-completions ]; then
        echo -e "${YELLOW}安装 zsh-completions...${NC}"
        git clone https://github.com/zsh-users/zsh-completions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-completions
    fi
    
    # zsh-history-substring-search
    if [ ! -d ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-history-substring-search ]; then
        echo -e "${YELLOW}安装 zsh-history-substring-search...${NC}"
        git clone https://github.com/zsh-users/zsh-history-substring-search ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-history-substring-search
    fi
    
    # fzf-tab
    if [ ! -d ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/fzf-tab ]; then
        echo -e "${YELLOW}安装 fzf-tab...${NC}"
        git clone https://github.com/Aloxaf/fzf-tab ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/fzf-tab
    fi

    # 安装fzf命令行模糊查找器
    if ! command -v fzf &> /dev/null; then
        echo -e "${YELLOW}安装 fzf...${NC}"
        git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
        ~/.fzf/install --all &> /dev/null
    fi
    
    # 安装z快速跳转目录
    if [ ! -d ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-z ]; then
        echo -e "${YELLOW}安装 zsh-z...${NC}"
        git clone https://github.com/agkozak/zsh-z ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-z
    fi
fi

# 安装所选主题
case $THEME in
  p10k)
    if [ ! -d ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k ]; then
        echo -e "${GREEN}安装Powerlevel10k主题...${NC}"
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
    fi
    
    # 创建p10k配置文件
    if [ ! -f ~/.p10k.zsh ]; then
        echo -e "${GREEN}创建Powerlevel10k配置文件...${NC}"
        curl -fsSL https://raw.githubusercontent.com/romkatv/powerlevel10k/master/config/p10k-rainbow.zsh > ~/.p10k.zsh
    fi
    ;;
    
  pure)
    if [ ! -d ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/pure ]; then
        echo -e "${GREEN}安装Pure主题...${NC}"
        mkdir -p ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/pure
        git clone https://github.com/sindresorhus/pure.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/pure
        ln -sf ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/pure/pure.zsh ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/pure.zsh-theme
    fi
    ;;
    
  spaceship)
    if [ ! -d ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/spaceship-prompt ]; then
        echo -e "${GREEN}安装Spaceship主题...${NC}"
        git clone https://github.com/spaceship-prompt/spaceship-prompt.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/spaceship-prompt --depth=1
        ln -sf ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/spaceship-prompt/spaceship.zsh-theme ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/spaceship.zsh-theme
    fi
    ;;
    
  *)
    # Agnoster和robbyrussell已包含在oh-my-zsh中
    echo -e "${GREEN}使用 $THEME 主题（Oh My Zsh 内置）${NC}"
    ;;
esac

# 创建.zshrc配置文件
echo -e "${GREEN}创建自定义.zshrc配置文件...${NC}"

# 选择插件列表，基于是否为最小安装
if $MINIMAL; then
    PLUGINS_LIST="git zsh-autosuggestions zsh-syntax-highlighting"
else
    PLUGINS_LIST="git docker docker-compose zsh-autosuggestions zsh-syntax-highlighting zsh-completions history-substring-search zsh-z extract sudo command-not-found colored-man-pages copypath copyfile dirhistory fzf-tab npm python pip"
fi

# 选择主题设置
case $THEME in
  p10k)
    THEME_CONFIG="ZSH_THEME=\"powerlevel10k/powerlevel10k\"\n\n# Powerlevel10k主题设置\n[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh\n\n# 启用Powerlevel10k即时提示\nif [[ -r \"\${XDG_CACHE_HOME:-\$HOME/.cache}/p10k-instant-prompt-\${(%):-%n}.zsh\" ]]; then\n  source \"\${XDG_CACHE_HOME:-\$HOME/.cache}/p10k-instant-prompt-\${(%):-%n}.zsh\"\nfi"
    ;;
  pure)
    THEME_CONFIG="ZSH_THEME=\"\"\n\n# Pure主题设置\nfpath+=(\${ZSH_CUSTOM:-\$HOME/.oh-my-zsh/custom}/themes/pure)\nautoload -U promptinit; promptinit\nprompt pure"
    ;;
  spaceship)
    THEME_CONFIG="ZSH_THEME=\"spaceship\"\n\n# Spaceship主题配置\nSPACESHIP_PROMPT_ORDER=(\n  time\n  user\n  host\n  dir\n  git\n  node\n  ruby\n  python\n  docker\n  line_sep\n  char\n)"
    ;;
  *)
    THEME_CONFIG="ZSH_THEME=\"$THEME\""
    ;;
esac

cat > ~/.zshrc << EOL
# 如果终端不在交互模式下，直接退出
[ -z "\$PS1" ] && return

# Oh My Zsh路径
export ZSH="\$HOME/.oh-my-zsh"

# 主题设置
$(echo -e $THEME_CONFIG)

# 插件列表
plugins=(
  $PLUGINS_LIST
)

source \$ZSH/oh-my-zsh.sh

# 用户配置
export LANG=en_US.UTF-8

# 确保终端支持256色
export TERM="xterm-256color"

# 别名
alias ls='ls --color=auto'
alias ll='ls -alF'
alias la='ls -a'
alias l='ls -CF'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias c='clear'
alias h='history'
alias update='sudo apt update && sudo apt upgrade -y'
alias zshconfig="vim ~/.zshrc"
alias ohmyzsh="vim ~/.oh-my-zsh"
alias myip="curl http://ipecho.net/plain; echo"
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias dl='cd ~/Downloads'
alias dc='cd ~/Documents'
alias gs='git status'
alias ga='git add'
alias gc='git commit -m'
alias gp='git push'
alias gpl='git pull'
alias gl='git log --oneline --graph --decorate'

# 历史记录设置
HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.zsh_history
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS
setopt SHARE_HISTORY
setopt HIST_VERIFY

# 自动补全设置
autoload -Uz compinit
compinit
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' menu select
zstyle ':completion:*' list-colors "\${(s.:.)LS_COLORS}"
zstyle ':completion:*' special-dirs true
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%F{yellow}-- %d --%f'

# 目录跳转快捷键
setopt AUTO_CD
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt PUSHD_SILENT
setopt PUSHD_TO_HOME

# 额外的键绑定
bindkey '^[[A' history-beginning-search-backward
bindkey '^[[B' history-beginning-search-forward
bindkey "^[[1;5C" forward-word
bindkey "^[[1;5D" backward-word
bindkey '^H' backward-kill-word

# 自定义函数
# 创建目录并进入
function mkcd() {
  mkdir -p "\$1" && cd "\$1"
}

# 把当前目录下的文件按修改时间排序
function lt() {
  ls -alht "\$@" | head -n 20
}

# 从当前目录查找文件
function ff() {
  find . -type f -name "*\$1*"
}

# 显示当前git仓库所有提交者及其提交次数
function git_stats() {
  git log --pretty=format:%an | sort | uniq -c | sort -rn
}

# 备份文件
function bak() {
  cp "\$1"{,.bak}
}

# 解压任何归档文件
function extract() {
  if [ -f \$1 ] ; then
    case \$1 in
      *.tar.bz2)   tar xjf \$1     ;;
      *.tar.gz)    tar xzf \$1     ;;
      *.bz2)       bunzip2 \$1     ;;
      *.rar)       unrar e \$1     ;;
      *.gz)        gunzip \$1      ;;
      *.tar)       tar xf \$1      ;;
      *.tbz2)      tar xjf \$1     ;;
      *.tgz)       tar xzf \$1     ;;
      *.zip)       unzip \$1       ;;
      *.Z)         uncompress \$1  ;;
      *.7z)        7z x \$1        ;;
      *)           echo "'\$1' 无法解压" ;;
    esac
  else
    echo "'\$1' 不是有效的文件"
  fi
}

# 快速查看CPU信息
function cpuinfo() {
  lscpu | grep -E '^Thread|^Core|^Socket|^CPU\(' | sort
}

# HTTP服务器 - 在当前目录启动一个HTTP服务器
function server() {
  local port="\${1:-8000}"
  python -m SimpleHTTPServer \$port 2>/dev/null || python3 -m http.server \$port
}

# 查看天气
function weather() {
  curl -s "wttr.in/\${1:-}"
}

# 查找大文件
function findlarge() {
  find . -type f -size +\${1:-100M} -exec ls -lh {} \; | sort -k5 -rh
}

# 显示目录大小
function dirsize() {
  du -sh \${1:-.}/*
}

# 快速查找历史命令
function hs() {
  history | grep "\$1"
}

# fzf集成，如果已安装
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# 其他集成
# batcat更好的cat替代品，如果已安装
if command -v batcat &>/dev/null; then
  alias cat='batcat --paging=never'
elif command -v bat &>/dev/null; then
  alias cat='bat --paging=never'
fi

# 使用exa替代ls，如果已安装
if command -v exa &>/dev/null; then
  alias ls='exa'
  alias l='exa -1a'
  alias la='exa -a'
  alias ll='exa -la'
  alias lx='exa -la --icons --sort=modified'
  alias tree='exa --tree'
fi

# 如果有fd命令，设置别名
if command -v fdfind &>/dev/null; then
  alias fd='fdfind'
fi

# 为Nerd Fonts设置变量（帮助部分应用显示图标）
export NERD_FONT=1

EOL

# 设置zsh为默认shell
if [ "$SHELL" != "$(which zsh)" ]; then
    echo -e "${GREEN}设置zsh为默认shell...${NC}"
    chsh -s $(which zsh)
    echo -e "${YELLOW}请注销并重新登录以应用更改${NC}"
fi

echo -e "${GREEN}=== zsh配置安装完成! ===${NC}"
echo -e "${YELLOW}请重启终端或执行 'source ~/.zshrc' 以应用更改${NC}"

# 针对特定主题的提示
case $THEME in
  p10k)
    echo -e "${YELLOW}首次启动时，将自动运行Powerlevel10k配置向导，按提示选择您喜欢的外观${NC}"
    echo -e "${YELLOW}之后您可以随时运行 'p10k configure' 重新配置主题${NC}"
    ;;
  pure)
    echo -e "${YELLOW}Pure主题已安装，重启终端后生效${NC}"
    ;;
  spaceship)
    echo -e "${YELLOW}Spaceship主题已安装，重启终端后生效${NC}"
    echo -e "${YELLOW}您可以在~/.zshrc中修改SPACESHIP_PROMPT_ORDER以自定义显示内容${NC}"
    ;;
esac

# 提供卸载/更新指令
echo -e "${CYAN}如需更新配置，请运行: $0 --update${NC}"
echo -e "${CYAN}如需卸载并重新安装，请运行: $0 --clean${NC}" 
