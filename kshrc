# -*-sh-*-

#
# .kshrc - Korn shell 93 startup file
#

umask 0077
set -o emacs
set +o multiline

# History file.
export HISTFILE=~/.hist$$
trap 'rm -f $HISTFILE' EXIT

export CDSTACK=32
export FPATH=$HOME/.funcs
integer _push_max=${CDSTACK} _push_top=${CDSTACK}

# Directory manipulation functions.
unalias cd 2>/dev/null
alias cd=_cd
alias pu=pushd
alias po=popd
alias d=dirs

alias h=history
alias j=jobs
alias m=$PAGER
alias ll='ls -laFo'
alias l='ls -l'
alias g='fgrep -i'
alias c=clear
alias ec=emacsclient
alias mutt='TERM=rxvt-256color mutt'

# Don't get fancy if we have a dumb terminal.  This happens for
# example if we're accessing files remotely through tramp in emacs.
[[ $TERM == 'dumb' ]] && return 0

# Generate an associative array containing the alternative characters
# set for the terminal.  See termcap (5) for more details.

eval typeset -A altchar=\($(tput acsc | sed -E "s/(.)(.)/['\1']='\2' /g")\)

# Generate two associative arrays containing the background
# and foreground colors.

typeset -A fg bg

function load_colors
{
    typeset color
    integer i=0

    for color in black red green brown blue magenta cyan white; do
        fg+=([$color]=$(tput setaf $i))
        bg+=([$color]=$(tput setab $i))
        (( i++ ))
    done
    fg+=([reset]=$(tput setaf 9))
    bg+=([reset]=$(tput setab 9))
}

function init_parms
{
    _user=$(whoami)
    _host=$(hostname -s)
    _tty=$(tty | sed s@/dev/@@)
    _rprompt=
    _lpos=
    _rpos=
    _cont_prompt=
    case $(id -u) in
	0) _prompt=\#;;
	*) _prompt=\$;;
    esac
    _prompt=$(tput md)${_prompt}$(tput me)

    # Use alternative characters to draw lines if supported or degrade
    # to normal characters if not.

    alt_on=$(tput as)
    alt_off=$(tput ae)
    _hbar=${altchar[q]:--}
    _vbar=${altchar[x]:-\|}
    _ulcorner=${altchar[l]:--}
    _llcorner=${altchar[m]:--}
    _urcorner=${altchar[k]:--}
    _lrcorner=${altchar[j]:--}
    _lbracket=${altchar[u]:-\[}
    _rbracket=${altchar[t]:-\]}

    integer colormax=$(tput colors)
    if (( ${colormax:-0} >= 8 )); then
        load_colors
        case $(id -u) in
            0)
                _bgcolor=${bg[red]}
                _fgcolor=${fg[white]}
                ;;
            *)
                _bgcolor=${bg[white]}
                _fgcolor=${fg[black]}
                ;;
        esac
    fi

    # Enable alternate char set.
    tput enacs
}

