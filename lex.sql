/*************************************************************************************************************/
/*                                                                                                           */
/* Implements a state machine that scans for the following tokens:                                           */
/*                                                                                                           */
/* T_KWD:    [A-Za-z][A-Za-z0-9]*                                                                            */
/* T_INT:    [0-9]+                                                                                          */
/* T_FLOAT:  [0-9]+\.[0-9]+                                                                                  */
/* T_WS:     \s+                                                                                             */
/* T_MUL:    \*                                                                                              */
/* T_DIV:    \/                                                                                              */
/* T_ADD:    \+                                                                                              */
/* T_SUB:    \-                                                                                              */
/* T_LPARAN: \(                                                                                              */
/* T_RPARAN: \)                                                                                              */
/* T_COMMA:  \,                                                                                              */
/* T_STRING: ".*"                                                                                            */
/* T_EOL:    \;                                                                                              */
/*                                                                                                           */
/* The state machine uses a recursive CTE and a JSON object to split the input string into tokens.           */
/* The JSON objects (called 'ctrl' in the script) has these attributes:                                      */
/*   st: the current state of the machine                                                                    */
/*   tk: the emitted token (the pseudo token T_WAIT indicates that the machine is processing a token)        */
/*   ch: the current character of the input string                                                           */
/*    i: the current scan position in the input string                                                       */
/*   tx: the text of matched token                                                                           */
/*                                                                                                           */
/*************************************************************************************************************/

