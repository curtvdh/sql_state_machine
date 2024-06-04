WITH RECURSIVE expr(code) AS (values ('10 + 20 * 3.45 / 9 - 334' || ';')),
lex(ctrl) AS (
	SELECT json_object('st', 'S_START', 'tk', 'T_WAIT', 'ch', substr(expr.code, 1, 1), 'i', 1, 'tx', '') as ctrl FROM expr
	UNION ALL SELECT 
	CASE
		WHEN ctrl ->> '$.st' = 'S_START' THEN
		CASE 
			WHEN ctrl ->> '$.ch' = ';' THEN json_object('st', 'S_EOL', 'tk', 'T_EOL', 'ch', substr(expr.code, ctrl ->> '$.i'+1, 1), 'i', ctrl ->> '$.i'+1, 'tx', '<EOL>')
			WHEN ctrl ->> '$.ch' = ' ' THEN json_object('st', 'S_WS', 'tk', 'T_WAIT', 'ch', substr(expr.code, ctrl ->> '$.i'+1, 1), 'i', ctrl ->> '$.i'+1, 'tx', '')
			WHEN instr('0123456789', ctrl ->> '$.ch') > 0 THEN json_object('st', 'S_NUMERIC', 'tk', 'T_WAIT', 'ch', substr(expr.code, ctrl ->> '$.i'+1, 1), 'i', ctrl ->> '$.i'+1, 'tx', ctrl ->> '$.ch')
			WHEN ctrl ->> '$.ch' = '+' THEN json_object('st', 'S_START', 'tk', 'T_PLUS', 'ch', substr(expr.code, ctrl ->> '$.i'+1, 1), 'i', ctrl ->> '$.i'+1, 'tx', ctrl ->> '$.ch')
			WHEN ctrl ->> '$.ch' = '-' THEN json_object('st', 'S_START', 'tk', 'T_MINUS', 'ch', substr(expr.code, ctrl ->> '$.i'+1, 1), 'i', ctrl ->> '$.i'+1, 'tx', ctrl ->> '$.ch')
			WHEN ctrl ->> '$.ch' = '*' THEN json_object('st', 'S_START', 'tk', 'T_MULTIPLY', 'ch', substr(expr.code, ctrl ->> '$.i'+1, 1), 'i', ctrl ->> '$.i'+1, 'tx', ctrl ->> '$.ch')
			WHEN ctrl ->> '$.ch' = '/' THEN json_object('st', 'S_START', 'tk', 'T_DIVIDE', 'ch', substr(expr.code, ctrl ->> '$.i'+1, 1), 'i', ctrl ->> '$.i'+1, 'tx', ctrl ->> '$.ch')
			ELSE json_object('st', 'S_ERROR', 'tk', '', 'advance', 'Y', 'tx', format('Error at position %d', ctrl ->> '$.i'))
		END
		WHEN ctrl ->> '$.st' = 'S_WS' THEN
		CASE
			WHEN ctrl ->> '$.ch' = ' ' THEN json_object('st', 'S_WS', 'tk', 'T_WAIT', 'ch', substr(expr.code, ctrl ->> '$.i'+1, 1), 'i', ctrl ->> '$.i'+1, 'tx', '')
			ELSE json_object('st', 'S_START', 'tk', 'T_WS', 'ch', substr(expr.code, ctrl ->> '$.i', 1), 'i', ctrl ->> '$.i', 'tx', '')
		END
		WHEN ctrl ->> '$.st' = 'S_NUMERIC' THEN 
		CASE 
			WHEN instr('0123456789', ctrl ->> '$.ch') > 0 THEN json_object('st', 'S_NUMERIC', 'tk', 'T_WAIT', 'ch', substr(expr.code, ctrl ->> '$.i'+1, 1), 'i', ctrl ->> '$.i'+1, 'tx', format('%s%s', ctrl ->> '$.tx', ctrl ->> '$.ch'))
			WHEN ctrl ->> '$.ch' = '.' THEN json_object('st', 'S_FLOAT', 'tk', 'T_WAIT', 'ch', substr(expr.code, ctrl ->> '$.i'+1, 1), 'i', ctrl ->> '$.i'+1, 'tx', format('%s%s', ctrl ->> '$.tx', ctrl ->> '$.ch'))
			ELSE json_object('st', 'S_START', 'tk', 'T_NUMERIC', 'ch', substr(expr.code, ctrl ->> '$.i', 1), 'i', ctrl ->> '$.i', 'tx', ctrl ->> '$.tx')
		END
		WHEN ctrl ->> '$.st' = 'S_FLOAT' THEN 
		CASE
			WHEN instr('0123456789', ctrl ->> '$.ch') > 0 THEN json_object('st', 'S_FLOAT', 'tk', 'T_WAIT', 'ch', substr(expr.code, ctrl ->> '$.i'+1, 1), 'i', ctrl ->> '$.i'+1, 'tx', format('%s%s', ctrl ->> '$.tx', ctrl ->> '$.ch'))
			ELSE json_object('st', 'S_START', 'tk', 'T_FLOAT', 'ch', substr(expr.code, ctrl ->> '$.i', 1), 'i', ctrl ->> '$.i', 'tx', ctrl ->> '$.tx')
		END
		ELSE json_object('st', 'S_ERROR', 'tk', '', 'advance', 'Y')
	END AS state
	FROM lex JOIN expr WHERE ctrl ->> '$.st' not in ('S_ERROR', 'S_EOL') AND ctrl ->> '$.i' <= length(expr.code)
)
SELECT ctrl ->> '$.tk' as token, ctrl ->> '$.tx' as txt FROM lex where ctrl ->> '$.tk' <> 'T_WAIT'