# Like pwd but display the $HOME directory as ~
function _pwd
{
    typeset dir="${PWD:-$(pwd -L)}"

    dir="${dir#$HOME/}"
    case $dir in
	"$HOME")
	    dir=\~ ;;
	/*)
	    ;;
	*)
	    dir=\~/$dir ;;
    esac
    print $dir
}

#### Two lines prompt.
# This function is executed before PS1 is referenced. It sets _rpos to
# the position of the right prompt and _lpos to the position after the
# left prompt. See discipline function in the man page of ksh93.

function PS1.get
{
    typeset rc=$?  # save the return value of the last command
    typeset dir="$(_pwd)" padline
    typeset uprompt="--[${_user}@${_host}:${_tty}]--(${dir})--"
    typeset rprompt="-(${_rstatue})--" lprompt="--(${_lstatue}|$)- "
    integer termwidth=$(tput co)
    integer offset=$(( ${#uprompt} - ${termwidth} ))
    integer i

    # Truncate the current directory if too long and define a line
    # padding such that the upper prompt occupy the terminal width.
    if (( $offset > 0 )) ; then
	dir="...${dir:$(( $offset + 3 ))}"
	padline=""
    else
	offset=$(( - $offset ))
	padline=${alt_on}
	for (( i=0; i<$offset; i++ )); do
	    padline=${padline}${_hbar}
	done
	padline=${padline}${alt_off}
    fi

    _rpos=$(( $termwidth - ${#rprompt} ))
    _lpos=${#lprompt}
    _cont_prompt=

    # Upper prompt.
    .sh.value="\
${alt_on}${_ulcorner}${_hbar}${_lbracket}${alt_off}\
${_bgcolor}${_fgcolor}\
${_user}@${_host}:${_tty}\
${fg[reset]}${bg[reset]}\
${alt_on}${_rbracket}${alt_off}\
${padline}\
${alt_on}${_hbar}${_hbar}${alt_off}\
$(tput md)(${dir})$(tput me)\
${alt_on}${_hbar}${_urcorner}${alt_off}"

    # If the terminal doesn't ignore a newline after the last column
    # and has automatic margin (e.g. cons25), a newline or carriage
    # return if written will be on the next line.  So don't add a
    # newline and for good mesure, move the cursor to the left before
    # writing cr at the end of a line.

    if ! tput am || tput xn; then
	.sh.value=${.sh.value}$'\n'
    fi

    # Lower prompt using carriage return to display the right prompt.
    .sh.value="${.sh.value}\
$(tput RI $_rpos)\
${_rprompt}\
$(tput le)$(tput cr)\
${alt_on}${_llcorner}${_hbar}${alt_off}\
(${_lstatue}${alt_on}${_vbar}${alt_off}${_prompt})\
${alt_on}${_hbar}${alt_off} "

    return $rc
}

# Statue in the left prompt
function _lstatue.get
{
    .sh.value=$(date +%H:%M:%S)
}

export GIT_PS1_SHOWDIRTYSTATE=yes
export GIT_PS1_SHOWUNTRACKEDFILES=yes

# Statue in the right prompt
function _rstatue.get
{
    # Use the current branch in a git repository or the current date.
    typeset b=$(__git_ps1 git:)
    .sh.value=${b:-$(date "+%a, %d %b")}
}

# Right prompt.
function _rprompt.get
{
    .sh.value="\
${alt_on}${_hbar}${alt_off}\
(${_rstatue})\
${alt_on}${_hbar}${_lrcorner}${alt_off}"
}

# Continuation prompt
function PS2.get
{
    _cont_prompt=yes
    .sh.value="${alt_on}${_hbar}${_hbar}${alt_off} "
}

# Deletion characters in emacs editing mode and from stty.
typeset -A _delchars=(
    [$'\ch']=DEL
    [$'\177']=BS
    [$'\E\177']=KILL-REGION
    [$'\cw']=BACKWARD-KILL-WORD
    [$'\cu']=KILL-LINE
)

# Erase the right prompt if the text reaches it and redraw it if the
# text fits in the region between the left prompt and the right one.
function _rpdisplay
{
    integer width=$(( $_rpos - $_lpos - 1))
    integer pos=${#.sh.edtext}
    typeset -S has_rprompt=yes
    typeset ch=${.sh.edchar}

    if [[ -z $has_rprompt ]]; then
        if (( $pos < $width )) ||
            ( (($pos == $width+1)) && [[ -n ${_delchars[$ch]} ]] ); then
            tput sc; tput vi
            tput cr; tput RI $_rpos
            print -n -- "${_rprompt}"
            tput rc; tput ve
            has_rprompt=yes
        fi
    elif (( $pos >= $width )) && [[ -z ${_delchars[$ch]} ]]; then
        tput ce
        has_rprompt=
    fi
}

# Set the line status to the command buffer and the window title
# to the command name.
function _setscreen
{
    typeset hs=${.sh.edtext/#*(\s)/} # delete leading blanks
    typeset cmd=${hs/%@(\s)*}
    typeset args=${hs/#+(\S)/}
    typeset sudopts=AbEHhKkLlnPSVvg:p:U:u:C:c:
    typeset -S lastcmd

    if [[ -n $cmd ]]; then
        cmd=${cmd##*/}
        if [[ $cmd == sudo || $cmd == *=* ]]; then
            # Find the real command name
            set -- $args
            {
                while getopts $sudopts c; do
                    ;               # skip options
                done
            } 2>/dev/null
            shift $((OPTIND-1))
            if [[ -n $1 ]]; then
                cmd=${1##*/}
            fi
        fi
        # Ignore variable assignment
        if [[  $cmd != *=* ]]; then
            lastcmd=$cmd
        fi
    fi
    print -nR $'\E_'${hs}$'\E\\'
    print -nR $'\Ek'${lastcmd}$'\E\\'
}

# Assoctiate a key  with an action.
typeset -A Keytable

function keybind # key [action]
{
    typeset key=$(print -f "%q" "$2")
    case $# in
    2)      Keytable[$1]=' .sh.edchar=${.sh.edmode}'"$key"
            ;;
    1)      unset Keytable[$1]
            ;;
    *)      print -u2 "Usage: $0 key [action]"
            return 2 # usage errors return 2 by default
            ;;
    esac
}

function _keytrap
{
    eval "${Keytable[${.sh.edchar}]}"

    # Execute only if we're not on a continuation prompt
    if [[ -z $_cont_prompt ]]; then
        [[ $TERM == screen && ${.sh.edchar} == $'\r' ]] && _setscreen
	_rpdisplay
    fi
}
trap _keytrap KEYBD

# Swap ^W and M-baskspace in emacs editing mode.
keybind $'\cw' $'\E\177'
keybind $'\E\177' $'\cw'

init_parms