-- the expr CTE contains the text to be scanned
-- the text here is just provided as a sample input
WITH RECURSIVE expr(code) AS (values ('"Abc" +  10 + 20 * 3.45 / 9 - 334 + func(arg1, arg2, "alpha?");')),
-- the lex CTE contains the actual state machine logic
-- ctrl is the JSON object used to hold the machine state and other attributes
lex(ctrl) AS (
	-- use the base state of the recursive CTE to initialize the state machine
	SELECT json_object('st', 'S_START', 'tk', 'T_WAIT', 'ch', substr(expr.code, 1, 1), 'i', 1, 'tx', '') as ctrl FROM expr
	UNION ALL SELECT 
	-- the following is the actual state machine
	-- it uses a search case to examine the JSON object 'ctrl' and derive a new JSON object which effects the state transition
	CASE
		-- the input string must be terminated with a semi-colon
		-- this step checks for string overrun
		WHEN ctrl ->> '$.i' > length(expr.code) then json_object('st', 'S_ERROR', 'tk', '', 'tx', format('Unexpected end of input at position %d', ctrl ->> '$.i'))
		-- S_START state is the base state that all other states will return to once sub-token scanning is complete and a token is emitted
		WHEN ctrl ->> '$.st' = 'S_START' THEN
		CASE 
			-- check for the semi-colon that indicates EOL
			WHEN ctrl ->> '$.ch' = ';' THEN json_object('st', 'S_EOL', 'tk', 'T_EOL', 'ch', substr(expr.code, ctrl ->> '$.i'+1, 1), 'i', ctrl ->> '$.i'+1, 'tx', '<EOL>')
			-- whitespace: moves the next state to S_WS
			WHEN ctrl ->> '$.ch' = ' ' THEN json_object('st', 'S_WS', 'tk', 'T_WAIT', 'ch', substr(expr.code, ctrl ->> '$.i'+1, 1), 'i', ctrl ->> '$.i'+1, 'tx', '')
			-- numeric digit: moves the next state to S_INT
			WHEN instr('0123456789', ctrl ->> '$.ch') > 0 THEN json_object('st', 'S_INT', 'tk', 'T_WAIT', 'ch', substr(expr.code, ctrl ->> '$.i'+1, 1), 
	                                                                               'i', ctrl ->> '$.i'+1, 'tx', ctrl ->> '$.ch')
			-- alpha character: moves the next state to S_KWD
			WHEN upper(ctrl ->> '$.ch') BETWEEN 'A' and 'Z' THEN json_object('st', 'S_KWD', 'tk', 'T_WAIT', 'ch', substr(expr.code, ctrl ->> '$.i'+1, 1), 
	                                                                                 'i', ctrl ->> '$.i'+1, 'tx', ctrl ->> '$.ch')
			-- quotation mark: moves the next state to S_STRING
			WHEN ctrl ->> '$.ch' = '"' THEN json_object('st', 'S_STRING', 'tk', 'T_WAIT', 'ch', substr(expr.code, ctrl ->> '$.i'+1, 1), 'i', ctrl ->> '$.i'+1, 'tx', '')
			-- the following are all single-length characters
			-- they don't require sub states, so we just emit the token and return to S_START
			WHEN ctrl ->> '$.ch' = '+' THEN json_object('st', 'S_START', 'tk', 'T_ADD', 'ch', substr(expr.code, ctrl ->> '$.i'+1, 1), 'i', ctrl ->> '$.i'+1, 'tx', ctrl ->> '$.ch')
			WHEN ctrl ->> '$.ch' = '-' THEN json_object('st', 'S_START', 'tk', 'T_SUB', 'ch', substr(expr.code, ctrl ->> '$.i'+1, 1), 'i', ctrl ->> '$.i'+1, 'tx', ctrl ->> '$.ch')
			WHEN ctrl ->> '$.ch' = '*' THEN json_object('st', 'S_START', 'tk', 'T_MUL', 'ch', substr(expr.code, ctrl ->> '$.i'+1, 1), 'i', ctrl ->> '$.i'+1, 'tx', ctrl ->> '$.ch')
			WHEN ctrl ->> '$.ch' = '/' THEN json_object('st', 'S_START', 'tk', 'T_DIV', 'ch', substr(expr.code, ctrl ->> '$.i'+1, 1), 'i', ctrl ->> '$.i'+1, 'tx', ctrl ->> '$.ch')
			WHEN ctrl ->> '$.ch' = '(' THEN json_object('st', 'S_START', 'tk', 'T_LPARAN', 'ch', substr(expr.code, ctrl ->> '$.i'+1, 1), 'i', ctrl ->> '$.i'+1, 'tx', ctrl ->> '$.ch')
			WHEN ctrl ->> '$.ch' = ')' THEN json_object('st', 'S_START', 'tk', 'T_RPARAN', 'ch', substr(expr.code, ctrl ->> '$.i'+1, 1), 'i', ctrl ->> '$.i'+1, 'tx', ctrl ->> '$.ch')
			WHEN ctrl ->> '$.ch' = ',' THEN json_object('st', 'S_START', 'tk', 'T_COMMA', 'ch', substr(expr.code, ctrl ->> '$.i'+1, 1), 'i', ctrl ->> '$.i'+1, 'tx', ctrl ->> '$.ch')
			-- if no character is matched, emit an error state
			ELSE json_object('st', 'S_ERROR', 'tk', '', 'tx', format('Error at position %d near character "%s"', ctrl ->> '$.i', ctrl ->> '$.ch'))
		END
		-- S_WS: repeats until char is anything other than a space
		WHEN ctrl ->> '$.st' = 'S_WS' THEN
		CASE
			WHEN ctrl ->> '$.ch' = ' ' THEN json_object('st', 'S_WS', 'tk', 'T_WAIT', 'ch', substr(expr.code, ctrl ->> '$.i'+1, 1), 'i', ctrl ->> '$.i'+1, 'tx', '')
			ELSE json_object('st', 'S_START', 'tk', 'T_WS', 'ch', substr(expr.code, ctrl ->> '$.i', 1), 'i', ctrl ->> '$.i', 'tx', '')
		END
		-- S_INT: if the current char is a period, switch to state S_FLOAT
		-- otherwise, gather the digits into ctrl -> tx
		-- return to S_STATE if char is anything else
		WHEN ctrl ->> '$.st' = 'S_INT' THEN 
		CASE 
			WHEN instr('0123456789', ctrl ->> '$.ch') > 0 THEN json_object('st', 'S_INT', 'tk', 'T_WAIT', 'ch', substr(expr.code, ctrl ->> '$.i'+1, 1), 
	                                                                               'i', ctrl ->> '$.i'+1, 'tx', format('%s%s', ctrl ->> '$.tx', ctrl ->> '$.ch'))
			WHEN ctrl ->> '$.ch' = '.' THEN json_object('st', 'S_FLOAT', 'tk', 'T_WAIT', 'ch', substr(expr.code, ctrl ->> '$.i'+1, 1), 
	                                                            'i', ctrl ->> '$.i'+1, 'tx', format('%s%s', ctrl ->> '$.tx', ctrl ->> '$.ch'))
			ELSE json_object('st', 'S_START', 'tk', 'T_INT', 'ch', substr(expr.code, ctrl ->> '$.i', 1), 'i', ctrl ->> '$.i', 'tx', ctrl ->> '$.tx')
		END
		-- S_FLOAT: gather digits into ctrl -> tx, return to S_START if char is not a digit
		WHEN ctrl ->> '$.st' = 'S_FLOAT' THEN 
		CASE
			WHEN instr('0123456789', ctrl ->> '$.ch') > 0 THEN json_object('st', 'S_FLOAT', 'tk', 'T_WAIT', 'ch', substr(expr.code, ctrl ->> '$.i'+1, 1), 
	                                                                               'i', ctrl ->> '$.i'+1, 'tx', format('%s%s', ctrl ->> '$.tx', ctrl ->> '$.ch'))
			ELSE json_object('st', 'S_START', 'tk', 'T_FLOAT', 'ch', substr(expr.code, ctrl ->> '$.i', 1), 'i', ctrl ->> '$.i', 'tx', ctrl ->> '$.tx')
		END
		-- S_KWD: if char is an alphanumeric, gather into ctrl -> tx, otherwise return S_START
		WHEN ctrl ->> '$.st' = 'S_KWD' THEN
		CASE
			WHEN (upper(ctrl ->> '$.ch') between 'A' and 'Z' OR ctrl ->> '$.ch' BETWEEN '0' and '9') 
				THEN json_object('st', 'S_KWD', 'tk', 'T_WAIT', 'ch', substr(expr.code, ctrl ->> '$.i'+1, 1), 
	                             'i', ctrl ->> '$.i'+1, 'tx', format('%s%s', ctrl ->> '$.tx', ctrl ->> '$.ch'))
			ELSE json_object('st', 'S_START', 'tk', 'T_KWD', 'ch', substr(expr.code, ctrl ->> '$.i', 1), 'i', ctrl ->> '$.i', 'tx', ctrl ->> '$.tx')
		END
		-- S_STRING: gather all characters into ctrl -> tx until the closing quotation mark is matched 
		WHEN ctrl ->> '$.st' = 'S_STRING' THEN
		CASE
			WHEN ctrl ->> '$.ch' <> '"' THEN json_object('st', 'S_STRING', 'tk', 'T_WAIT', 'ch', substr(expr.code, ctrl ->> '$.i'+1, 1), 
	                                                             'i', ctrl ->> '$.i'+1, 'tx', format('%s%s', ctrl ->> '$.tx', ctrl ->> '$.ch'))
			ELSE json_object('st', 'S_START', 'tk', 'T_STRING', 'ch', substr(expr.code, ctrl ->> '$.i'+1, 1), 'i', ctrl ->> '$.i' + 1, 'tx', ctrl ->> '$.tx')
		END			
	END AS ctrl
	FROM lex JOIN expr WHERE ctrl ->> '$.st' not in ('S_ERROR', 'S_EOL') 
)
SELECT ctrl ->> '$.tk' as token, ctrl ->> '$.tx' as txt FROM lex where ctrl ->> '$.tk' <> 'T_WAIT'
