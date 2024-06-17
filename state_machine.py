from enum import Enum
from dataclasses import dataclass
from typing import List, Optional


###
# Exception class
###
class LexerException(Exception):

    def __init__(self, message: str):
        self.message = message

    def __str__(self):
        return self.message


###
# State enums
###
class States(Enum):
    S_START = 'S_START'
    S_WS = 'S_WS'
    S_STRING = 'S_STRING'
    S_INT = 'S_INT'
    S_FLOAT = 'S_FLOAT'
    S_KWD = 'S_KWD'
    S_EOL = 'S_EOL'
    S_ERROR = 'S_ERROR'


###
# Token type enums
###
class TokenTypes(Enum):
    T_KWD = 'T_KWD'         # [A-Za-z][A-Za-z0-9]*
    T_INT = 'T_INT'         # [0-9]+
    T_FLOAT = 'T_FLOAT'     # [0-9]+\.[0-9]+
    T_WS = 'T_WS'           # \s+
    T_MUL = 'T_MUL'         # \*
    T_DIV = 'T_DIV'         # \/
    T_ADD = 'T_ADD'         # \+
    T_SUB = 'T_SUB'         # \-
    T_LPARAN = 'T_LPARAN'   # \(
    T_RPARAN = 'T_RPARAN'   # \)
    T_COMMA = 'T_COMMA'     # \,
    T_STRING = 'T_STRING'   # ".*"
    T_EOL = 'T_EOL'         # \;
    T_WAIT = 'T_WAIT'


@dataclass
class Token:
    """ Token class """
    token_type: TokenTypes
    text: Optional[str]


@dataclass
class Ctrl:
    """ Class to keep track of state information """
    state: States       # current state
    pos: int            # scan position
    token: Token        # token corresponding to this state


