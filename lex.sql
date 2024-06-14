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
/*                                                                                                           */
/*************************************************************************************************************/
WITH RECURSIVE expr(code) AS (values ('"Abc" + 10 + 20 * 3.45 / 9 - 334 + func(arg1, arg2, "alpha?");')),
lex(ctrl) AS (
	SELECT json_object('st', 'S_START', 'tk', 'T_WAIT', 'ch', substr(expr.code, 1, 1), 'i', 1, 'tx', '') as ctrl FROM expr
	UNION ALL SELECT 
	CASE
		WHEN ctrl ->> '$.i' > length(expr.code) then json_object('st', 'S_ERROR', 'tk', '', 'tx', format('Unexpected end of input at position %d', ctrl ->> '$.i'))
		WHEN ctrl ->> '$.st' = 'S_START' THEN
		CASE 
			WHEN ctrl ->> '$.ch' = ';' THEN json_object('st', 'S_EOL', 'tk', 'T_EOL', 'ch', substr(expr.code, ctrl ->> '$.i'+1, 1), 'i', ctrl ->> '$.i'+1, 'tx', '<EOL>')
			WHEN ctrl ->> '$.ch' = ' ' THEN json_object('st', 'S_WS', 'tk', 'T_WAIT', 'ch', substr(expr.code, ctrl ->> '$.i'+1, 1), 'i', ctrl ->> '$.i'+1, 'tx', '')
			WHEN instr('0123456789', ctrl ->> '$.ch') > 0 THEN json_object('st', 'S_INT', 'tk', 'T_WAIT', 'ch', substr(expr.code, ctrl ->> '$.i'+1, 1), 'i', ctrl ->> '$.i'+1, 'tx', ctrl ->> '$.ch')
			WHEN upper(ctrl ->> '$.ch') between 'A' and 'Z' THEN json_object('st', 'S_KWD', 'tk', 'T_WAIT', 'ch', substr(expr.code, ctrl ->> '$.i'+1, 1), 'i', ctrl ->> '$.i'+1, 'tx', ctrl ->> '$.ch')
			WHEN ctrl ->> '$.ch' = '"' THEN json_object('st', 'S_STRING', 'tk', 'T_WAIT', 'ch', substr(expr.code, ctrl ->> '$.i'+1, 1), 'i', ctrl ->> '$.i'+1, 'tx', '')
			WHEN ctrl ->> '$.ch' = '+' THEN json_object('st', 'S_START', 'tk', 'T_ADD', 'ch', substr(expr.code, ctrl ->> '$.i'+1, 1), 'i', ctrl ->> '$.i'+1, 'tx', ctrl ->> '$.ch')
			WHEN ctrl ->> '$.ch' = '-' THEN json_object('st', 'S_START', 'tk', 'T_SUB', 'ch', substr(expr.code, ctrl ->> '$.i'+1, 1), 'i', ctrl ->> '$.i'+1, 'tx', ctrl ->> '$.ch')
			WHEN ctrl ->> '$.ch' = '*' THEN json_object('st', 'S_START', 'tk', 'T_MUL', 'ch', substr(expr.code, ctrl ->> '$.i'+1, 1), 'i', ctrl ->> '$.i'+1, 'tx', ctrl ->> '$.ch')
			WHEN ctrl ->> '$.ch' = '/' THEN json_object('st', 'S_START', 'tk', 'T_DIV', 'ch', substr(expr.code, ctrl ->> '$.i'+1, 1), 'i', ctrl ->> '$.i'+1, 'tx', ctrl ->> '$.ch')
			WHEN ctrl ->> '$.ch' = '(' THEN json_object('st', 'S_START', 'tk', 'T_LPARAN', 'ch', substr(expr.code, ctrl ->> '$.i'+1, 1), 'i', ctrl ->> '$.i'+1, 'tx', ctrl ->> '$.ch')
			WHEN ctrl ->> '$.ch' = ')' THEN json_object('st', 'S_START', 'tk', 'T_RPARAN', 'ch', substr(expr.code, ctrl ->> '$.i'+1, 1), 'i', ctrl ->> '$.i'+1, 'tx', ctrl ->> '$.ch')
			WHEN ctrl ->> '$.ch' = ',' THEN json_object('st', 'S_START', 'tk', 'T_COMMA', 'ch', substr(expr.code, ctrl ->> '$.i'+1, 1), 'i', ctrl ->> '$.i'+1, 'tx', ctrl ->> '$.ch')
			ELSE json_object('st', 'S_ERROR', 'tk', '', 'tx', format('Error at position %d near character "%s"', ctrl ->> '$.i', ctrl ->> '$.ch'))
		END
		WHEN ctrl ->> '$.st' = 'S_WS' THEN
		CASE
			WHEN ctrl ->> '$.ch' = ' ' THEN json_object('st', 'S_WS', 'tk', 'T_WAIT', 'ch', substr(expr.code, ctrl ->> '$.i'+1, 1), 'i', ctrl ->> '$.i'+1, 'tx', '')
			ELSE json_object('st', 'S_START', 'tk', 'T_WS', 'ch', substr(expr.code, ctrl ->> '$.i', 1), 'i', ctrl ->> '$.i', 'tx', '')
		END
		WHEN ctrl ->> '$.st' = 'S_INT' THEN 
		CASE 
			WHEN instr('0123456789', ctrl ->> '$.ch') > 0 THEN json_object('st', 'S_INT', 'tk', 'T_WAIT', 'ch', substr(expr.code, ctrl ->> '$.i'+1, 1), 'i', ctrl ->> '$.i'+1, 'tx', format('%s%s', ctrl ->> '$.tx', ctrl ->> '$.ch'))
			WHEN ctrl ->> '$.ch' = '.' THEN json_object('st', 'S_FLOAT', 'tk', 'T_WAIT', 'ch', substr(expr.code, ctrl ->> '$.i'+1, 1), 'i', ctrl ->> '$.i'+1, 'tx', format('%s%s', ctrl ->> '$.tx', ctrl ->> '$.ch'))
			ELSE json_object('st', 'S_START', 'tk', 'T_INT', 'ch', substr(expr.code, ctrl ->> '$.i', 1), 'i', ctrl ->> '$.i', 'tx', ctrl ->> '$.tx')
		END
		WHEN ctrl ->> '$.st' = 'S_FLOAT' THEN 
		CASE
			WHEN instr('0123456789', ctrl ->> '$.ch') > 0 THEN json_object('st', 'S_FLOAT', 'tk', 'T_WAIT', 'ch', substr(expr.code, ctrl ->> '$.i'+1, 1), 'i', ctrl ->> '$.i'+1, 'tx', format('%s%s', ctrl ->> '$.tx', ctrl ->> '$.ch'))
			ELSE json_object('st', 'S_START', 'tk', 'T_FLOAT', 'ch', substr(expr.code, ctrl ->> '$.i', 1), 'i', ctrl ->> '$.i', 'tx', ctrl ->> '$.tx')
		END
		WHEN ctrl ->> '$.st' = 'S_KWD' THEN
		CASE
			WHEN (upper(ctrl ->> '$.ch') between 'A' and 'Z' OR ctrl ->> '$.ch' BETWEEN '0' and '9') THEN json_object('st', 'S_KWD', 'tk', 'T_WAIT', 'ch', substr(expr.code, ctrl ->> '$.i'+1, 1), 'i', ctrl ->> '$.i'+1, 'tx', format('%s%s', ctrl ->> '$.tx', ctrl ->> '$.ch'))
			ELSE json_object('st', 'S_START', 'tk', 'T_KWD', 'ch', substr(expr.code, ctrl ->> '$.i', 1), 'i', ctrl ->> '$.i', 'tx', ctrl ->> '$.tx')
		END
		WHEN ctrl ->> '$.st' = 'S_STRING' THEN
		CASE
			WHEN ctrl ->> '$.ch' <> '"' THEN json_object('st', 'S_STRING', 'tk', 'T_WAIT', 'ch', substr(expr.code, ctrl ->> '$.i'+1, 1), 'i', ctrl ->> '$.i'+1, 'tx', format('%s%s', ctrl ->> '$.tx', ctrl ->> '$.ch'))
			ELSE json_object('st', 'S_START', 'tk', 'T_STRING', 'ch', substr(expr.code, ctrl ->> '$.i'+1, 1), 'i', ctrl ->> '$.i' + 1, 'tx', ctrl ->> '$.tx')
		END			
	END AS state
	FROM lex JOIN expr WHERE ctrl ->> '$.st' not in ('S_ERROR', 'S_EOL') 
)
SELECT ctrl ->> '$.tk' as token, ctrl ->> '$.tx' as txt, ctrl ->> '$.i' as pos FROM lex where ctrl ->> '$.tk' <> 'T_WAIT'