def transition(ctrl: Ctrl, code: str) -> Ctrl:
    """
    This function takes the current state as a parameter and returns a new state derived from the machine rules
    :param ctrl: input state
    :param code: string containing text to be scanned
    :return: next state
    """

    ch = code[ctrl.pos]

    if ctrl.state == States.S_START:
        # check for semicolon
        if ch == ';':
            return Ctrl(States.S_EOL, ctrl.pos + 1, Token(TokenTypes.T_EOL, '<EOL>'))
        # check for whitespace
        elif ch == ' ':
            return Ctrl(States.S_WS, ctrl.pos + 1, Token(TokenTypes.T_WAIT, None))
        # check for integer
        elif '0' <= ch <= '9':
            return Ctrl(States.S_INT, ctrl.pos + 1, Token(TokenTypes.T_WAIT, ch))
        # check for alpha character
        elif 'A' <= ch.upper() <= 'Z':
            return Ctrl(States.S_KWD, ctrl.pos + 1, Token(TokenTypes.T_WAIT, ch))
        # check string opening quote
        elif ch == '"':
            return Ctrl(States.S_STRING, ctrl.pos + 1, Token(TokenTypes.T_WAIT, ''))
        # single-character matches
        elif ch == '+':
            return Ctrl(States.S_START, ctrl.pos + 1, Token(TokenTypes.T_ADD, ch))
        elif ch == '-':
            return Ctrl(States.S_START, ctrl.pos + 1, Token(TokenTypes.T_SUB, ch))
        elif ch == '*':
            return Ctrl(States.S_START, ctrl.pos + 1, Token(TokenTypes.T_MUL, ch))
        elif ch == '/':
            return Ctrl(States.S_START, ctrl.pos + 1, Token(TokenTypes.T_DIV, ch))
        elif ch == '(':
            return Ctrl(States.S_START, ctrl.pos + 1, Token(TokenTypes.T_RPARAN, ch))
        elif ch == ')':
            return Ctrl(States.S_START, ctrl.pos + 1, Token(TokenTypes.T_LPARAN, ch))
        elif ch == ',':
            return Ctrl(States.S_START, ctrl.pos + 1, Token(TokenTypes.T_COMMA, ch))
        else:
            raise LexerException(f'Unexpected character {ch} at position {ctrl.pos}')
    # whitespace state
    elif ctrl.state == States.S_WS:
        if ch == ' ':
            return Ctrl(States.S_WS, ctrl.pos + 1, Token(TokenTypes.T_WAIT, None))
        else:
            # backtrack: return same pos instead of advancing
            return Ctrl(States.S_START, ctrl.pos, Token(TokenTypes.T_WS, ' '))
    # integer state
    elif ctrl.state == States.S_INT:
        if '0' <= ch <= '9':
            return Ctrl(States.S_INT, ctrl.pos + 1, Token(TokenTypes.T_WAIT, ctrl.token.text + ch))
        # check for period and move state to S_FLOAT is found
        elif ch == '.':
            return Ctrl(States.S_FLOAT, ctrl.pos + 1, Token(TokenTypes.T_WAIT, ctrl.token.text + ch))
        else:
            # backtrack: return same pos instead of advancing
            return Ctrl(States.S_START, ctrl.pos, Token(TokenTypes.T_INT, ctrl.token.text))
    # float state
    elif ctrl.state == States.S_FLOAT:
        if '0' <= ch <= '9':
            return Ctrl(States.S_FLOAT, ctrl.pos + 1, Token(TokenTypes.T_WAIT, ctrl.token.text + ch))
        else:
            # backtrack: return same pos instead of advancing
            return Ctrl(States.S_START, ctrl.pos, Token(TokenTypes.T_FLOAT, ctrl.token.text))
    # keyword state
    elif ctrl.state == States.S_KWD:
        if ('A' <= ch.upper() <= 'Z') or ('0' <= ch <= '9'):
            return Ctrl(States.S_KWD, ctrl.pos + 1, Token(TokenTypes.T_WAIT, ctrl.token.text + ch))
        else:
            # backtrack: return same pos instead of advancing
            return Ctrl(States.S_START, ctrl.pos, Token(TokenTypes.T_KWD, ctrl.token.text))
    # string state - match all characters until closing quote is found
    elif ctrl.state == States.S_STRING:
        if ch != '"':
            return Ctrl(States.S_STRING, ctrl.pos + 1, Token(TokenTypes.T_WAIT, ctrl.token.text + ch))
        else:
            return Ctrl(States.S_START, ctrl.pos + 1, Token(TokenTypes.T_STRING, ctrl.token.text))
    else:
        raise LexerException(f'Unhandled state {ctrl.state}')


def tokenize_itr(code: str) -> List[Token]:
    """
    Tokenizer - iterative version
    :param code: text to be scanned
    :return: token stream
    """

    tokens: List[Token] = []
    ctrl = Ctrl(States.S_START, 0, Token(TokenTypes.T_WAIT, None))

    while ctrl.state not in (States.S_ERROR, States.S_EOL):
        if ctrl.pos >= len(code):
            raise LexerException(f'Unexpected end of input at {ctrl.pos}')
        ctrl = transition(ctrl, code)
        if ctrl.token.token_type != TokenTypes.T_WAIT:
            tokens.append(ctrl.token)

    return tokens


def tokenize_recur(code: str) -> List[Token]:
    """
    Tokenizer - recursive version
    :param code: text to be scanned
    :return: token stream
    """
    tokens: List[Token] = []

    def scan(ctrl: Ctrl):
        """ recursive scanning function """
        if ctrl.pos > len(code):
            raise LexerException(f'Unexpected end of input at {ctrl.pos}')
        if ctrl.state not in (States.S_EOL, States.S_ERROR):
            ctrl = transition(ctrl, code)
            if ctrl.token.token_type != TokenTypes.T_WAIT:
                tokens.append(ctrl.token)
            scan(ctrl)

    scan(Ctrl(States.S_START, 0, Token(TokenTypes.T_WAIT, None)))
    return tokens


try:
    for token_type in tokenize_recur('"Abc" +  10 + 20 * 3.45 / 9 - 334 + func(arg1, arg2, "alpha?");'):
        print(f'{token_type.token_type}: {token_type.text}')
except LexerException as e:
    print(e)

